//
//  SettingsView.swift
//  MoneyProgress
//
//  专属设置界面（独立 NSWindow，卡片风格 + 跟主界面一致）
//  - 8 个 tab：收入/工作时间/节假日/通知/外观/数据/快捷键/启动
//  - 自定义卡片布局（避免 SwiftUI Form 的 macOS/iOS 风格混乱）
//  - 自动保存（@AppStorage 实时绑定）
//  - 与 iCloud 同步集成
//  - 暗色模式自动适配（暖色渐变 + 鲜亮高饱和色板）
//

import SwiftUI
import AppKit

// MARK: - 主入口

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .income
    @Environment(\.colorScheme) private var colorScheme

    enum SettingsTab: String, CaseIterable, Identifiable {
        case income, worktime, holiday, notification, appearance, data, shortcut, startup
        var id: String { rawValue }

        var title: String {
            switch self {
            case .income: return "收入与目标"
            case .worktime: return "工作时间"
            case .holiday: return "节假日"
            case .notification: return "通知"
            case .appearance: return "外观"
            case .data: return "数据与同步"
            case .shortcut: return "快捷键"
            case .startup: return "启动"
            }
        }

        var icon: String {
            switch self {
            case .income: return "dollarsign.circle.fill"
            case .worktime: return "clock.fill"
            case .holiday: return "calendar.badge.checkmark"
            case .notification: return "bell.badge.fill"
            case .appearance: return "paintbrush.fill"
            case .data: return "icloud.fill"
            case .shortcut: return "keyboard.fill"
            case .startup: return "powerplug.fill"
            }
        }
    }

    var body: some View {
        ZStack {
            // 背景：跟主界面同款暖色 / 暗色渐变
            WindowBackground(scheme: colorScheme)
                .ignoresSafeArea()

            // 柔光斑
            GeometryReader { geo in
                Circle()
                    .fill(AppTheme.gold.opacity(colorScheme == .dark ? 0.15 : 0.12))
                    .frame(width: 320, height: 320)
                    .blur(radius: 80)
                    .offset(x: -120, y: -80)
                Circle()
                    .fill(AppTheme.purple.opacity(colorScheme == .dark ? 0.15 : 0.10))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: geo.size.width - 200, y: geo.size.height - 200)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部 Tab 栏（毛玻璃 + 鲜亮金色选中）
                tabBar
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        Rectangle()
                            .fill(colorScheme == .dark
                                  ? Color.white.opacity(0.05)
                                  : Color.white.opacity(0.45))
                    )

                Divider().opacity(0.3)

                // 内容区
                ScrollView {
                    Group {
                        switch selectedTab {
                        case .income: IncomeTab()
                        case .worktime: WorkTimeTab()
                        case .holiday: HolidayTab()
                        case .notification: NotificationTab()
                        case .appearance: AppearanceTab()
                        case .data: DataTab()
                        case .shortcut: ShortcutTab()
                        case .startup: StartupTab()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(minWidth: 660, idealWidth: 720, maxWidth: .infinity,
               minHeight: 480, idealHeight: 580, maxHeight: .infinity)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SettingsTab.allCases) { tab in
                    tabButton(tab)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func tabButton(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button(action: { selectedTab = tab }) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primaryText(scheme: colorScheme).opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected
                          ? AnyShapeStyle(AppTheme.goldGradient)
                          : AnyShapeStyle(Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        isSelected
                            ? Color.clear
                            : Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? AppTheme.gold.opacity(0.4) : .clear,
                radius: 4, y: 2
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 卡片 & 单行（自定义避免 Form 风格混乱）

/// 卡片（带标题 + 卡片内容）
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String?
    let tint: Color?
    let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    init(title: String, icon: String? = nil, tint: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon, let tint = tint {
                    CardIcon(systemName: icon, tint: tint)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                Spacer()
            }
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.06)
                          : Color.white.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.white.opacity(0.9),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.3)
                    : Color.black.opacity(0.05),
                radius: 6, y: 2
            )
        }
    }
}

/// 卡片内单行（带分隔线）
struct SettingsRow<Content: View>: View {
    let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            Divider()
                .opacity(colorScheme == .dark ? 0.15 : 0.4)
                .padding(.leading, 14)
        }
    }
}

// MARK: - 标签 / 值样式（统一字号 + 字体 + 颜色）

/// 设置项左侧的标签
struct SettingsLabel: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color.primaryText(scheme: colorScheme))
    }
}

/// 设置项右侧的次要文本（"已就绪"、"CNY" 等）
struct SettingsHint: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(Color.secondaryText(scheme: colorScheme))
    }
}

/// 卡片标题左侧的小图标
struct CardIcon: View {
    let systemName: String
    let tint: Color
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
    }
}

// MARK: - Tab 1: 收入与目标

struct IncomeTab: View {
    @AppStorage("wiki.qaq.currencyUnit") private var currencyUnit: String = "CNY"
    @AppStorage("wiki.qaq.monthPaid") private var monthPaid: Double = 30000
    @AppStorage("wiki.qaq.dayWorkOfMonth") private var dayWorkOfMonth: Int = 22
    @AppStorage("wiki.qaq.monthlyGoal") private var monthlyGoal: Double = 0
    @AppStorage("wiki.qaq.dailyGoalOverride") private var dailyGoalOverride: Double = 0
    @AppStorage("wiki.qaq.streakGoal") private var streakGoal: Int = 0
    @AppStorage("wiki.qaq.overtime.enabled") private var overtimeEnabled: Bool = false
    @AppStorage("wiki.qaq.overtime.rate") private var overtimeRate: Double = 1.5
    @AppStorage("wiki.qaq.overtime.threshold") private var overtimeThreshold: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "基础收入", icon: "dollarsign.circle.fill", tint: AppTheme.gold) {
                SettingsRow {
                    SettingsLabel("货币单位")
                    Spacer()
                    Picker("", selection: $currencyUnit) {
                        ForEach(["CNY", "USD", "EUR", "GBP", "JPY", "HKD", "KRW", "SGD", "AUD", "CAD"], id: \.self) { code in
                            Text("\(currencySymbol(code)) \(code)").tag(code)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                SettingsRow {
                    SettingsLabel("月薪")
                    Spacer()
                    TextField("", value: $monthPaid, format: .number)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                    SettingsHint(currencyUnit)
                        .frame(width: 30, alignment: .leading)
                }
                SettingsRow {
                    SettingsLabel("每月工作天数")
                    Spacer()
                    Stepper(value: $dayWorkOfMonth, in: 1...31) {
                        Text("\(dayWorkOfMonth) 天")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .labelsHidden()
                }
            }

            SettingsCard(title: "目标", icon: "trophy.fill", tint: AppTheme.gold) {
                SettingsRow {
                    SettingsLabel("每日目标")
                    Spacer()
                    TextField("", value: $dailyGoalOverride, format: .number)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                    SettingsHint(currencyUnit)
                        .frame(width: 30, alignment: .leading)
                }
                SettingsRow {
                    SettingsLabel("每月目标")
                    Spacer()
                    TextField("", value: $monthlyGoal, format: .number)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                    SettingsHint(currencyUnit)
                        .frame(width: 30, alignment: .leading)
                }
                SettingsRow {
                    SettingsLabel("连续达标目标")
                    Spacer()
                    Stepper(value: $streakGoal, in: 0...365) {
                        Text("\(streakGoal) 天")
                            .frame(width: 60, alignment: .trailing)
                    }
                    .labelsHidden()
                }
            }

            SettingsCard(title: "加班", icon: "bolt.fill", tint: AppTheme.purple) {
                SettingsRow {
                    SettingsLabel("启用加班费")
                    Spacer()
                    Toggle("", isOn: $overtimeEnabled)
                        .labelsHidden()
                }
                if overtimeEnabled {
                    SettingsRow {
                        SettingsLabel("加班起始时间")
                        Spacer()
                        Stepper(value: $overtimeThreshold, in: 0...240, step: 30) {
                            Text(formatMinutes(overtimeThreshold * 60))
                                .frame(width: 70, alignment: .trailing)
                        }
                        .labelsHidden()
                    }
                    SettingsRow {
                        SettingsLabel("加班费率")
                        Spacer()
                        Stepper(value: $overtimeRate, in: 1.0...3.0, step: 0.1) {
                            Text(String(format: "%.1fx", overtimeRate))
                                .frame(width: 60, alignment: .trailing)
                        }
                        .labelsHidden()
                    }
                }
            }
        }
    }

    private func currencySymbol(_ code: String) -> String {
        let map = ["CNY": "¥", "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "HKD": "HK$", "KRW": "₩", "SGD": "S$", "AUD": "A$", "CAD": "C$"]
        return map[code] ?? ""
    }

    private func formatMinutes(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

// MARK: - Tab 2: 工作时间

struct WorkTimeTab: View {
    @AppStorage("wiki.qaq.workStart") private var workStart: Int = 9 * 3600
    @AppStorage("wiki.qaq.workEnd") private var workEnd: Int = 18 * 3600
    @AppStorage("wiki.qaq.noonBreak") private var noonBreak: Bool = false
    @AppStorage("wiki.qaq.breakStart") private var breakStart: Int = 12 * 3600
    @AppStorage("wiki.qaq.breakEnd") private var breakEnd: Int = 14 * 3600
    @AppStorage("wiki.qaq.weekendsWork") private var weekendsWork: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "快速模板", icon: "rectangle.stack.fill", tint: AppTheme.cyan) {
                SettingsRow {
                    SettingsLabel("班次模板")
                    Spacer()
                    Button("选择…") {
                        NotificationCenter.default.post(name: .openShiftTemplatePicker, object: nil)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            SettingsCard(title: "自定义时间", icon: "clock.fill", tint: AppTheme.cyan) {
                SettingsRow {
                    SettingsLabel("上班时间")
                    Spacer()
                    DatePicker("", selection: timeBinding(for: $workStart), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                SettingsRow {
                    SettingsLabel("下班时间")
                    Spacer()
                    DatePicker("", selection: timeBinding(for: $workEnd), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
            }

            SettingsCard(title: "午休", icon: "cup.and.saucer.fill", tint: AppTheme.coral) {
                SettingsRow {
                    SettingsLabel("启用午休")
                    Spacer()
                    Toggle("", isOn: $noonBreak)
                        .labelsHidden()
                }
                if noonBreak {
                    SettingsRow {
                        SettingsLabel("午休开始")
                        Spacer()
                        DatePicker("", selection: timeBinding(for: $breakStart), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    SettingsRow {
                        SettingsLabel("午休结束")
                        Spacer()
                        DatePicker("", selection: timeBinding(for: $breakEnd), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }

            SettingsCard(title: "周末", icon: "calendar", tint: AppTheme.mint) {
                SettingsRow {
                    SettingsLabel("周末也工作")
                    Spacer()
                    Toggle("", isOn: $weekendsWork)
                        .labelsHidden()
                }
            }
        }
    }

    private func timeBinding(for seconds: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let s = seconds.wrappedValue
                return Calendar.current.date(bySettingHour: s / 3600, minute: (s % 3600) / 60, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                seconds.wrappedValue = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60
            }
        )
    }
}

extension Notification.Name {
    static let openShiftTemplatePicker = Notification.Name("openShiftTemplatePicker")
}

// MARK: - Tab 3: 节假日

struct HolidayTab: View {
    @AppStorage("wiki.qaq.holiday.enabled") private var holidayEnabled: Bool = true
    @AppStorage("wiki.qaq.holiday.customHolidays") private var customHolidays: String = "[]"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "节假日识别", icon: "calendar.badge.checkmark", tint: AppTheme.purple) {
                SettingsRow {
                    SettingsLabel("启用法定节假日")
                    Spacer()
                    Toggle("", isOn: $holidayEnabled)
                        .labelsHidden()
                }
            }

            SettingsCard(title: "自定义", icon: "square.and.pencil", tint: AppTheme.coral) {
                SettingsRow {
                    SettingsLabel("管理自定义节假日")
                    Spacer()
                    Button("编辑…") {
                        NotificationCenter.default.post(name: .openHolidayEditor, object: nil)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

extension Notification.Name {
    static let openHolidayEditor = Notification.Name("openHolidayEditor")
}

// MARK: - Tab 4: 通知

struct NotificationTab: View {
    @AppStorage("wiki.qaq.notifications.enabled") private var notificationsEnabled: Bool = true
    @AppStorage("wiki.qaq.notif.workStart") private var workStartNotif: Bool = true
    @AppStorage("wiki.qaq.notif.workEnd") private var workEndNotif: Bool = true
    @AppStorage("wiki.qaq.notif.goalReached") private var goalReachedNotif: Bool = true
    @AppStorage("wiki.qaq.notif.dndStart") private var dndStart: Int = 22 * 3600
    @AppStorage("wiki.qaq.notif.dndEnd") private var dndEnd: Int = 8 * 3600
    @AppStorage("wiki.qaq.notif.dndEnabled") private var dndEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "总开关", icon: "bell.badge.fill", tint: AppTheme.pink) {
                SettingsRow {
                    SettingsLabel("启用通知")
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                }
                if !notificationsEnabled {
                    SettingsRow {
                        SettingsLabel("系统权限")
                        Spacer()
                        Button("申请权限") {
                            NotificationManager.shared.requestAuthorization { _ in }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            SettingsCard(title: "事件通知", icon: "bell.fill", tint: AppTheme.cyan) {
                SettingsRow {
                    SettingsLabel("上班提醒")
                    Spacer()
                    Toggle("", isOn: $workStartNotif)
                        .labelsHidden()
                        .disabled(!notificationsEnabled)
                }
                SettingsRow {
                    SettingsLabel("下班结算")
                    Spacer()
                    Toggle("", isOn: $workEndNotif)
                        .labelsHidden()
                        .disabled(!notificationsEnabled)
                }
                SettingsRow {
                    SettingsLabel("目标达成")
                    Spacer()
                    Toggle("", isOn: $goalReachedNotif)
                        .labelsHidden()
                        .disabled(!notificationsEnabled)
                }
            }

            SettingsCard(title: "免打扰", icon: "moon.fill", tint: AppTheme.purple) {
                SettingsRow {
                    SettingsLabel("启用免打扰")
                    Spacer()
                    Toggle("", isOn: $dndEnabled)
                        .labelsHidden()
                        .disabled(!notificationsEnabled)
                }
                if dndEnabled {
                    SettingsRow {
                        SettingsLabel("开始时间")
                        Spacer()
                        DatePicker("", selection: timeBinding(for: $dndStart), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    SettingsRow {
                        SettingsLabel("结束时间")
                        Spacer()
                        DatePicker("", selection: timeBinding(for: $dndEnd), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    private func timeBinding(for seconds: Binding<Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let s = seconds.wrappedValue
                return Calendar.current.date(bySettingHour: s / 3600, minute: (s % 3600) / 60, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                seconds.wrappedValue = (comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60
            }
        )
    }
}

// MARK: - Tab 5: 外观

struct AppearanceTab: View {
    @AppStorage("wiki.qaq.theme") private var theme: String = "auto"
    @AppStorage("wiki.qaq.accentColor") private var accentColor: String = "gold"
    @AppStorage("wiki.qaq.menubarFormat") private var menubarFormat: String = "amount"
    @AppStorage("wiki.qaq.compactMode") private var compactMode: Bool = false
    @AppStorage("wiki.qaq.fontSize") private var fontSize: String = "standard"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "主题", icon: "paintbrush.fill", tint: AppTheme.purple) {
                SettingsRow {
                    SettingsLabel("外观")
                    Spacer()
                    Picker("", selection: $theme) {
                        Text("跟随系统").tag("auto")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                SettingsRow {
                    SettingsLabel("主色")
                    Spacer()
                    Picker("", selection: $accentColor) {
                        Text("金色").tag("gold")
                        Text("粉紫").tag("pink")
                        Text("薄荷").tag("mint")
                        Text("天蓝").tag("blue")
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
            }

            SettingsCard(title: "菜单栏", icon: "menubar.rectangle", tint: AppTheme.cyan) {
                SettingsRow {
                    SettingsLabel("显示格式")
                    Spacer()
                    Picker("", selection: $menubarFormat) {
                        Text("金额").tag("amount")
                        Text("百分比").tag("percent")
                        Text("金额+百分比").tag("both")
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
                SettingsRow {
                    SettingsLabel("紧凑模式")
                    Spacer()
                    Toggle("", isOn: $compactMode)
                        .labelsHidden()
                }
            }

            SettingsCard(title: "字体", icon: "textformat.size", tint: AppTheme.mint) {
                SettingsRow {
                    SettingsLabel("字号")
                    Spacer()
                    Picker("", selection: $fontSize) {
                        Text("小").tag("small")
                        Text("标准").tag("standard")
                        Text("大").tag("large")
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }
            }
        }
    }
}

// MARK: - Tab 6: 数据与同步

struct DataTab: View {
    @AppStorage("wiki.qaq.history.v1") private var historyJSON: String = "[]"
    @ObservedObject private var sync = iCloudSyncManager.shared
    @State private var showResetConfirm: Bool = false
    @State private var lastSyncInfo: String = "—"
    @Environment(\.colorScheme) private var colorScheme

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "iCloud 同步", icon: "icloud.fill", tint: .blue) {
                SettingsRow {
                    HStack(spacing: 6) {
                        Image(systemName: sync.isAvailable ? "icloud.fill" : "icloud.slash")
                            .foregroundStyle(sync.isAvailable ? .blue : Color.secondaryText(scheme: colorScheme))
                        SettingsLabel("iCloud 状态")
                    }
                    Spacer()
                    Text(sync.isAvailable ? "已连接" : "不可用")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(sync.isAvailable ? AppTheme.mint : Color.secondaryText(scheme: colorScheme))
                }
                SettingsRow {
                    SettingsLabel("云端同步键数")
                    Spacer()
                    SettingsHint(sync.isAvailable ? "已就绪" : "—")
                }
                SettingsRow {
                    SettingsLabel("立即同步")
                    Spacer()
                    Button("推送") { sync.forcePush() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("拉取") { sync.forcePull() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            SettingsCard(title: "数据", icon: "externaldrive.fill", tint: AppTheme.mint) {
                SettingsRow {
                    SettingsLabel("历史记录数")
                    Spacer()
                    SettingsHint("\(historyCount()) 条")
                }
                SettingsRow {
                    SettingsLabel("数据大小")
                    Spacer()
                    SettingsHint(dataSizeString())
                }
                SettingsRow {
                    SettingsLabel("导出历史")
                    Spacer()
                    Button("导出…") {
                        HistoryExporter.exportCSV()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            SettingsCard(title: "危险操作", icon: "exclamationmark.triangle.fill", tint: AppTheme.pink) {
                SettingsRow {
                    SettingsLabel("重置所有设置")
                    Spacer()
                    Button("重置") { showResetConfirm = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("确认重置？", isPresented: $showResetConfirm) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) { resetAll() }
        } message: {
            Text("所有设置将恢复默认值，此操作不可撤销。")
        }
    }

    private func historyCount() -> Int {
        guard let data = historyJSON.data(using: .utf8),
              let arr = try? JSONDecoder().decode([HistoryRecord].self, from: data) else { return 0 }
        return arr.count
    }

    private func dataSizeString() -> String {
        let total = historyJSON.utf8.count
        if total < 1024 { return "\(total) B" }
        if total < 1024 * 1024 { return String(format: "%.1f KB", Double(total) / 1024) }
        return String(format: "%.2f MB", Double(total) / 1024 / 1024)
    }

    private func resetAll() {
        AppLog.info("已重置所有设置")
        // 删除所有 wiki.qaq.* 键
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("wiki.qaq.") {
            if key != "wiki.qaq.window.frame" {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - Tab 7: 快捷键

struct ShortcutTab: View {
    @AppStorage("wiki.qaq.shortcut.enabled") private var enabled: Bool = true
    @AppStorage("wiki.qaq.shortcut.togglePanel") private var togglePanel: String = "⌥⌘M"
    @AppStorage("wiki.qaq.shortcut.toggleRun") private var toggleRun: String = "⌥⌘R"
    @AppStorage("wiki.qaq.shortcut.openSettings") private var openSettingsShortcut: String = "⌘,"
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "全局快捷键", icon: "globe", tint: AppTheme.cyan) {
                SettingsRow {
                    SettingsLabel("启用全局快捷键")
                    Spacer()
                    Toggle("", isOn: $enabled)
                        .labelsHidden()
                }
            }

            SettingsCard(title: "快捷键", icon: "keyboard.fill", tint: AppTheme.purple) {
                SettingsRow {
                    SettingsLabel("切换主窗口")
                    Spacer()
                    Text(togglePanel)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                }
                SettingsRow {
                    SettingsLabel("开始/停止计时")
                    Spacer()
                    Text(toggleRun)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                }
                SettingsRow {
                    SettingsLabel("打开设置")
                    Spacer()
                    Text(openSettingsShortcut)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                }
            }
        }
    }
}

// MARK: - Tab 8: 启动

struct StartupTab: View {
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @AppStorage("wiki.qaq.launch.minimized") private var launchMinimized: Bool = false
    @AppStorage("wiki.qaq.launch.menubarOnly") private var menubarOnly: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "开机自启动", icon: "powerplug.fill", tint: AppTheme.gold) {
                SettingsRow {
                    SettingsLabel("开机时启动")
                    Spacer()
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { newVal in
                            LaunchAtLogin.setEnabled(newVal)
                        }
                }
            }

            SettingsCard(title: "启动行为", icon: "arrow.up.right.circle.fill", tint: AppTheme.cyan) {
                SettingsRow {
                    SettingsLabel("最小化启动")
                    Spacer()
                    Toggle("", isOn: $launchMinimized)
                        .labelsHidden()
                }
                SettingsRow {
                    SettingsLabel("仅菜单栏模式")
                    Spacer()
                    Toggle("", isOn: $menubarOnly)
                        .labelsHidden()
                }
            }

            SettingsCard(title: "关于", icon: "info.circle.fill", tint: AppTheme.purple) {
                SettingsRow {
                    SettingsLabel("版本")
                    Spacer()
                    SettingsHint(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
                SettingsRow {
                    SettingsLabel("构建号")
                    Spacer()
                    SettingsHint(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                }
            }
        }
    }
}

// 历史记录（用于数据统计）
struct HistoryRecord: Codable {
    let dateKey: String
    let earned: Double
}
