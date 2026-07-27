//
//  GoalSettingView.swift
//  MoneyProgress
//
//  目标/里程碑设置（Feature 55）
//  月度收入目标 + 连续工作日 streak 目标
//

import SwiftUI

struct GoalSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var schedule: WorkSchedule
    /// 当前货币单位（从 ContentView 传入，避免 UserDefaults 未初始化 fallback）
    let currencyUnit: String
    let onChange: () -> Void

    @State private var monthlyGoalStr: String = ""
    @State private var streakGoalStr: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题栏
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(AppTheme.goldGradient)
                    .font(.system(size: 20, weight: .bold))
                Text("ui.title.goals".localized)
                    .font(.system(.title3, design: .rounded).bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                }
                .buttonStyle(.plain)
            }

            Divider()

            Text("goal.intro".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            // 月度目标
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "target")
                        .foregroundStyle(AppTheme.gold)
                    Text("goal.monthly".localized)
                        .font(.system(.callout, design: .rounded).bold())
                }
                HStack {
                    TextField("goal.monthlyPlaceholder".localized, text: $monthlyGoalStr)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: monthlyGoalStr) { v in
                            let cents = (Int(v) ?? 0) * 100
                            schedule.monthlyGoalCents = cents
                            onChange()
                        }
                    Text(currencyDisplayShort)
                        .foregroundStyle(.secondary)
                }
                if schedule.monthlyGoalCents > 0 {
                    Text(String(format: "goal.dailyHint".localized,
                                dailyGoalEstimate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Streak 目标
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(AppTheme.pink)
                    Text("goal.streak".localized)
                        .font(.system(.callout, design: .rounded).bold())
                }
                HStack {
                    TextField("goal.streakPlaceholder".localized, text: $streakGoalStr)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: streakGoalStr) { v in
                            schedule.streakGoal = Int(v) ?? 0
                            onChange()
                        }
                    Text("goal.days".localized)
                        .foregroundStyle(.secondary)
                }
                Text("goal.streakHint".localized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 提示
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppTheme.cyan)
                Text("goal.tip".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.cardSurface(scheme: colorScheme)))

            Spacer()

            // 操作
            HStack {
                Button(role: .destructive) {
                    schedule.monthlyGoalCents = 0
                    schedule.dailyGoalOverrideCents = 0
                    schedule.streakGoal = 0
                    monthlyGoalStr = ""
                    streakGoalStr = ""
                    onChange()
                } label: {
                    Text("ui.clearAll".localized)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("ui.done".localized)
                        .font(.system(.callout, design: .rounded).bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.gold)
            }
        }
        .padding(20)
        .frame(width: 460, height: 440)
        .background(WindowBackground(scheme: colorScheme))
        .onAppear {
            monthlyGoalStr = schedule.monthlyGoalCents > 0
                ? String(schedule.monthlyGoalCents / 100) : ""
            streakGoalStr = schedule.streakGoal > 0
                ? String(schedule.streakGoal) : ""
        }
    }

    private var dailyGoalEstimate: String {
        let daily = Double(schedule.monthlyGoalCents) / 100.0 / Double(max(1, schedule.dayWorkOfMonth))
        return String(format: "%.0f", daily)
    }

    private var currencyDisplayShort: String {
        UserDefaults.standard.string(forKey: "wiki.qaq.currencyUnit") == "CNY" ? "元" : "USD"
    }
}
