//
//  MonthlyReportView.swift
//  MoneyProgress
//
//  月度报告（Feature 53）
//  自动汇总本月赚了多少、加班时长、最高日
//

import SwiftUI

struct MonthlyReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let menubar: Menubar

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(AppTheme.goldGradient)
                    .font(.system(size: 20, weight: .bold))
                Text("report.title".localized)
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

            if let summary = monthlySummary {
                // 4 个数据指标
                HStack(spacing: 10) {
                    statCard(title: "report.total".localized,
                            value: String(format: "%.2f", summary.total),
                            unit: "元",
                            color: AppTheme.gold,
                            icon: "dollarsign.circle.fill")
                    statCard(title: "report.workDays".localized,
                            value: "\(summary.workDays)",
                            unit: "天",
                            color: AppTheme.mint,
                            icon: "calendar")
                    statCard(title: "report.avgDaily".localized,
                            value: String(format: "%.0f", summary.avg),
                            unit: "元/天",
                            color: AppTheme.cyan,
                            icon: "chart.line.uptrend.xyaxis")
                    statCard(title: "report.peak".localized,
                            value: String(format: "%.0f", summary.peak),
                            unit: "元",
                            color: AppTheme.pink,
                            icon: "star.fill")
                }

                Divider()

                // 加班 + 休息日
                HStack {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundStyle(AppTheme.purple)
                        Text("report.overtime".localized)
                        Text(formatOvertime(summary.totalOvertime))
                            .font(.system(.callout, design: .rounded).bold())
                            .foregroundStyle(AppTheme.purple)
                    }
                    Spacer()
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AppTheme.gold)
                        Text("report.restDays".localized)
                        Text("\(summary.restDays) 天")
                            .font(.system(.callout, design: .rounded).bold())
                            .foregroundStyle(AppTheme.gold)
                    }
                }
                .font(.callout)

                // 鼓励语
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.encourageText)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.primaryText(scheme: colorScheme))
                    Text(summary.dateRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.cardSurface(scheme: colorScheme))
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("report.empty".localized)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)  // 关键：撑满 frame 并顶部对齐
        .background(WindowBackground(scheme: colorScheme))
    }

    private var monthlySummary: MonthlySummary? {
        guard let records = menubar.snapshotHistory(), !records.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        let nowKey = fmt.string(from: Date())
        let monthRecords = records.filter { $0.dateKey.hasPrefix(nowKey) }
        guard !monthRecords.isEmpty else { return nil }

        let total = monthRecords.reduce(0.0) { $0 + $1.earned }
        let workDays = monthRecords.filter { !$0.isRestDay }.count
        let restDays = monthRecords.filter { $0.isRestDay }.count
        let peak = monthRecords.map(\.earned).max() ?? 0
        let avg = workDays > 0 ? total / Double(workDays) : 0
        let totalOvertime = monthRecords.reduce(0) { $0 + $1.overtimeSeconds }

        // 日期范围
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "MM/dd"
        let first = monthRecords.first?.dateKey ?? ""
        let last = monthRecords.last?.dateKey ?? ""
        let dateRange = "本周期：\(first) - \(last)"

        // 鼓励
        let encourage: String
        if total >= 30_000 {
            encourage = "🏆 收入达人！本月表现超群"
        } else if total >= 20_000 {
            encourage = "🎉 表现优秀！继续保持"
        } else if total >= 10_000 {
            encourage = "💪 稳步前行，下月再战"
        } else if total > 0 {
            encourage = "🚀 起步阶段，加油"
        } else {
            encourage = "📊 暂无收入数据"
        }

        return MonthlySummary(
            total: total,
            workDays: workDays,
            restDays: restDays,
            avg: avg,
            peak: peak,
            totalOvertime: totalOvertime,
            dateRange: dateRange,
            encourageText: encourage
        )
    }

    private func statCard(title: String, value: String, unit: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cardSurface(scheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.cardStroke(scheme: colorScheme), lineWidth: 1)
        )
    }

    private func formatOvertime(_ sec: Int) -> String {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct MonthlySummary {
    let total: Double
    let workDays: Int
    let restDays: Int
    let avg: Double
    let peak: Double
    let totalOvertime: Int
    let dateRange: String
    let encourageText: String
}
