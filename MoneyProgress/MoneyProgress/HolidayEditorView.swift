//
//  HolidayEditorView.swift
//  MoneyProgress
//
//  自定义节假日编辑面板（Feature 8）
//  可视化日历选择器，添加/删除自定义节假日
//

import SwiftUI
import AppKit

struct HolidayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var customHolidays: Set<String>
    let officialHolidays: Set<String>

    @State private var selectedDate: Date = Date()
    @State private var pickerMode: PickerMode = .date
    @State private var holidayMode: HolidayMode = .rest

    enum PickerMode: String, CaseIterable, Identifiable {
        case date = "single"
        case range = "range"
        var id: String { rawValue }
    }

    enum HolidayMode: String, CaseIterable, Identifiable {
        case rest = "rest"
        case work = "work"
        var id: String { rawValue }
    }

    private static let keyFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private static let displayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd EEE"
        f.locale = Locale.current
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(AppTheme.purple)
                    .font(.system(size: 20, weight: .bold))
                Text("ui.title.customHolidays".localized)
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
                .help("ui.close".localized)
            }

            Divider()

            // 选择模式
            Picker("模式", selection: $pickerMode) {
                Text("ui.single".localized).tag(PickerMode.date)
                Text("ui.dateRange".localized).tag(PickerMode.range)
            }
            .pickerStyle(.segmented)

            // 节假日类型
            Picker("类型", selection: $holidayMode) {
                Text("ui.restDay".localized).tag(HolidayMode.rest)
                Text("ui.workDay".localized).tag(HolidayMode.work)
            }
            .pickerStyle(.segmented)

            // 日期选择器
            HStack {
                if pickerMode == .date {
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                } else {
                    VStack(alignment: .leading) {
                        Text("ui.start".localized)
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                        Text("ui.rangeHint".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider()

            // 操作按钮
            HStack {
                Button {
                    addSelected()
                } label: {
                    Label("ui.add".localized, systemImage: "plus.circle.fill")
                        .font(.system(size: 13, design: .rounded).bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.purple)

                if !customHolidays.isEmpty {
                    Button(role: .destructive) {
                        customHolidays.removeAll()
                    } label: {
                        Label("ui.clearAll".localized, systemImage: "trash")
                            .font(.system(size: 12, design: .rounded))
                    }
                }
                Spacer()
                Text(String(format: "ui.totalCustom".localized, customHolidays.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 已添加列表
            VStack(alignment: .leading, spacing: 6) {
                Text("ui.added".localized)
                    .font(.system(size: 12, design: .rounded).bold())
                    .foregroundStyle(.secondary)

                if customHolidays.isEmpty {
                    Text("ui.emptyCustom".localized)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(customHolidays.sorted(), id: \.self) { key in
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(AppTheme.purple)
                                    Text(displayString(key))
                                        .font(.system(size: 12, design: .rounded))
                                    Spacer()
                                    Button {
                                        customHolidays.remove(key)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.cardSurface(scheme: colorScheme))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }

            // 帮助
            HStack {
                Image(systemName: "info.circle")
                Text("法定节假日已自动包含，可在 ContentView 关闭「节假日排除」以禁用".localized)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 460, height: 640)
        .background(WindowBackground(scheme: colorScheme))
    }

    private func displayString(_ key: String) -> String {
        guard let d = Self.keyFmt.date(from: key) else { return key }
        return Self.displayFmt.string(from: d)
    }

    private func addSelected() {
        let key = Self.keyFmt.string(from: selectedDate)
        customHolidays.insert(key)
    }
}
