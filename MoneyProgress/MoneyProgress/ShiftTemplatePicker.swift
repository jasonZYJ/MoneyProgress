//
//  ShiftTemplatePicker.swift
//  MoneyProgress
//
//  班次模板选择器（Feature 11）
//  一键切换朝九晚五/996/995/中班/夜班/兼职
//

import SwiftUI

struct ShiftTemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let onSelect: (ShiftTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "rectangle.stack.badge.plus")
                    .foregroundStyle(AppTheme.cyan)
                    .font(.system(size: 20, weight: .bold))
                Text("班次模板".localized)
                    .font(.system(.title3, design: .rounded).bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                }
                .buttonStyle(.plain)
            }

            Text("选择后自动填充工作时间、休息、加班等配置".localized)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(ShiftTemplate.presets) { t in
                        templateRow(t)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 440, height: 540)
        .background(WindowBackground(scheme: colorScheme))
    }

    private func templateRow(_ t: ShiftTemplate) -> some View {
        Button {
            onSelect(t)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [AppTheme.cyan, AppTheme.mint],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: iconFor(t.id))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.nameKey.localized)
                        .font(.system(.callout, design: .rounded).bold())
                        .foregroundStyle(Color.primaryText(scheme: colorScheme))
                    Text("\(formatTime(t.workStart)) - \(formatTime(t.workEnd))  ·  \(t.daysPerMonth) days/mo  ·  \(t.breaks.count) breaks")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.cardSurface(scheme: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cardStroke(scheme: colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ sec: Int) -> String {
        let h = sec / 3600
        let m = (sec % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    private func iconFor(_ id: String) -> String {
        switch id {
        case "standard": return "sun.max.fill"
        case "size996":  return "flame.fill"
        case "size995":  return "flame"
        case "swing":    return "moon.fill"
        case "night":    return "moon.stars.fill"
        case "partTime": return "clock.badge.checkmark"
        default:         return "briefcase.fill"
        }
    }
}
