//
//  PerfSignpost.swift
//  MoneyProgress
//
//  性能监测（os_signpost 接入 Instruments）
//  Feature 60：用 os_signpost 给关键计算路径打点
//

import Foundation
import os.signpost

/// 性能监测点（用 os_signpost 让 Instruments.app 可视化）
enum PerfSignpost {
    private static let log = OSLog(subsystem: "wiki.qaq.MoneyProgress", category: .pointsOfInterest)
    private static let counter = OSLog(subsystem: "wiki.qaq.MoneyProgress", category: "counter")

    /// 包裹关键计算，自动 begin/end
    @inline(__always)
    static func measure<T>(_ name: StaticString, _ block: () throws -> T) rethrows -> T {
        os_signpost(.begin, log: log, name: name)
        defer { os_signpost(.end, log: log, name: name) }
        return try block()
    }

    /// 异步测量（带闭包）
    @inline(__always)
    static func measureAsync<T>(_ name: StaticString, _ block: () async throws -> T) async rethrows -> T {
        os_signpost(.begin, log: log, name: name)
        defer { os_signpost(.end, log: log, name: name) }
        return try await block()
    }

    /// 事件（一次性标记）
    @inline(__always)
    static func event(_ name: StaticString) {
        os_signpost(.event, log: log, name: name)
    }

    /// 计数器（用于统计如 tick 次数、记录数）
    @inline(__always)
    static func count(_ name: StaticString, by delta: Int64 = 1) {
        os_signpost(.event, log: counter, name: name)
    }
}
