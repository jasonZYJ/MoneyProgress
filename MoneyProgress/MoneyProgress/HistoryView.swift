//
//  HistoryView.swift
//  MoneyProgress
//
//  历史统计面板（暗色适配 + 关闭按钮 + 鲜艳配色）
//

import Charts
import SwiftUI

struct HistoryView: View {
    @AppStorage("wiki.qaq.history.v1") private var rawHistory: String = ""

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var records: [DailyEarningRecord] = []
    @State private var range: Int = 14  // 默认 14 天

    private var displayRecords: [DailyEarningRecord] {
        let sorted = records.sorted { $0.dateKey > $1.dateKey }
        return Array(sorted.prefix(range)).reversed()
    }

    private var totalEarned: Double { displayRecords.reduce(0) { $0 + $1.earned } }
    private var avgDaily: Double {
        guard !displayRecords.isEmpty else { return 0 }
        return totalEarned / Double(displayRecords.count)
    }
    private var maxDaily: Double { displayRecords.map { $0.earned }.max() ?? 0 }
    private var overtimeTotalSeconds: Int { displayRecords.reduce(0) { $0 + $1.overtimeSeconds } }

    var body: some View {
        ZStack {
            // 自适应背景
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.10, blue: 0.16),
                        Color(red: 0.18, green: 0.12, blue: 0.20),
                        Color(red: 0.20, green: 0.10, blue: 0.16),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.95, blue: 0.85),
                        Color(red: 1.0, green: 0.88, blue: 0.78),
                        Color(red: 0.98, green: 0.83, blue: 0.92),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }

            // 柔光斑
            Circle()
                .fill(AppTheme.gold.opacity(colorScheme == .dark ? 0.15 : 0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -200, y: -120)
            Circle()
                .fill(AppTheme.purple.opacity(colorScheme == .dark ? 0.20 : 0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 250, y: 200)

            VStack(alignment: .leading, spacing: 12) {
                // 顶栏：标题 + 范围切换 + 关闭
                header
                // 概览卡片
                HStack(spacing: 10) {
                    StatCard(title: "累计".localized, value: String(format: "%.2f", totalEarned), unit: "元", color: AppTheme.gold, scheme: colorScheme)
                    StatCard(title: "日均".localized, value: String(format: "%.2f", avgDaily), unit: "元", color: AppTheme.mint, scheme: colorScheme)
                    StatCard(title: "峰值".localized, value: String(format: "%.2f", maxDaily), unit: "元", color: AppTheme.pink, scheme: colorScheme)
                    StatCard(title: "加班".localized, value: String(format: "%.1f", Double(overtimeTotalSeconds) / 3600.0), unit: "h", color: AppTheme.purple, scheme: colorScheme)
                }
                // 图表
                chartArea
                // 近期记录
                if !displayRecords.isEmpty {
                    Divider().background(Color.cardStroke(scheme: colorScheme))
                    recordsList
                }
                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadRecords() }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.goldGradient)
                Text("📊 历史统计".localized)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(Color.primaryText(scheme: colorScheme))
            }

            Spacer()

            Picker("", selection: $range) {
                Text("7d").tag(7)
                Text("14d").tag(14)
                Text("30d").tag(30)
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            // 显式关闭按钮
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.secondaryText(scheme: colorScheme))
            }
            .buttonStyle(.plain)
            .help("关闭".localized)
        }
    }

    // MARK: - 图表

    @ViewBuilder
    private var chartArea: some View {
        if displayRecords.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.purple.opacity(0.6))
                Text("暂无数据，运行应用后会自动累计".localized)
                    .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                    .font(.system(.callout, design: .rounded))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardSurface(scheme: colorScheme))
            )
        } else {
            Chart(displayRecords) { rec in
                let isRest = rec.isRestDay
                let baseEarned = isRest ? 0 : rec.earned
                BarMark(
                    x: .value("Date", shortDate(rec.dateKey)),
                    y: .value("Earned", baseEarned)
                )
                .foregroundStyle(isRest
                                  ? AnyShapeStyle(Color.gray.opacity(0.4))
                                  : AnyShapeStyle(AppTheme.goldGradient))
                .cornerRadius(4)
                .annotation(position: .top) {
                    if baseEarned > 0 {
                        Text(String(format: "%.0f", baseEarned))
                            .font(.system(size: 8, design: .rounded).bold())
                            .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let str = value.as(String.self) {
                            Text(str)
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(Double.self) {
                            Text(String(format: "%.0f", d))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                        }
                    }
                }
            }
            .frame(height: 220)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardSurface(scheme: colorScheme))
            )
        }
    }

    // MARK: - 近期记录

    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("📝 近期记录".localized)
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(Color.primaryText(scheme: colorScheme))
            ForEach(displayRecords.suffix(5).reversed()) { rec in
                HStack {
                    Text(rec.dateKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.primaryText(scheme: colorScheme))
                        .frame(width: 90, alignment: .leading)
                    if rec.isRestDay {
                        Text("🎉 休息日".localized)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(AppTheme.purple)
                    } else {
                        Text(String(format: "%.2f 元", rec.earned))
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(AppTheme.gold)
                        if rec.overtimeSeconds > 0 {
                            Text("+\(formatDuration(rec.overtimeSeconds)) OT")
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundStyle(AppTheme.pink)
                        }
                    }
                    Spacer()
                    Text("\(Int(rec.netWorkSeconds / 60)) min")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface(scheme: colorScheme))
        )
    }

    // MARK: - 工具

    private func loadRecords() {
        guard let data = rawHistory.data(using: .utf8),
              let arr = try? JSONDecoder().decode([DailyEarningRecord].self, from: data) else {
            records = []
            return
        }
        records = arr
    }

    private func shortDate(_ key: String) -> String {
        guard key.count >= 10 else { return key }
        let idx = key.index(key.startIndex, offsetBy: 5)
        return String(key[idx...])
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h\(m)m" }
        return "\(m)m"
    }
}

// MARK: - 统计卡片

private struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let scheme: ColorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.secondaryText(scheme: scheme))
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Color.secondaryText(scheme: scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(scheme == .dark ? 0.18 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(scheme == .dark ? 0.45 : 0.35), lineWidth: 1)
        )
    }
}
