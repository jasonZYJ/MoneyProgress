//
//  MenubarView.swift
//  MoneyProgress
//
//  Created by Lakr Aream on 2022/3/15.
//
//  暗色模式适配 + 渐变进度 + 毛玻璃卡片
//

import SwiftUI

struct MenubarView: View {
    @StateObject var menubar = Menubar.shared
    @Environment(\.colorScheme) private var colorScheme

    let myTitle = [
        "touch fish together".localized,
        "touch all can touch".localized,
        "Always touch fish".localized,
    ]

    let currentTitle: String

    @AppStorage("wiki.qaq.currencyUnit")
    var currencyUnit: String = "CNY"

    init() {
        currentTitle = myTitle.randomElement() ?? "touch fish"
    }

    var body: some View {
        ZStack {
            // 暖色/暗色渐变背景
            PopoverBackground(scheme: colorScheme)

            // 柔光斑
            Circle()
                .fill(AppTheme.gold.opacity(colorScheme == .dark ? 0.20 : 0.22))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: -120, y: -80)
            Circle()
                .fill(AppTheme.pink.opacity(colorScheme == .dark ? 0.22 : 0.18))
                .frame(width: 200, height: 200)
                .blur(radius: 65)
                .offset(x: 140, y: 80)
            Circle()
                .fill(AppTheme.purple.opacity(colorScheme == .dark ? 0.18 : 0.10))
                .frame(width: 180, height: 180)
                .blur(radius: 60)
                .offset(x: 100, y: -60)

            content
                .padding(16)
        }
        .frame(width: 380, height: 240)
    }

    // MARK: - 内容

    private var content: some View {
        VStack(spacing: 10) {
            // 顶部：大数字 + 状态
            HStack(alignment: .top, spacing: 12) {
                // 圆形进度环
                ZStack {
                    Circle()
                        .stroke(AppTheme.gold.opacity(0.15), lineWidth: 8)
                        .frame(width: 70, height: 70)
                    Circle()
                        .trim(from: 0, to: min(1.0, menubar.todayPercent))
                        .stroke(
                            menubar.isHoliday ? AppTheme.holidayGradient : AppTheme.goldGradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    if menubar.isHoliday {
                        Text("🎉")
                            .font(.system(size: 24))
                    } else {
                        Text(String(format: "%.0f%%", menubar.todayPercent * 100))
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(AppTheme.goldDeep)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Group {
                        if menubar.isHoliday {
                            Text("🎉 节假日快乐！".localized)
                                .foregroundStyle(AppTheme.overtimeGradient)
                        } else if menubar.todayPercent <= 0 {
                            Text("No work started today!".localized)
                        } else if menubar.todayPercent >= 1 {
                            Text("You have earned your full salary today!".localized)
                        } else {
                            Text(currentTitle)
                        }
                    }
                    .font(.system(.callout, design: .rounded).bold())
                    .foregroundStyle(Color.primaryText(scheme: colorScheme))

                    if !menubar.isHoliday {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundStyle(AppTheme.gold)
                                .font(.system(size: 12))
                            Text(String(format: "%.2f", menubar.todayEarn))
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundStyle(AppTheme.goldGradient)
                                .contentTransition(.numericText())
                            Text(currencyUnit)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 关闭/退出按钮
                VStack(spacing: 6) {
                    menuIconButton(icon: "macwindow", help: "打开主窗口".localized, tint: AppTheme.mintDeep) {
                        menubar.openMainWindow()
                    }
                    menuIconButton(icon: "xmark", help: "退出".localized, tint: .red.opacity(0.85)) {
                        NSApp.terminate(nil)
                    }
                }
            }

            // 进度条
            progressFillBar

            // 加班信息
            if menubar.todayOvertimeSeconds > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(AppTheme.overtimeGradient)
                    Text(String(format: "💼 加班 %d h %d min".localized,
                                menubar.todayOvertimeSeconds / 3600,
                                (menubar.todayOvertimeSeconds % 3600) / 60))
                        .font(.system(.caption, design: .rounded).bold())
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(AppTheme.pink.opacity(colorScheme == .dark ? 0.20 : 0.15))
                        .overlay(Capsule().stroke(AppTheme.pink.opacity(0.4), lineWidth: 1))
                )
                .foregroundStyle(AppTheme.pink)
            }

            Spacer(minLength: 0)
        }
    }

    private func menuIconButton(icon: String, help: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.cardSurface(scheme: colorScheme)))
                .overlay(Circle().stroke(Color.cardStroke(scheme: colorScheme), lineWidth: 1))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder
    private var progressFillBar: some View {
        GeometryReader { r in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.cardSurface(scheme: colorScheme))
                    .frame(height: 10)
                if menubar.isHoliday {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.purple.opacity(0.6))
                        .frame(width: r.size.width * min(1, menubar.todayPercent), height: 10)
                        .shadow(color: AppTheme.purple.opacity(0.5), radius: 3)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.progressGradient)
                        .frame(width: r.size.width * min(1, menubar.todayPercent), height: 10)
                        .shadow(color: AppTheme.gold.opacity(0.5), radius: 3)
                }
            }
        }
        .frame(height: 10)
    }
}
