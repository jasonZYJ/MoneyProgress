//
//  Menubar.swift
//  MoneyProgress
//
//  Created by Lakr Aream on 2022/3/15.
//
//  重构：使用 WorkSchedule + EarningsCalculator 统一计算逻辑
//  增加：跨午夜、加班、节假日支持；下班通知；历史记录；全局快捷键
//

import AppKit
import SwiftUI

final class Menubar: ObservableObject {
    static let shared = Menubar()

    // MARK: - 配置（单一数据源）

    @AppStorage("wiki.qaq.workSchedule.v2") private var rawSchedule: String = ""
    @AppStorage("wiki.qaq.currencyUnit") var currencyUnit: String = "CNY"
    @AppStorage("wiki.qaq.compactMode") var compactMode: Bool = false
    @AppStorage("wiki.qaq.notifications.enabled") var notificationsEnabled: Bool = true
    @AppStorage("wiki.qaq.holiday.enabled") var holidayEnabled: Bool = true
    @AppStorage("wiki.qaq.globalHotkey.enabled") var globalHotkeyEnabled: Bool = true
    @AppStorage("wiki.qaq.history.v1") private var rawHistory: String = ""

    var schedule: WorkSchedule {
        get {
            if let data = rawSchedule.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(WorkSchedule.self, from: data) {
                return decoded
            }
            return WorkSchedule.migrateFromLegacy()
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let str = String(data: data, encoding: .utf8) else { return }
            rawSchedule = str
        }
    }

    // MARK: - 运行时状态

    @Published var menubarRunning = false
    @Published var todayPercent: Double = 0
    @Published var todayEarn: Double = 0
    @Published var todayOvertimeSeconds: Int = 0
    @Published var isHoliday: Bool = false

    var popover: NSPopover
    var statusItem: NSStatusItem?
    var eventMonitor: EventMonitor?
    var hotkey: GlobalHotkey?

    let timer: Timer!

    // 通知去重
    private var lastOvertimeNotified: Bool = false
    private var lastOffworkNotifiedDate: String = ""
    private var lastHolidayNotifiedDate: String = ""

    private init() {
        let buildPopover = NSPopover()
        popover = buildPopover
        let view = MenubarView()
        buildPopover.contentViewController = NSHostingController(rootView: view)
        timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            Menubar.shared.tick()
        }
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown], handler: { event in
            Menubar.shared.mouseEventHandler(event)
        })
        RunLoop.current.add(timer, forMode: .common)
    }

    // MARK: - 公共 API

    @MainActor
    func run() {
        assert(Thread.isMainThread)
        guard !menubarRunning else { return }
        AppLog.debug("Menubar.run")
        popover.close()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(sender:))
        if let origFont = item.button?.font {
            item.button?.font = .monospacedSystemFont(ofSize: origFont.pointSize, weight: .regular)
        }
        // 设置状态栏图标（跟 app 主图标一致 — 金币 + 趋势线）
        applyStatusBarIcon(to: item.button)
        self.statusItem = item
        menubarRunning = true
        NotificationManager.shared.ensureAuthorization()
        registerHotkey()
        tick()
    }

    /// 把 app 主 logo 渲染成 macOS 状态栏图标
    /// 状态栏推荐尺寸 18x18 @1x / 36x36 @2x
    @MainActor
    private func applyStatusBarIcon(to button: NSStatusBarButton?) {
        guard let button = button else { return }
        // 优先使用 BrandLogo Canvas（跟界面/logo 完全一致的金币 + 趋势线）
        if let cgImage = renderBrandLogoCG(size: 36) {
            let img = NSImage(cgImage: cgImage, size: NSSize(width: 18, height: 18))
            img.isTemplate = false  // 保持彩色（金币是金色，不能被系统染黑）
            button.image = img
            button.imagePosition = .imageLeft
            button.imageScaling = .scaleProportionallyDown
        } else if let png = AppIconLoader.loadIcon() {
            // 回退：bundle 里的 PNG
            png.size = NSSize(width: 18, height: 18)
            button.image = png
            button.imagePosition = .imageLeft
        }
    }

    /// 用 ImageRenderer 把 BrandLogo 视图渲染成 CGImage（与界面 logo 100% 一致）
    @MainActor
    private func renderBrandLogoCG(size: CGFloat) -> CGImage? {
        let logo = BrandLogo(size: size, showRing: false, progress: 0)
            .frame(width: size, height: size)
        let renderer = ImageRenderer(content: logo)
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(width: size, height: size)
        return renderer.cgImage
    }

    func stop() {
        assert(Thread.isMainThread)
        guard menubarRunning else { return }
        AppLog.debug("Menubar.stop")
        popover.close()
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        menubarRunning = false
        hotkey?.unregister()
        hotkey = nil
    }

    func reload() {
        // 触发 tick
        tick()
    }

    /// 读取历史快照（用于导出）
    func snapshotHistory() -> [DailyEarningRecord]? {
        guard let data = rawHistory.data(using: .utf8),
              let arr = try? JSONDecoder().decode([DailyEarningRecord].self, from: data)
        else { return nil }
        return arr.sorted { $0.dateKey < $1.dateKey }
    }

    func showPopover(_: AnyObject) {
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.maxY)
            eventMonitor?.start()
        }
    }

    func hidePopover(_ sender: AnyObject) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }

    func mouseEventHandler(_ event: NSEvent?) {
        if popover.isShown, let event = event {
            hidePopover(event)
        }
    }

    @objc
    func togglePopover(sender: AnyObject) {
        if popover.isShown {
            hidePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    /// 打开主窗口（菜单栏点击双动作）
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
            return
        }
    }

    // MARK: - 定时刷新

    func tick() {
        let now = Date()
        let holidays = holidayEnabled ? HolidayCalendar(customHolidays: schedule.customHolidays) : nil
        let result = EarningsCalculator.compute(
            schedule: schedule,
            now: now,
            holidays: holidays
        )

        let isRest = holidays?.isRestDay(now) ?? false
        isHoliday = isRest

        // 进度百分比：节假日显示 100% 不变（"今天挣满啦"）
        let percent: Double
        if isRest {
            percent = 1.0
        } else {
            percent = max(0, min(1, result.percent))
        }
        todayPercent = percent
        todayEarn = isRest ? result.dailyEarnings : result.earned
        todayOvertimeSeconds = result.overtimeSeconds

        updateButtonText()
        handleNotifications(result: result, isRest: isRest)
        saveHistoryIfNeeded(result: result, isRest: isRest)
    }

    private func updateButtonText() {
        guard let button = statusItem?.button else { return }

        let title: String
        if isHoliday {
            title = " " + NSLocalizedString("menubar.holiday", comment: "")
        } else if todayPercent <= 0 {
            title = " " + NSLocalizedString("menubar.notStarted", comment: "")
        } else if todayPercent >= 1 {
            title = " " + String(format: NSLocalizedString("menubar.available", comment: ""), todayEarn, currencyUnit)
        } else {
            if compactMode {
                title = " " + String(format: NSLocalizedString("menubar.earnedCompact", comment: ""), todayEarn, currencyUnit)
            } else {
                title = " " + String(format: NSLocalizedString("menubar.earnedLong", comment: ""), todayEarn, currencyUnit)
            }
        }
        button.title = title
    }

    private func handleNotifications(result: EarningResult, isRest: Bool) {
        guard notificationsEnabled, menubarRunning else { return }
        let todayKey = DailyEarningRecord.todayKey()

        // 下班通知
        if result.completed, !isRest, lastOffworkNotifiedDate != todayKey {
            lastOffworkNotifiedDate = todayKey
            NotificationManager.shared.notifyOffWork(earned: result.earned, currencyUnit: currencyUnit)
        }

        // 加班通知（首次进入加班时）
        if result.overtimeSeconds > 0, !lastOvertimeNotified {
            lastOvertimeNotified = true
            NotificationManager.shared.notifyOvertimeStart(earned: result.earned, currencyUnit: currencyUnit)
        } else if result.overtimeSeconds == 0 {
            lastOvertimeNotified = false
        }

        // 节假日通知
        if isRest, lastHolidayNotifiedDate != todayKey {
            lastHolidayNotifiedDate = todayKey
            NotificationManager.shared.notifyHoliday(name: "Holiday".localized)
        }
    }

    private func saveHistoryIfNeeded(result: EarningResult, isRest: Bool) {
        let key = DailyEarningRecord.todayKey()
        var records: [DailyEarningRecord] = {
            guard let data = rawHistory.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([DailyEarningRecord].self, from: data) else {
                return []
            }
            return arr
        }()

        let record = DailyEarningRecord(
            dateKey: key,
            earned: result.earned,
            dayEarnings: result.dailyEarnings,
            overtimeSeconds: result.overtimeSeconds,
            netWorkSeconds: result.passedWorkSeconds,
            isRestDay: isRest
        )

        if let idx = records.firstIndex(where: { $0.dateKey == key }) {
            records[idx] = record
        } else {
            records.append(record)
        }

        // 清理 365 天前（最多保留 1 年数据）
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone.current
        let cutoffKey = fmt.string(from: Calendar.current.date(byAdding: .day, value: -HistoryRetentionDays, to: Date()) ?? Date())
        records = records
            .filter { $0.dateKey >= cutoffKey }
            .sorted { $0.dateKey < $1.dateKey }
        // 硬上限：按日期去重后不超过 1.5x 限额（防御异常日期）
        if records.count > HistoryRetentionDays + 30 {
            records = Array(records.suffix(HistoryRetentionDays))
        }

        if let data = try? JSONEncoder().encode(records),
           let str = String(data: data, encoding: .utf8) {
            rawHistory = str
        }
    }

    // MARK: - 全局快捷键

    private func registerHotkey() {
        guard globalHotkeyEnabled else { return }
        if hotkey == nil {
            hotkey = GlobalHotkey(keyCode: 0x2D, modifiers: [.option, .command]) { [weak self] in
                // Cmd+Opt+0 切换主窗口
                self?.openMainWindow()
            }
        }
        hotkey?.register()
    }
}

// MARK: - EventMonitor（修复 force cast）

extension Menubar {
    final class EventMonitor {
        private var monitor: Any?
        private let mask: NSEvent.EventTypeMask
        private let handler: (NSEvent?) -> Void

        init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
            self.mask = mask
            self.handler = handler
        }

        deinit { stop() }

        func start() {
            if monitor != nil { stop() }
            monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        }

        func stop() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
            }
            monitor = nil
        }
    }
}
