//
//  Log.swift
//  MoneyProgress
//
//  简易日志（DEBUG 输出，生产静默）
//

import Foundation
import os

/// 通知名称（项目内集中管理）
extension Notification.Name {
    /// 触发"打开设置窗口" — 用于绕过 NSApp.delegate 转换失败的问题
    static let openSettings = Notification.Name("wiki.qaq.openSettings")
}

enum AppLog {
    private static let logger = Logger(subsystem: "wiki.qaq.MoneyProgress", category: "app")

    static func debug(_ message: @autoclosure () -> String, file: String = #fileID, line: Int = #line) {
        #if DEBUG
        let msg = message()
        logger.debug("[\(file):\(line)] \(msg, privacy: .public)")
        print("🐛 [\(file):\(line)] \(msg)")
        #endif
    }

    static func info(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.info("\(msg, privacy: .public)")
    }

    static func warn(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.warning("⚠️ \(msg, privacy: .public)")
    }

    static func error(_ message: @autoclosure () -> String) {
        let msg = message()
        logger.error("❌ \(msg, privacy: .public)")
    }
}
