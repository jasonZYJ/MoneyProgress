//
//  Constants.swift
//  MoneyProgress
//
//  全局常量（替代散落的 magic numbers）
//

import Foundation

// MARK: - 历史数据

/// 历史记录保留天数（最多保留 1 年）
let HistoryRetentionDays: Int = 365

/// 历史图表默认显示天数
let HistoryDefaultDays: Int = 14

// MARK: - 加班

/// 加班默认阈值（8 小时）
let OvertimeDefaultThresholdSeconds: Int = 8 * 3600

/// 加班默认费率（1.5x）
let OvertimeDefaultRate: Double = 1.5

/// 加班费率最小值
let OvertimeMinRate: Double = 1.0

// MARK: - 班次模板（Feature 11）

/// 班次模板预设
struct ShiftTemplate: Identifiable, Equatable {
    let id: String
    let nameKey: String       // Localizable 键
    let workStart: Int        // 当天秒数
    let workEnd: Int          // 当天秒数
    let breaks: [BreakPeriod]
    let daysPerMonth: Int
    let overtimeThreshold: Int
    let overtimeRate: Double

    static let presets: [ShiftTemplate] = [
        .init(id: "standard", nameKey: "shift.standard",
              workStart: 9 * 3600, workEnd: 18 * 3600,
              breaks: [BreakPeriod(startSeconds: 12 * 3600, endSeconds: 13 * 3600 + 30 * 60)],
              daysPerMonth: 22,
              overtimeThreshold: 0, overtimeRate: 1.0),
        .init(id: "size996", nameKey: "shift.996",
              workStart: 9 * 3600, workEnd: 21 * 3600,
              breaks: [BreakPeriod(startSeconds: 12 * 3600, endSeconds: 13 * 3600),
                       BreakPeriod(startSeconds: 18 * 3600, endSeconds: 18 * 3600 + 30 * 60)],
              daysPerMonth: 26,
              overtimeThreshold: 0, overtimeRate: 1.0),
        .init(id: "size995", nameKey: "shift.995",
              workStart: 9 * 3600, workEnd: 21 * 3600,
              breaks: [BreakPeriod(startSeconds: 12 * 3600, endSeconds: 13 * 3600)],
              daysPerMonth: 26,
              overtimeThreshold: 0, overtimeRate: 1.0),
        .init(id: "swing", nameKey: "shift.swing",
              workStart: 15 * 3600, workEnd: 24 * 3600,
              breaks: [BreakPeriod(startSeconds: 19 * 3600, endSeconds: 19 * 3600 + 30 * 60)],
              daysPerMonth: 22,
              overtimeThreshold: 0, overtimeRate: 1.0),
        .init(id: "night", nameKey: "shift.night",
              workStart: 22 * 3600, workEnd: 6 * 3600,
              breaks: [BreakPeriod(startSeconds: 2 * 3600, endSeconds: 2 * 3600 + 30 * 60)],
              daysPerMonth: 22,
              overtimeThreshold: 0, overtimeRate: 1.5),
        .init(id: "partTime", nameKey: "shift.partTime",
              workStart: 14 * 3600, workEnd: 18 * 3600,
              breaks: [],
              daysPerMonth: 15,
              overtimeThreshold: 0, overtimeRate: 1.0),
    ]
}

// MARK: - 输入校验

/// 月薪最大（元，防御性）
let MonthPaidMax: Int = 10_000_000

/// 每月工作天数范围
let DayWorkMin: Int = 1
let DayWorkMax: Int = 31

// MARK: - 调度 / 性能

/// TextField 防抖（毫秒）
let InputDebounceMs: Int = 300

/// 进度条刷新间隔（秒）
let TickIntervalSeconds: TimeInterval = 1.0
