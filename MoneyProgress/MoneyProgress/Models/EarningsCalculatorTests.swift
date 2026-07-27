//
//  EarningsCalculatorTests.swift
//  MoneyProgress
//
//  单元测试（独立 main，可直接 swiftc 编译运行）
//  编译: swiftc -O EarningsCalculatorTests.swift WorkSchedule.swift EarningsCalculator.swift -o tests && ./tests
//

import Foundation

// MARK: - 微型测试框架

var testPassed = 0
var testFailed = 0
var testFailedNames: [String] = []

func assertEq<T: Equatable>(_ actual: T, _ expected: T, _ name: String, _ msg: String = "") {
    if actual == expected {
        testPassed += 1
    } else {
        testFailed += 1
        testFailedNames.append(name)
        print("❌ \(name) [\(msg)]: expected \(expected), got \(actual)")
    }
}

func assertApprox(_ actual: Double, _ expected: Double, _ name: String, _ tolerance: Double = 0.01, _ msg: String = "") {
    if abs(actual - expected) <= tolerance {
        testPassed += 1
    } else {
        testFailed += 1
        testFailedNames.append(name)
        print("❌ \(name) [\(msg)]: expected \(expected), got \(actual)")
    }
}

func assertTrue(_ cond: Bool, _ name: String, _ msg: String = "") {
    if cond {
        testPassed += 1
    } else {
        testFailed += 1
        testFailedNames.append(name)
        print("❌ \(name) [\(msg)]")
    }
}

func section(_ name: String) {
    print("\n— \(name) —")
}

// MARK: - 测试辅助

func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, sec: Int = 0) -> Date {
    var c = DateComponents()
    c.year = year; c.month = month; c.day = day
    c.hour = hour; c.minute = minute; c.second = sec
    c.timeZone = TimeZone(identifier: "Asia/Shanghai")
    return Calendar(identifier: .gregorian).date(from: c)!
}

func basicSchedule(
    workStart: Int = 9 * 3600,
    workEnd: Int = 18 * 3600,
    breaks: [BreakPeriod] = [BreakPeriod(startSeconds: 12 * 3600, endSeconds: 14 * 3600)],
    monthPaidCents: Int = 20_000_00,
    dayWorkOfMonth: Int = 20,
    overtimeRate: Double = 1.0,
    overtimeThresholdSeconds: Int = 0
) -> WorkSchedule {
    WorkSchedule(
        workStartSeconds: workStart,
        workEndSeconds: workEnd,
        breaks: breaks,
        monthPaidCents: monthPaidCents,
        dayWorkOfMonth: dayWorkOfMonth,
        workdays: WorkdaySet([2, 3, 4, 5, 6]),
        overtimeRate: overtimeRate,
        overtimeThresholdSeconds: overtimeThresholdSeconds,
        customHolidays: [],
        workOnWeekends: false,
        monthlyGoalCents: 0,
        dailyGoalOverrideCents: 0,
        streakGoal: 0
    )
}

// MARK: - 主入口

@main
struct TestRunner {
    static func main() {
        test_basicSchedule()
        test_crossMidnight()
        test_overtime()
        test_noLunch()
        test_multiBreak()
        test_edgeCases()
        test_workdaySet()
        test_effectiveSpan()
        test_holiday()
        test_consistency()
        printSummary()
    }

    static func printSummary() {
        print("\n========================================")
        print("✅ Passed: \(testPassed)    ❌ Failed: \(testFailed)")
        if testFailed > 0 {
            print("Failed tests:")
            for n in testFailedNames { print("  - \(n)") }
            exit(1)
        } else {
            print("All tests passed!")
            exit(0)
        }
    }
}

// MARK: - 1. 基础

func test_basicSchedule() {
    section("1. 基础：9-18 + 12-14 午休，月薪 20000")
    let s = basicSchedule()

    // 9:00 整 上班
    let r1 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 24, hour: 9, minute: 0)
    )
    assertTrue(!r1.notStartedYet, "9:00 整 已开始")
    assertTrue(r1.passedWorkSeconds == 0, "9:00 整 passed=0")
    assertEq(r1.totalWorkSeconds, 7 * 3600, "totalWork=7h", "got \(r1.totalWorkSeconds)")

    // 10:30
    let r2 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 24, hour: 10, minute: 30)
    )
    assertEq(r2.passedWorkSeconds, 90 * 60, "10:30 passed=1.5h", "got \(r2.passedWorkSeconds)")

    // 13:00 午休中（应冻结在 3h）
    let r3 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 24, hour: 13, minute: 0)
    )
    assertEq(r3.passedWorkSeconds, 3 * 3600, "13:00 午休中 passed=3h", "got \(r3.passedWorkSeconds)")

    // 14:30 = 9-12 (3h) + 14-14:30 (0.5h) = 3.5h
    let r4 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 24, hour: 14, minute: 30)
    )
    assertEq(r4.passedWorkSeconds, Int(3.5 * 3600), "14:30 passed=3.5h", "got \(r4.passedWorkSeconds)")

    // 18:00 完成
    let r5 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 24, hour: 18, minute: 0)
    )
    assertEq(r5.passedWorkSeconds, 7 * 3600, "18:00 passed=7h")
    assertTrue(r5.completed, "18:00 completed")

    // 21:00 下班后（仍 7h）
    let r6 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 24, hour: 21, minute: 0)
    )
    assertEq(r6.passedWorkSeconds, 7 * 3600, "21:00 passed=7h（封顶）")
    assertApprox(r6.earned, 1000.0, "21:00 earned=daily=1000", 0.01, "got \(r6.earned)")

    // 7:00 上班前
    let r7 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 24, hour: 7, minute: 0)
    )
    assertTrue(r7.notStartedYet, "7:00 上班前 notStarted")
}

// MARK: - 2. 跨午夜

func test_crossMidnight() {
    section("2. 跨午夜：22:00 → 次日 06:00（夜班）")
    let night = basicSchedule(workStart: 22 * 3600, workEnd: 6 * 3600, breaks: [])
    assertTrue(night.crossesMidnight, "crossesMidnight=true")
    assertEq(night.totalWorkSecondsToday, 8 * 3600, "夜班 total=8h")

    // 22:00 整
    let r1 = EarningsCalculator.compute(
        schedule: night, now: makeDate(year: 2026, month: 7, day: 24, hour: 22, minute: 0)
    )
    assertTrue(!r1.notStartedYet, "22:00 整 已开始")
    assertTrue(r1.passedWorkSeconds == 0, "22:00 整 passed=0")

    // 23:30 = 1.5h
    let r2 = EarningsCalculator.compute(
        schedule: night, now: makeDate(year: 2026, month: 7, day: 24, hour: 23, minute: 30)
    )
    assertEq(r2.passedWorkSeconds, Int(1.5 * 3600), "23:30 passed=1.5h", "got \(r2.passedWorkSeconds)")

    // 次日 02:00 = 4h
    let r3 = EarningsCalculator.compute(
        schedule: night, now: makeDate(year: 2026, month: 7, day: 25, hour: 2, minute: 0)
    )
    assertEq(r3.passedWorkSeconds, 4 * 3600, "次日 02:00 passed=4h", "got \(r3.passedWorkSeconds)")

    // 次日 06:00 完成
    let r4 = EarningsCalculator.compute(
        schedule: night, now: makeDate(year: 2026, month: 7, day: 25, hour: 6, minute: 0)
    )
    assertEq(r4.passedWorkSeconds, 8 * 3600, "次日 06:00 passed=8h")
    assertTrue(r4.completed, "次日 06:00 completed")

    // 21:00 还没到 22:00
    let r5 = EarningsCalculator.compute(
        schedule: night, now: makeDate(year: 2026, month: 7, day: 24, hour: 21, minute: 0)
    )
    assertTrue(r5.notStartedYet, "21:00 夜班前 notStarted")
}

// MARK: - 3. 加班

func test_overtime() {
    section("3. 加班：threshold=4h，超 4h 算 1.5x")
    let ot = basicSchedule(
        workStart: 9 * 3600,
        workEnd: 18 * 3600,
        breaks: [BreakPeriod(startSeconds: 12 * 3600, endSeconds: 13 * 3600)],
        overtimeRate: 1.5,
        overtimeThresholdSeconds: 4 * 3600
    )
    // totalWork = 9h - 1h = 8h
    assertEq(ot.totalWorkSecondsToday, 8 * 3600, "OT totalWork=8h")

    // 17:30 = 净工作 7.5h, 加班 3.5h
    let r2 = EarningsCalculator.compute(
        schedule: ot, now: makeDate(year: 2026, month: 7, day: 24, hour: 17, minute: 30)
    )
    assertEq(r2.overtimeSeconds, Int(3.5 * 3600), "17:30 overtime=3.5h", "got \(r2.overtimeSeconds)")
    // base = 4h * (1000/8h) = 500
    // OT = 3.5h * 1.5 * (1000/8h) = 656.25
    // earned = 500 + 656.25 = 1156.25
    let expectedOT = 4.0 * (1000.0 / 8.0) + 3.5 * 1.5 * (1000.0 / 8.0)
    assertApprox(r2.earned, expectedOT, "17:30 OT earned", 0.1, "expected \(expectedOT), got \(r2.earned)")

    // 13:00 午休中 = 净工作 3h, 未到加班
    let r1 = EarningsCalculator.compute(
        schedule: ot, now: makeDate(year: 2026, month: 7, day: 24, hour: 13, minute: 0)
    )
    assertEq(r1.overtimeSeconds, 0, "13:00 overtime=0", "got \(r1.overtimeSeconds)")
    assertApprox(r1.earned, 3.0 * (1000.0 / 8.0), "13:00 earned=base only", 0.1)
}

// MARK: - 4. 无午休

func test_noLunch() {
    section("4. 无午休：纯 9-18，total=9h")
    let noLunch = basicSchedule(workStart: 9 * 3600, workEnd: 18 * 3600, breaks: [])
    assertEq(noLunch.totalWorkSecondsToday, 9 * 3600, "无午休 total=9h")

    let r1 = EarningsCalculator.compute(
        schedule: noLunch, now: makeDate(year: 2026, month: 7, day: 24, hour: 12, minute: 0)
    )
    assertEq(r1.passedWorkSeconds, 3 * 3600, "12:00 noLunch passed=3h")
}

// MARK: - 5. 多休息

func test_multiBreak() {
    section("5. 多休息：10-10:15 茶歇 + 12-14 午休")
    let mb = basicSchedule(breaks: [
        BreakPeriod(startSeconds: 10 * 3600, endSeconds: 10 * 3600 + 15 * 60),
        BreakPeriod(startSeconds: 12 * 3600, endSeconds: 14 * 3600),
    ])
    // totalWork = 9h - 15m - 2h = 6h45m = 24300s
    assertEq(mb.totalWorkSecondsToday, 24300, "多休息 total=6h45m", "got \(mb.totalWorkSecondsToday)")

    // 10:30 = 9-10 (1h) - 10-10:15 (15m) = 45m
    let r1 = EarningsCalculator.compute(
        schedule: mb, now: makeDate(year: 2026, month: 7, day: 24, hour: 10, minute: 30)
    )
    assertEq(r1.passedWorkSeconds, 75 * 60, "10:30 passed=75min (90-15)", "got \(r1.passedWorkSeconds)")
}

// MARK: - 6. 边界

func test_edgeCases() {
    section("6. 边界")
    // workStart == workEnd (无效)
    let zero = basicSchedule(workStart: 9 * 3600, workEnd: 9 * 3600)
    let rZ = EarningsCalculator.compute(
        schedule: zero, now: makeDate(year: 2026, month: 7, day: 24, hour: 10, minute: 0)
    )
    assertEq(rZ.passedWorkSeconds, 0, "无效班次 passed=0")
    assertApprox(rZ.earned, 0, "无效班次 earned=0", 0.001)

    // dayWorkOfMonth = 0
    let divZero = basicSchedule(dayWorkOfMonth: 0)
    let rD = EarningsCalculator.compute(
        schedule: divZero, now: makeDate(year: 2026, month: 7, day: 24, hour: 12, minute: 0)
    )
    assertApprox(rD.earned, 0, "dayWorkOfMonth=0 不崩", 0.001)

    // monthPaid = 0
    let zeroPay = basicSchedule(monthPaidCents: 0)
    let rZP = EarningsCalculator.compute(
        schedule: zeroPay, now: makeDate(year: 2026, month: 7, day: 24, hour: 12, minute: 0)
    )
    assertApprox(rZP.earned, 0, "monthPaid=0 不崩", 0.001)
}

// MARK: - 7. WorkdaySet

func test_workdaySet() {
    section("7. WorkdaySet")
    var ws = WorkdaySet([2, 3, 4, 5, 6])
    assertTrue(ws.contains(2), "周一 contains")
    assertTrue(ws.contains(6), "周五 contains")
    assertTrue(!ws.contains(7), "周六 不 contains")
    assertTrue(!ws.contains(1), "周日 不 contains")
    ws.toggle(day: 7)
    assertTrue(ws.contains(7), "toggle 后 周六 contains")
    ws.set(day: 1)
    assertTrue(ws.contains(1), "set 后 周日 contains")
}

// MARK: - 8. effectiveSpan

func test_effectiveSpan() {
    section("8. effectiveSpanSeconds 跨午夜")
    assertEq(WorkSchedule.effectiveSpanSeconds(start: 9 * 3600, end: 18 * 3600), 9 * 3600, "9-18 = 9h")
    assertEq(WorkSchedule.effectiveSpanSeconds(start: 22 * 3600, end: 6 * 3600), 8 * 3600, "22-06 = 8h")
    assertEq(WorkSchedule.effectiveSpanSeconds(start: 9 * 3600, end: 9 * 3600), 0, "相同=0")
}

// MARK: - 9. 节假日

func test_holiday() {
    section("9. 节假日")
    let holiday = HolidayCalendar(customHolidays: ["2026-07-25"])
    // 2026-07-25 是周六
    let sat = makeDate(year: 2026, month: 7, day: 25, hour: 12, minute: 0)
    let mon = makeDate(year: 2026, month: 7, day: 27, hour: 12, minute: 0)
    assertTrue(holiday.isRestDay(sat), "周六 是休息日")
    assertTrue(!holiday.isRestDay(mon), "周一 非假日")
    let custom = HolidayCalendar(customHolidays: ["2026-07-27"])
    assertTrue(custom.isRestDay(mon), "自定义假日 周一 是休息日")
}

// MARK: - 10. 一致性

func test_consistency() {
    section("10. 一致性：跨整天 passed 单调不减")
    let s = basicSchedule()
    var prev: Int = -1
    var allNonDecreasing = true
    let total = 7 * 3600
    var hits = 0
    for sec in stride(from: 0, to: 24 * 3600, by: 600) {  // 每 10 分钟采样
        let cal = Calendar(identifier: .gregorian)
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 24
        c.hour = sec / 3600; c.minute = (sec % 3600) / 60; c.second = 0
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let now = cal.date(from: c)!
        let r = EarningsCalculator.compute(schedule: s, now: now)
        // 上半段 (workStart 之前) passed = 0
        // 中间 (workStart ~ workEnd) passed 单调增（但可能在午休段持平）
        // 下半段 (workEnd 之后) passed = totalWork
        if r.passedWorkSeconds < prev { allNonDecreasing = false }
        prev = r.passedWorkSeconds
        if r.passedWorkSeconds > 0 && r.passedWorkSeconds < total { hits += 1 }
    }
    assertTrue(allNonDecreasing, "passed 单调不减")
    assertTrue(hits > 50, "中间段命中点足够多（hits=\(hits)）")

    // 验证：每日 totalWork 一致
    let total1 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 24, hour: 10)
    ).totalWorkSeconds
    let total2 = EarningsCalculator.compute(
        schedule: s, now: makeDate(year: 2026, month: 7, day: 25, hour: 10)
    ).totalWorkSeconds
    assertEq(total1, total2, "跨日 totalWork 一致")
}
