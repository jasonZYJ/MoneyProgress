//
//  WorkScheduleStore.swift
//  MoneyProgress
//
//  统一存储：将原来散落在 ContentView/Menubar 的 18 个 @AppStorage 合并为单一数据源
//  + 兼容旧版（自动迁移）
//

import Foundation
import SwiftUI

/// 工作日程的持久化存储（替代 9 个 @AppStorage）
@propertyWrapper
struct AppStorageWorkSchedule: DynamicProperty {
    @AppStorage("wiki.qaq.workSchedule.v2") private var raw: String = ""

    var wrappedValue: WorkSchedule {
        get {
            if let data = raw.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(WorkSchedule.self, from: data) {
                return decoded
            }
            // 旧数据迁移：尝试从 9 个老 key 重建
            return Self.migrateFromLegacy()
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let str = String(data: data, encoding: .utf8) else { return }
            raw = str
        }
    }

    var projectedValue: Binding<WorkSchedule> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }

    private static func migrateFromLegacy() -> WorkSchedule {
        let defaults = UserDefaults.standard
        let schedule = WorkSchedule.default

        // 读取旧 key（不存在则用 default）
        func dbl(_ key: String) -> Double {
            defaults.object(forKey: key) as? Double ?? 0
        }
        func int(_ key: String, _ fb: Int) -> Int {
            defaults.object(forKey: key) as? Int ?? fb
        }
        func bool(_ key: String, _ fb: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fb
        }

        let workStart = dbl("wiki.qaq.workStart")
        let workEnd = dbl("wiki.qaq.workEnd")
        let monthPaid = int("wiki.qaq.monthPaid", 3000)
        let dayWorkOfMonth = int("wiki.qaq.dayWorkOfMonth", 20)
        let isHaveNoonBreak = bool("wiki.qaq.isHaveNoonBreak", false)
        let noonBreakStart = dbl("wiki.qaq.noonBreakStartTimeStamp")
        let noonBreakEnd = dbl("wiki.qaq.noonBreakEndTimeStamp")

        guard workStart > 0, workEnd > 0 else {
            return schedule
        }

        // 从 timeIntervalSince1970 提取 HMS -> secondsInDay
        func hms(_ stamp: Double) -> Int {
            let date = Date(timeIntervalSince1970: stamp)
            let cal = Calendar.current
            return cal.component(.hour, from: date) * 3600
                + cal.component(.minute, from: date) * 60
        }

        var breaks: [BreakPeriod] = []
        if isHaveNoonBreak, noonBreakStart > 0, noonBreakEnd > 0 {
            breaks = [BreakPeriod(startSeconds: hms(noonBreakStart), endSeconds: hms(noonBreakEnd))]
        }

        return WorkSchedule(
            workStartSeconds: hms(workStart),
            workEndSeconds: hms(workEnd),
            breaks: breaks,
            monthPaidCents: max(0, monthPaid) * 100,
            dayWorkOfMonth: max(1, dayWorkOfMonth),
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

/// 历史每日累计（用于 Swift Charts）
struct DailyEarningRecord: Codable, Equatable, Identifiable {
    var id: String { dateKey }
    var dateKey: String      // yyyy-MM-dd
    var earned: Double       // 当日累计（元）
    var dayEarnings: Double  // 今日应赚（元）
    var overtimeSeconds: Int
    var netWorkSeconds: Int
    var isRestDay: Bool

    static let empty = DailyEarningRecord(
        dateKey: "", earned: 0, dayEarnings: 0, overtimeSeconds: 0, netWorkSeconds: 0, isRestDay: false
    )

    static func todayKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone.current
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: Date())
    }
}

/// 历史存储
@propertyWrapper
struct AppStorageHistory: DynamicProperty {
    @AppStorage("wiki.qaq.history.v1") private var raw: String = ""
    @AppStorage("wiki.qaq.history.lastResetMonth") private var lastResetMonth: String = ""

    var wrappedValue: [DailyEarningRecord] {
        get {
            guard let data = raw.data(using: .utf8),
                  let arr = try? JSONDecoder().decode([DailyEarningRecord].self, from: data) else {
                return []
            }
            return arr.sorted { $0.dateKey < $1.dateKey }
        }
        nonmutating set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let str = String(data: data, encoding: .utf8) else { return }
            raw = str
        }
    }

    var projectedValue: Binding<[DailyEarningRecord]> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }

    /// 清理上月记录（保留最近 60 天）
    static func trim(_ records: [DailyEarningRecord]) -> [DailyEarningRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let key = DailyEarningRecord.empty.dateKey
        _ = key
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone.current
        let cutoffKey = fmt.string(from: cutoff)
        return records.filter { $0.dateKey >= cutoffKey }
    }
}
