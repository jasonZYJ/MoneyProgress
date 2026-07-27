//
//  WorkSchedule.swift
//  MoneyProgress
//
//  工作日程配置模型（单一数据源，替代散落在视图中的 @AppStorage）
//

import Foundation

/// 休息时段（午休等）
struct BreakPeriod: Codable, Equatable, Hashable {
    /// 当天的秒数偏移（0-86399）
    var startSeconds: Int
    var endSeconds: Int

    init(startSeconds: Int, endSeconds: Int) {
        precondition(startSeconds >= 0 && startSeconds < 86400, "startSeconds out of range")
        precondition(endSeconds > 0 && endSeconds <= 86400, "endSeconds out of range")
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }

    /// 时长（秒）
    var duration: TimeInterval { TimeInterval(endSeconds - startSeconds) }
}

/// 周工作日（1=周日，2=周一，...，7=周六）——与 Calendar.weekday 对齐
struct WorkdaySet: Codable, Equatable, Hashable {
    private var bits: UInt8

    init(_ days: Set<Int> = [2, 3, 4, 5, 6]) {  // 默认周一~周五
        bits = 0
        for d in days { set(day: d) }
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        bits = 0
        if let arr = try? container.decode([Int].self) {
            for d in arr { set(day: d) }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for d in allDays.sorted() { try container.encode(d) }
    }

    func contains(_ weekday: Int) -> Bool { (bits & (1 << UInt8(weekday - 1))) != 0 }

    mutating func set(day: Int) {
        guard (1...7).contains(day) else { return }
        bits |= (1 << UInt8(day - 1))
    }

    mutating func toggle(day: Int) {
        guard (1...7).contains(day) else { return }
        bits ^= (1 << UInt8(day - 1))
    }

    var allDays: Set<Int> {
        var r = Set<Int>()
        for d in 1...7 where contains(d) { r.insert(d) }
        return r
    }
}

/// 工作日程（替代 ContentView 中散落的 18 个 @AppStorage 字段）
struct WorkSchedule: Codable, Equatable {
    /// 上班时间（当天秒数偏移）
    var workStartSeconds: Int
    /// 下班时间（当天秒数偏移，允许 < workStart 表示跨午夜）
    var workEndSeconds: Int
    /// 休息时段（午休等）
    var breaks: [BreakPeriod]
    /// 月薪（分，避免浮点；展示时除 100）
    var monthPaidCents: Int
    /// 每月工作天数
    var dayWorkOfMonth: Int
    /// 工作日集合（默认周一~周五）
    var workdays: WorkdaySet
    /// 加班费率（默认 1.0 = 不算加班；1.5 = 1.5 倍等）
    var overtimeRate: Double
    /// 超过多少秒算加班（0 = 不计加班）
    var overtimeThresholdSeconds: Int
    /// 自定义节假日（yyyy-MM-dd）
    var customHolidays: Set<String>
    /// 周末是否也算工作日（用于补班）
    var workOnWeekends: Bool
    /// 月度收入目标（元，0 = 无目标）
    var monthlyGoalCents: Int
    /// 今日收入目标（0 = 跟随月薪/天数）
    var dailyGoalOverrideCents: Int
    /// 连续工作日目标（0 = 不追踪）
    var streakGoal: Int

    static let `default` = WorkSchedule(
        workStartSeconds: 9 * 3600,
        workEndSeconds: 18 * 3600,
        breaks: [BreakPeriod(startSeconds: 12 * 3600, endSeconds: 14 * 3600)],
        monthPaidCents: 20_000_00,   // 20000 元
        dayWorkOfMonth: 20,
        workdays: WorkdaySet([2, 3, 4, 5, 6]),
        overtimeRate: 1.0,
        overtimeThresholdSeconds: 0,
        customHolidays: [],
        workOnWeekends: false,
        monthlyGoalCents: 0,
        dailyGoalOverrideCents: 0,
        streakGoal: 0
    )

    // MARK: - 便利属性

    /// 是否跨午夜
    var crossesMidnight: Bool { workEndSeconds <= workStartSeconds }

    /// 月薪（元，Double）
    var monthPaid: Double { Double(monthPaidCents) / 100.0 }

    /// 每天应赚（元）
    var dailyEarnings: Double {
        guard dayWorkOfMonth > 0 else { return 0 }
        return monthPaid / Double(dayWorkOfMonth)
    }

    /// 今日总工时（秒，扣除休息）
    var totalWorkSecondsToday: Int {
        let gross = effectiveSpanSeconds(start: workStartSeconds, end: workEndSeconds)
        let breakSeconds = breaks
            .filter { $0.startSeconds < $0.endSeconds }  // 跨午夜的休息不计（理论上不存在）
            .reduce(0) { $0 + $1.duration }
        return max(0, gross - Int(breakSeconds))
    }

    /// 计算两时刻的「有效秒数」，支持跨午夜
    static func effectiveSpanSeconds(start: Int, end: Int) -> Int {
        if end > start { return end - start }
        if end < start { return (86400 - start) + end }   // 跨午夜
        return 0
    }

    func effectiveSpanSeconds(start: Int, end: Int) -> Int {
        Self.effectiveSpanSeconds(start: start, end: end)
    }

    // MARK: - 旧数据迁移

    /// 从旧版 9 个独立 @AppStorage key 迁移数据
    /// - Parameter defaults: UserDefaults（默认 .standard）
    /// - Returns: 重建的 WorkSchedule；若无数据则返回 `.default`
    static func migrateFromLegacy(defaults: UserDefaults = .standard) -> WorkSchedule {
        func dbl(_ key: String) -> Double { defaults.object(forKey: key) as? Double ?? 0 }
        func int(_ key: String, _ fb: Int) -> Int { defaults.object(forKey: key) as? Int ?? fb }
        func bool(_ key: String, _ fb: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fb }

        let workStart = dbl("wiki.qaq.workStart")
        let workEnd = dbl("wiki.qaq.workEnd")
        guard workStart > 0, workEnd > 0 else { return .default }

        func hms(_ stamp: Double) -> Int {
            let date = Date(timeIntervalSince1970: stamp)
            let cal = Calendar.current
            return cal.component(.hour, from: date) * 3600
                + cal.component(.minute, from: date) * 60
        }

        var breaks: [BreakPeriod] = []
        if bool("wiki.qaq.isHaveNoonBreak", false) {
            let s = dbl("wiki.qaq.noonBreakStartTimeStamp")
            let e = dbl("wiki.qaq.noonBreakEndTimeStamp")
            if s > 0, e > 0 {
                breaks = [BreakPeriod(startSeconds: hms(s), endSeconds: hms(e))]
            }
        }

        return WorkSchedule(
            workStartSeconds: hms(workStart),
            workEndSeconds: hms(workEnd),
            breaks: breaks,
            monthPaidCents: max(0, int("wiki.qaq.monthPaid", 3000)) * 100,
            dayWorkOfMonth: max(1, int("wiki.qaq.dayWorkOfMonth", 20)),
            workdays: WorkdaySet([2, 3, 4, 5, 6]),
            overtimeRate: 1.0,
            overtimeThresholdSeconds: 0,
            customHolidays: [],
            workOnWeekends: false,
            monthlyGoalCents: 0,
            dailyGoalOverrideCents: 0,
            streakGoal: 0
        )
    }
}

/// 节假日日历
struct HolidayCalendar {
    var customHolidays: Set<String>   // yyyy-MM-dd

    /// 中国 2024-2026 法定节假日（硬编码示例；生产应来自 API/文件）
    static let chineseOfficial: Set<String> = [
        // 2025
        "2025-01-01", "2025-01-28", "2025-01-29", "2025-01-30", "2025-01-31", "2025-02-03", "2025-02-04",
        "2025-04-04", "2025-04-05", "2025-04-06",
        "2025-05-01", "2025-05-02", "2025-05-03",
        "2025-05-31", "2025-06-01", "2025-06-02",
        "2025-10-01", "2025-10-02", "2025-10-03", "2025-10-04", "2025-10-05", "2025-10-06", "2025-10-07", "2025-10-08",
        // 2026
        "2026-01-01", "2026-01-02",
        "2026-02-16", "2026-02-17", "2026-02-18", "2026-02-19", "2026-02-20",
        "2026-04-04", "2026-04-05", "2026-04-06",
    ]

    /// 是否为休息日（不工作）
    func isRestDay(_ date: Date) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        let weekday = cal.component(.weekday, from: date)  // 1=Sun..7=Sat
        let key = Self.key(for: date)
        if customHolidays.contains(key) { return true }
        if Self.chineseOfficial.contains(key) { return true }
        if weekday == 1 || weekday == 7 { return true }   // 周末
        return false
    }

    static func key(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        return fmt.string(from: date)
    }
}
