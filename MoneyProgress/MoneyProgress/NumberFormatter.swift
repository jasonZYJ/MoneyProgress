//
//  NumberFormatter.swift
//  MoneyProgress
//
//  数字格式化工具（P2 #19）：自动 k/m 格式
//  1234 → "1.2k"，0.0154 → "0.02"，12345 → "12.3k"
//

import Foundation

enum NumberFormatter {
    /// 智能格式化金额：自动 k/m 单位
    /// - Parameter value: 金额（元）
    /// - Returns: 格式化字符串
    static func smartCurrency(_ value: Double) -> String {
        let absV = abs(value)
        if absV >= 10_000 {
            return String(format: "%.1fk", value / 1000)
        } else if absV >= 1_000 {
            return String(format: "%.2fk", value / 1000)
        } else if absV >= 100 {
            return String(format: "%.0f", value)
        } else if absV >= 1 {
            return String(format: "%.2f", value)
        } else if absV >= 0.01 {
            return String(format: "%.4f", value)
        } else if absV > 0 {
            return String(format: "%.6f", value)
        } else {
            return "0"
        }
    }

    /// 简短数字：用于指标卡 16pt 字号
    static func compact(_ value: Double) -> String {
        let absV = abs(value)
        if absV >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if absV >= 1_000 {
            return String(format: "%.1fk", value / 1000)
        } else {
            return String(format: "%.2f", value)
        }
    }
}
