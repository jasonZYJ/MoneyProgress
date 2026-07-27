//
//  AppTheme.swift
//  MoneyProgress
//
//  共享主题（亮/暗自适应）- 鲜亮高饱和版本
//

import SwiftUI

// MARK: - 主题色

enum AppTheme {
    /// 主渐变：鲜亮金黄 → 橙红（高饱和）
    static let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.92, blue: 0.20), Color(red: 1.0, green: 0.55, blue: 0.05)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// 进度渐变：鲜绿 → 金黄
    static let progressGradient = LinearGradient(
        colors: [Color(red: 0.10, green: 1.0, blue: 0.50), Color(red: 1.0, green: 0.90, blue: 0.15)],
        startPoint: .leading, endPoint: .trailing
    )
    /// 加班渐变：粉红 → 紫
    static let overtimeGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.30, blue: 0.55), Color(red: 0.60, green: 0.30, blue: 1.0)],
        startPoint: .leading, endPoint: .trailing
    )
    /// 节假日渐变
    static let holidayGradient = LinearGradient(
        colors: [Color(red: 0.60, green: 0.30, blue: 1.0), Color(red: 1.0, green: 0.30, blue: 0.55)],
        startPoint: .leading, endPoint: .trailing
    )
    /// 青色渐变
    static let cyanGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.95, blue: 1.0), Color(red: 0.20, green: 0.45, blue: 1.0)],
        startPoint: .leading, endPoint: .trailing
    )
    /// 珊瑚红渐变
    static let coralGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.50, blue: 0.45), Color(red: 1.0, green: 0.70, blue: 0.25)],
        startPoint: .leading, endPoint: .trailing
    )

    /// 强语义色（鲜亮高饱和 — 看着开心系列）
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.10)        // 金黄
    static let goldDeep = Color(red: 1.0, green: 0.60, blue: 0.10)    // 橙金
    static let mint = Color(red: 0.05, green: 0.95, blue: 0.55)        // 鲜绿
    static let mintDeep = Color(red: 0.00, green: 0.80, blue: 0.40)    // 深绿
    static let pink = Color(red: 1.0, green: 0.30, blue: 0.60)         // 粉红
    static let purple = Color(red: 0.65, green: 0.35, blue: 1.0)       // 鲜紫
    static let cyan = Color(red: 0.20, green: 0.90, blue: 1.0)         // 鲜青
    static let coral = Color(red: 1.0, green: 0.45, blue: 0.40)        // 珊瑚红

    /// CNY → "元"，其他 → 原代码
    static func currencyLabel(_ code: String) -> String {
        code == "CNY" ? "元" : code
    }
}

// MARK: - Color 语义扩展（亮/暗自动适配）

extension Color {
    /// 卡片背景（毛玻璃感，浅色更柔和高亮）
    static func cardSurface(scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.white.opacity(0.95)
    }

    /// 卡片描边
    static func cardStroke(scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.15)
            : Color.black.opacity(0.06)
    }

    /// 主要文字（暗色白，亮色深灰不刺眼）
    static func primaryText(scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.10, green: 0.10, blue: 0.15)
    }

    /// 次要文字
    static func secondaryText(scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.60) : Color(red: 0.40, green: 0.40, blue: 0.45)
    }
}

// MARK: - 自适应背景 View

/// 窗口背景（主窗口铺满）- 鲜亮暖色
struct WindowBackground: View {
    let scheme: ColorScheme
    var body: some View {
        if scheme == .dark {
            // 暗色：深紫黑 + 微弱光斑
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.16),
                    Color(red: 0.18, green: 0.10, blue: 0.20),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            // 浅色：鲜亮暖色渐变（看着开心！）
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.97, blue: 0.88),    // 暖白
                    Color(red: 1.0, green: 0.92, blue: 0.80),    // 浅杏
                    Color(red: 1.0, green: 0.85, blue: 0.70),    // 桃色
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}

/// 弹窗背景（菜单栏 popover）
struct PopoverBackground: View {
    let scheme: ColorScheme
    var body: some View {
        if scheme == .dark {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.10, blue: 0.18),
                    Color(red: 0.20, green: 0.12, blue: 0.22),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            // 浅色：温暖米色
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.97, blue: 0.88),
                    Color(red: 1.0, green: 0.93, blue: 0.82),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}
