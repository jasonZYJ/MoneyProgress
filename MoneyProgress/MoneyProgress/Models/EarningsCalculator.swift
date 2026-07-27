//
//  EarningsCalculator.swift
//  MoneyProgress
//
//  收入计算器（纯函数，无副作用，可单测）
//  支持：跨午夜、多个休息时段、加班费率、节假日
//

import Foundation

/// 时刻点：包含「天数偏移」和「当天秒数」
/// 用于表示跨午夜的班次（如 22:00 → 次日 06:00）
struct TimePoint: Equatable, Hashable, Comparable {
    /// 从锚点开始的天数（0 = 今天，1 = 明天，-1 = 昨天）
    var dayOffset: Int
    /// 当天秒数偏移 [0, 86400)
    var secondsInDay: Int

    init(dayOffset: Int, secondsInDay: Int) {
        self.dayOffset = dayOffset
        self.secondsInDay = max(0, min(86399, secondsInDay))
    }

    static func today(_ secondsInDay: Int) -> TimePoint { .init(dayOffset: 0, secondsInDay: secondsInDay) }
    static func tomorrow(_ secondsInDay: Int) -> TimePoint { .init(dayOffset: 1, secondsInDay: secondsInDay) }
}

extension TimePoint {
    static func < (lhs: TimePoint, rhs: TimePoint) -> Bool {
        if lhs.dayOffset != rhs.dayOffset { return lhs.dayOffset < rhs.dayOffset }
        return lhs.secondsInDay < rhs.secondsInDay
    }
}

/// 收入计算结果
struct EarningResult: Equatable {
    /// 已工作秒数（含休息？不含 —— 净工作）
    var passedWorkSeconds: Int
    /// 今日总工时（秒）
    var totalWorkSeconds: Int
    /// 加班秒数（超过阈值的部分）
    var overtimeSeconds: Int
    /// 进度百分比 [0, ∞)；>1 表示加班中
    var percent: Double
    /// 已赚金额（元）
    var earned: Double
    /// 今日应赚金额（基础 + 加班）
    var dailyEarnings: Double
    /// 是否还未上班
    var notStartedYet: Bool
    /// 是否已完成今日工作
    var completed: Bool

    /// 秒薪（基础工时部分），单位：元/秒
    /// 不为 0 时为有效值
    var coinPerSecond: Double {
        totalWorkSeconds > 0 ? dailyEarnings / Double(totalWorkSeconds) : 0
    }
}

/// 收入计算器（纯函数）
enum EarningsCalculator {

    // MARK: - 入口

    /// 主计算入口
    /// - Parameters:
    ///   - schedule: 工作日程
    ///   - now: 当前时刻（可注入用于测试）
    ///   - referenceDate: 班次锚点日期（通常 = now 所在日期；测试时可调整）
    ///   - holidays: 节假日日历
    static func compute(
        schedule: WorkSchedule,
        now: Date,
        referenceDate: Date? = nil,
        holidays: HolidayCalendar? = nil
    ) -> EarningResult {
        let anchor = referenceDate ?? now
        let cal = Calendar.current
        let nowPoint = pointOf(date: now, anchor: anchor, calendar: cal)

        // 无效班次（workStart == workEnd），直接返回零结果
        if schedule.workStartSeconds == schedule.workEndSeconds {
            return EarningResult(
                passedWorkSeconds: 0, totalWorkSeconds: 0, overtimeSeconds: 0,
                percent: 0, earned: 0, dailyEarnings: schedule.dailyEarnings,
                notStartedYet: false, completed: false
            )
        }

        // 决定 workStart 的日期偏移
        // 跨午夜的班次：若 now 在 [00:00, workEnd) 区间内，班次是从昨天开始的
        let workStartDayOffset: Int
        if schedule.crossesMidnight {
            if nowPoint.secondsInDay <= schedule.workEndSeconds {
                workStartDayOffset = -1   // 班次从昨天开始，今天结束
            } else {
                workStartDayOffset = 0    // 班次从今天开始，明天结束
            }
        } else {
            workStartDayOffset = 0
        }

        let workStartPoint = TimePoint(
            dayOffset: workStartDayOffset,
            secondsInDay: schedule.workStartSeconds
        )
        let workEndPoint = TimePoint(
            dayOffset: workStartDayOffset + (schedule.crossesMidnight ? 1 : 0),
            secondsInDay: schedule.workEndSeconds
        )

        // 构造所有「工作段」与「休息段」的时间点
        let segments = buildSegments(
            schedule: schedule,
            workStartDayOffset: workStartDayOffset,
            calendar: cal
        )

        // 计算净工作秒数
        let (netWork, _) = calculateNetWorkAndOvertime(
            nowPoint: nowPoint,
            segments: segments,
            threshold: schedule.overtimeThresholdSeconds
        )

        let totalWork = schedule.totalWorkSecondsToday
        let baseDaily = schedule.dailyEarnings
        let perSecondBase = totalWork > 0 ? baseDaily / Double(totalWork) : 0
        let perSecondOT = schedule.overtimeRate * perSecondBase
        // 基础工时 = min(净工作, 阈值)，加班 = max(0, 净工作 - 阈值)
        let threshold = schedule.overtimeThresholdSeconds
        let baseSeconds: Int
        let otSeconds: Int
        if threshold > 0 {
            baseSeconds = min(netWork, threshold)
            otSeconds = max(0, netWork - threshold)
        } else {
            baseSeconds = netWork
            otSeconds = 0
        }
        let earned = Double(baseSeconds) * perSecondBase + Double(otSeconds) * perSecondOT

        let percent: Double = totalWork > 0 ? Double(netWork) / Double(totalWork) : 0

        let notStarted = nowPoint < workStartPoint
        let completed = nowPoint >= workEndPoint

        return EarningResult(
            passedWorkSeconds: netWork,
            totalWorkSeconds: totalWork,
            overtimeSeconds: otSeconds,
            percent: percent,
            earned: earned,
            dailyEarnings: baseDaily,
            notStartedYet: notStarted,
            completed: completed
        )
    }

    // MARK: - 内部辅助

    /// 工作段（work）或休息段（break）
    private struct Segment {
        enum Kind { case work, `break` }
        let kind: Kind
        let start: TimePoint
        let end: TimePoint
    }

    private static func pointOf(date: Date, anchor: Date, calendar: Calendar) -> TimePoint {
        let dayDelta = calendar.dateComponents([.day], from: startOfDay(anchor, calendar: calendar), to: startOfDay(date, calendar: calendar)).day ?? 0
        let secs = secondsInDay(date: date, calendar: calendar)
        return TimePoint(dayOffset: dayDelta, secondsInDay: secs)
    }

    private static func pointOfDay(seconds: Int, dayOffset: Int, anchor: Date, calendar: Calendar) -> TimePoint {
        return TimePoint(dayOffset: dayOffset, secondsInDay: seconds)
    }

    private static func startOfDay(_ date: Date, calendar: Calendar) -> Date {
        return calendar.startOfDay(for: date)
    }

    private static func secondsInDay(date: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0)
    }

    private static func buildSegments(
        schedule: WorkSchedule,
        workStartDayOffset: Int,
        calendar: Calendar
    ) -> [Segment] {
        let ws = TimePoint(dayOffset: workStartDayOffset, secondsInDay: schedule.workStartSeconds)
        let we = TimePoint(
            dayOffset: workStartDayOffset + (schedule.crossesMidnight ? 1 : 0),
            secondsInDay: schedule.workEndSeconds
        )
        var segs: [Segment] = [.init(kind: .work, start: ws, end: we)]
        for b in schedule.breaks {
            // 休息时段假定在工作日内（不跨午夜）
            let bs = TimePoint(dayOffset: workStartDayOffset, secondsInDay: b.startSeconds)
            let be = TimePoint(dayOffset: workStartDayOffset, secondsInDay: b.endSeconds)
            // 截断到工作范围内
            let clippedStart = maxPoint(bs, ws)
            let clippedEnd = minPoint(be, we)
            if clippedStart < clippedEnd {
                segs.append(.init(kind: .break, start: clippedStart, end: clippedEnd))
            }
        }
        return segs
    }

    /// 计算净工作秒数 + 加班秒数
    /// 净工作 = 已过工作段时长 - 已过休息段时长（且不超出总工作段）
    private static func calculateNetWorkAndOvertime(
        nowPoint: TimePoint,
        segments: [Segment],
        threshold: Int
    ) -> (netSeconds: Int, overtimeSeconds: Int) {
        // 已过的「工作段」时长（毛）
        let workSegs = segments.filter { $0.kind == .work }
        var grossWork = 0
        for seg in workSegs {
            let e = minPoint(seg.end, nowPoint)
            if e > seg.start {
                grossWork += deltaSeconds(from: seg.start, to: e)
            }
        }
        // 已过的「休息段」时长（在工作段内的）
        let breakSegs = segments.filter { $0.kind == .break }
        var breakPassed = 0
        for seg in breakSegs {
            let e = minPoint(seg.end, nowPoint)
            if e > seg.start {
                breakPassed += deltaSeconds(from: seg.start, to: e)
            }
        }
        let netWork = max(0, grossWork - breakPassed)
        // 加班 = 超过阈值的部分
        let overtime = threshold > 0 ? max(0, netWork - threshold) : 0
        return (netWork, overtime)
    }

    /// 两个 TimePoint 之间的秒数（end > start 时为正）
    private static func deltaSeconds(from: TimePoint, to: TimePoint) -> Int {
        if to <= from { return 0 }
        let dayDiff = to.dayOffset - from.dayOffset
        return dayDiff * 86400 + (to.secondsInDay - from.secondsInDay)
    }

    private static func minPoint(_ a: TimePoint, _ b: TimePoint) -> TimePoint {
        if a.dayOffset != b.dayOffset { return a.dayOffset < b.dayOffset ? a : b }
        return a.secondsInDay <= b.secondsInDay ? a : b
    }

    private static func maxPoint(_ a: TimePoint, _ b: TimePoint) -> TimePoint {
        if a.dayOffset != b.dayOffset { return a.dayOffset > b.dayOffset ? a : b }
        return a.secondsInDay >= b.secondsInDay ? a : b
    }
}
