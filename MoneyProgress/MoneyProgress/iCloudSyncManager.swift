//
//  iCloudSyncManager.swift
//  MoneyProgress
//
//  iCloud KVS 同步管理器（NSUbiquitousKeyValueStore）
//  - 启动时从云端拉取并合并
//  - 监听本地写入并推送到云端
//  - 监听云端变化并自动应用
//  - 优雅降级：iCloud 不可用不影响本地使用
//

import Foundation
import SwiftUI

@MainActor
final class iCloudSyncManager: ObservableObject {
    static let shared = iCloudSyncManager()

    private let store = NSUbiquitousKeyValueStore.default
    private var localObserver: NSObjectProtocol?
    private var cloudObserver: NSObjectProtocol?
    private var isApplyingFromCloud = false  // 防止拉取时再次回推

    /// 同步状态（UI 显示用）
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastError: String?

    /// 需要同步的 key 列表（白名单）
    private let syncedKeys: Set<String> = [
        // 工作日程
        "wiki.qaq.workSchedule.v2",
        "wiki.qaq.workSchedule.legacy",  // 旧版 9 个 key 容器
        // 历史
        "wiki.qaq.history.v1",
        "wiki.qaq.history.lastResetMonth",
        // 偏好
        "wiki.qaq.currencyUnit",
        "wiki.qaq.compactMode",
        "wiki.qaq.notifications.enabled",
        "wiki.qaq.holiday.enabled",
        "wiki.qaq.overtime.enabled",
        "wiki.qaq.globalHotkey.enabled",
        // 目标
        "wiki.qaq.monthlyGoal",
        "wiki.qaq.dailyGoalOverride",
        "wiki.qaq.streakGoal",
        // 旧版工作日程字段（兼容）
        "wiki.qaq.workStart",
        "wiki.qaq.workEnd",
        "wiki.qaq.monthPaid",
        "wiki.qaq.dayWorkOfMonth",
        "wiki.qaq.isHaveNoonBreak",
        "wiki.qaq.noonBreakStartTimeStamp",
        "wiki.qaq.noonBreakEndTimeStamp",
    ]

    /// 不同步的 key（设备特有）
    private let excludedKeys: Set<String> = [
        "wiki.qaq.window.frame",
        "wiki.qaq.window.hasSaved",
        "wiki.qaq.notif.didPrompt",
        "wiki.qaq.launchAtLogin",
    ]

    private init() {}

    // MARK: - 生命周期

    /// 启动同步（在 applicationDidFinishLaunching 调用）
    func start() {
        // 1) 启动时同步一次
        store.synchronize()

        // 2) 检测 iCloud 是否可用
        // 尝试读取一个测试 key 触发 iCloud account 状态
        isAvailable = checkICloudAvailability()

        // 3) 从云端拉取并合并
        if isAvailable {
            for key in syncedKeys {
                applyFromCloudIfPresent(key: key)
            }
            lastSyncDate = Date()
        } else {
            AppLog.warn("iCloudSync: iCloud 不可用，仅本地模式")
        }

        // 4) 监听云端变化
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleCloudChange(notification)
            }
        }

        // 5) 监听本地 UserDefaults 变化（NotificationCenter）→ 推送到云端
        // 注：不要用 KVO 观察 dictionaryRepresentation（KVO 对计算属性不可靠）
        localObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            // 防抖：避免一次 UI 操作触发多次同步
            self?.scheduleDebouncedPush()
        }
    }

    private var pendingPush: DispatchWorkItem?
    private func scheduleDebouncedPush() {
        pendingPush?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.pushChangedKeysToCloud()
            }
        }
        pendingPush = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    // MARK: - 检测 iCloud 可用性

    private func checkICloudAvailability() -> Bool {
        // FileManager.default.ubiquityIdentityToken 不为 nil 表示 iCloud 已登录
        return FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - 从云端拉取

    private func applyFromCloudIfPresent(key: String) {
        // KVS 不直接告诉某个 key 是否存在，只能尝试读
        if let str = store.string(forKey: key) {
            applyStringFromCloud(key: key, value: str)
        } else if let data = store.data(forKey: key) {
            applyDataFromCloud(key: key, value: data)
        }
    }

    private func applyStringFromCloud(key: String, value: String) {
        isApplyingFromCloud = true
        defer { isApplyingFromCloud = false }

        if key == "wiki.qaq.history.v1" {
            // 历史需要合并
            mergeHistoryFromCloud(value: value)
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func applyDataFromCloud(key: String, value: Data) {
        isApplyingFromCloud = true
        defer { isApplyingFromCloud = false }

        if let str = String(data: value, encoding: .utf8) {
            UserDefaults.standard.set(str, forKey: key)
        } else {
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    // MARK: - 历史合并（核心：取并集，earned 大的胜出）

    private func mergeHistoryFromCloud(value: String) {
        guard let cloudData = value.data(using: .utf8),
              let cloudRecords = try? JSONDecoder().decode([DailyEarningRecord].self, from: cloudData) else {
            AppLog.warn("iCloudSync: 云端 history 解析失败")
            return
        }

        // 读取本地历史
        let localRaw = UserDefaults.standard.string(forKey: "wiki.qaq.history.v1") ?? ""
        let localRecords: [DailyEarningRecord]
        if let localData = localRaw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([DailyEarningRecord].self, from: localData) {
            localRecords = decoded
        } else {
            localRecords = []
        }

        // 合并：按 dateKey 取并集，同一天 earned 大的胜出
        var merged: [String: DailyEarningRecord] = [:]
        for rec in localRecords {
            merged[rec.dateKey] = rec
        }
        for rec in cloudRecords {
            if let existing = merged[rec.dateKey] {
                // 同一日期：取 earned 大的
                if rec.earned > existing.earned {
                    merged[rec.dateKey] = rec
                }
            } else {
                merged[rec.dateKey] = rec
            }
        }

        let mergedArray = Array(merged.values).sorted { $0.dateKey < $1.dateKey }
        if let mergedData = try? JSONEncoder().encode(mergedArray),
           let mergedStr = String(data: mergedData, encoding: .utf8) {
            UserDefaults.standard.set(mergedStr, forKey: "wiki.qaq.history.v1")
            AppLog.info("iCloudSync: 合并 history — 本地 \(localRecords.count) 条 + 云端 \(cloudRecords.count) 条 → 合并后 \(mergedArray.count) 条")
        }
    }

    // MARK: - 推送到云端

    private func pushChangedKeysToCloud() {
        // 防止拉取时回推
        guard !isApplyingFromCloud else { return }
        guard isAvailable else { return }

        for key in syncedKeys {
            if let str = UserDefaults.standard.string(forKey: key) {
                // 推送前再次合并 history（避免覆盖更新的云端数据）
                if key == "wiki.qaq.history.v1" {
                    let localCount = (try? JSONDecoder().decode([DailyEarningRecord].self, from: str.data(using: .utf8) ?? Data()))?.count ?? 0
                    // 优先读取云端 → 合并 → 再推送
                    if let cloudStr = store.string(forKey: key) {
                        // 复用合并逻辑
                        guard let cloudData = cloudStr.data(using: .utf8),
                              let cloudRecords = try? JSONDecoder().decode([DailyEarningRecord].self, from: cloudData) else {
                            store.set(str, forKey: key)
                            continue
                        }
                        guard let localData = str.data(using: .utf8),
                              let localRecords = try? JSONDecoder().decode([DailyEarningRecord].self, from: localData) else {
                            store.set(str, forKey: key)
                            continue
                        }
                        var merged: [String: DailyEarningRecord] = [:]
                        for rec in cloudRecords { merged[rec.dateKey] = rec }
                        for rec in localRecords {
                            if let existing = merged[rec.dateKey] {
                                if rec.earned > existing.earned { merged[rec.dateKey] = rec }
                            } else {
                                merged[rec.dateKey] = rec
                            }
                        }
                        let mergedArray = Array(merged.values).sorted { $0.dateKey < $1.dateKey }
                        if let mergedData = try? JSONEncoder().encode(mergedArray),
                           let mergedStr = String(data: mergedData, encoding: .utf8) {
                            store.set(mergedStr, forKey: key)
                        }
                        _ = localCount
                    } else {
                        store.set(str, forKey: key)
                    }
                } else {
                    store.set(str, forKey: key)
                }
            }
        }

        let ok = store.synchronize()
        if ok {
            lastSyncDate = Date()
        } else {
            lastError = "synchronize() 返回 false"
        }
    }

    // MARK: - 处理云端变化

    private func handleCloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }

        AppLog.info("iCloudSync: 收到云端变化，keys=\(changedKeys.count)")

        for key in changedKeys {
            guard syncedKeys.contains(key) else { continue }
            applyFromCloudIfPresent(key: key)
        }
        lastSyncDate = Date()
    }

    // MARK: - 手动触发

    /// 强制立即推送（如用户点击"立即同步"按钮）
    func forcePush() {
        pushChangedKeysToCloud()
    }

    /// 强制立即拉取
    func forcePull() {
        store.synchronize()
        for key in syncedKeys {
            applyFromCloudIfPresent(key: key)
        }
        lastSyncDate = Date()
    }

    // MARK: - 辅助

    /// 同步状态文字（用于 UI 显示）
    var statusText: String {
        if !isAvailable {
            return "本地模式（未登录 iCloud）"
        }
        guard let date = lastSyncDate else {
            return "iCloud 已就绪"
        }
        let fmt = DateFormatter()
        fmt.dateStyle = .none
        fmt.timeStyle = .medium
        return "iCloud 已同步 · \(fmt.string(from: date))"
    }
}
