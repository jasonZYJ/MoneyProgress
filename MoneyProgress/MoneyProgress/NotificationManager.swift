//
//  NotificationManager.swift
//  MoneyProgress
//
//  下班 / 加班 / 节假日提醒
//

import AppKit
import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    private var didRequestAuth = false

    /// 申请通知权限（仅在第一次调用时触发）
    func ensureAuthorization() {
        guard !didRequestAuth else { return }
        didRequestAuth = true
        requestAuthorization { _ in }
    }

    /// 直接申请通知权限（用于启动引导）
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                AppLog.warn("通知权限请求失败：\(error.localizedDescription)")
            } else {
                AppLog.info("通知权限 granted=\(granted)")
            }
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// 下班提醒
    func notifyOffWork(earned: Double, currencyUnit: String) {
        let title = "💰 下班啦".localized
        let body = String(format: "今日已挣 %.2f %@".localized, earned, currencyUnit)
        deliver(title: title, body: body, identifier: "offwork.\(DailyEarningRecord.todayKey())")
    }

    /// 加班提示（达到阈值时）
    func notifyOvertimeStart(earned: Double, currencyUnit: String) {
        let title = "💼 开始加班".localized
        let body = String(format: "基础工时已完成，当前累计 %.2f %@，按加班费率计算中".localized, earned, currencyUnit)
        deliver(title: title, body: body, identifier: "overtime.\(DailyEarningRecord.todayKey())")
    }

    /// 节假日提醒
    func notifyHoliday(name: String) {
        let title = "🎉 节假日快乐".localized
        let body = String(format: "今天是 %@，好好休息！".localized, name)
        deliver(title: title, body: body, identifier: "holiday.\(DailyEarningRecord.todayKey())")
    }

    private func deliver(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { error in
            if let error = error {
                AppLog.warn("通知投递失败：\(error.localizedDescription)")
            }
        }
    }
}
