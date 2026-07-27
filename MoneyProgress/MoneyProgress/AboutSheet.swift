import SwiftUI

/// "关于" 弹窗：完整品牌信息
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let appVersion: String

    var body: some View {
        VStack(spacing: 18) {
            // 顶部：完整 logo
            BrandLogo(size: 96, showRing: true, progress: 0.75)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("薪辛".localized)
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(Color.primary)
                Text("EARNEST")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.goldDeep, AppTheme.pink],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .tracking(3)
            }

            // 渐变分隔线
            Rectangle()
                .fill(LinearGradient(
                    colors: [AppTheme.gold, AppTheme.pink, AppTheme.purple].map { $0.opacity(0.6) },
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 1)
                .padding(.horizontal, 20)

            VStack(spacing: 6) {
                infoRow(icon: "tag.fill", title: "版本".localized, value: appVersion)
                infoRow(icon: "person.fill", title: "作者".localized, value: "Lakr Aream".localized)
                infoRow(icon: "globe", title: "设计".localized, value: "金币 + 上升曲线 · 一体化")
            }
            .padding(.horizontal, 20)

            // 特性徽章
            HStack(spacing: 6) {
                featureChip(icon: "bolt.fill", text: "实时", color: AppTheme.gold)
                featureChip(icon: "chart.line.uptrend.xyaxis", text: "进度", color: AppTheme.mint)
                featureChip(icon: "calendar", text: "节假", color: AppTheme.purple)
            }
            .padding(.top, 4)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("好的".localized)
                    .font(.system(.body, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.gold, AppTheme.pink],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 360, height: 460)
        .background(
            LinearGradient(
                colors: [Color(white: 1.0), Color(red: 1.0, green: 0.96, blue: 0.90)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.goldDeep)
                .frame(width: 16)
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .rounded).bold())
                .foregroundStyle(.primary)
        }
    }

    private func featureChip(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(.caption2, design: .rounded).bold())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.15)))
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.5))
    }
}
