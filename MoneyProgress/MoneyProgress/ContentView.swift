//
//  ContentView.swift
//  MoneyProgress
//
//  Created by Lakr Aream on 2022/3/14.
//
//  UI 重构：暗色模式适配 + 窗口铺满 + 暖色渐变 + 卡片化
//

import AppKit
import Colorful
import SwiftUI

enum AlertType {
    case moneyCountInvalid
    case workDayInvalid
    case timeInvalid
}

struct ContentView: View {
    // 单一数据源
    @AppStorage("wiki.qaq.workSchedule.v2") private var rawSchedule: String = ""
    @AppStorage("wiki.qaq.currencyUnit") private var currencyStorage: String = "CNY"
    @AppStorage("wiki.qaq.compactMode") var compactMode: Bool = false
    @AppStorage("wiki.qaq.notifications.enabled") var notificationsEnabled: Bool = true
    @AppStorage("wiki.qaq.holiday.enabled") var holidayEnabled: Bool = true
    @AppStorage("wiki.qaq.overtime.enabled") var overtimeEnabled: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    @State private var schedule: WorkSchedule = .default
    @State private var currencyUnit: String = "CNY"
    @State private var workStartDate: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var workEndDate: Date = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var breakStartDate: Date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var breakEndDate: Date = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var isHaveNoonBreak: Bool = false
    @State private var sliderWidth: CGFloat = 0
    @State private var refreshTrigger = UUID()
    @State private var now: Date = Date()
    @State private var tickTimer: Timer?

    @StateObject var menubar = Menubar.shared

    @State private var isMoneyInvalid = false
    @State private var isWorkDayInvalid = false
    @State private var isShowAlert = false
    @State private var alertType: AlertType = .moneyCountInvalid

    @State private var openCoinTypePicker = false
    @State private var showHistorySheet = false
    @State private var showHolidayEditor = false
    @State private var showTemplatePicker = false
    @State private var animateProgress: Double = 0
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    /// TextField 防抖任务（避免每次按键都持久化）
    @State private var persistTask: Task<Void, Never>?

    /// Confetti 触发器（改 true 触发一次，view 内自动 reset）
    @State private var confettiTrigger: Bool = false
    /// 100% 已达 — Confetti 仅触发一次，直到收入再次低于 100%
    @State private var hasShownConfetti: Bool = false
    @State private var showGoalSheet: Bool = false
    @State private var showMonthlyReport: Bool = false
    @State private var showAboutSheet: Bool = false
    @State private var showSettingsSheet: Bool = false

    /// 打开设置窗口（通过 AppDelegate，最稳定）
    private func openSettings() {
        print("🟢 [openSettings] 进入")
        if let appDelegate = NSApp.delegate as? AppDelegate {
            print("🟢 找到 appDelegate，调 openSettingsWindow")
            appDelegate.openSettingsWindow()
        } else {
            print("❌ 找不到 appDelegate！")
        }
    }

    /// 把 live.percent 暴露给外层 .onChange（避免 onChange 闭包内部直接调 liveResult）
    @State private var livePercentKey: Double = 0

    // MARK: - 状态同步

    // MARK: - 工具方法

    /// 获取应用版本号（用于"关于"弹窗）
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - 持久化

    private func persistSchedule() {
        guard let data = try? JSONEncoder().encode(schedule),
              let str = String(data: data, encoding: .utf8) else { return }
        rawSchedule = str
        Menubar.shared.reload()
        refreshTrigger = UUID()
    }

    /// 防抖持久化（用于 TextField 每次按键触发）
    private func debouncedPersist() {
        persistTask?.cancel()
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(InputDebounceMs) * 1_000_000)
            guard !Task.isCancelled else { return }
            persistSchedule()
        }
    }

    /// 应用班次模板（Feature 11）
    private func applyTemplate(_ template: ShiftTemplate) {
        var s = schedule
        s.workStartSeconds = template.workStart
        s.workEndSeconds = template.workEnd
        s.breaks = template.breaks
        s.dayWorkOfMonth = template.daysPerMonth
        s.overtimeThresholdSeconds = template.overtimeThreshold
        s.overtimeRate = template.overtimeRate
        schedule = s
        persistSchedule()
        // 同步 Date 选择器
        workStartDate = today(secondsInDay: template.workStart)
        workEndDate = today(secondsInDay: template.workEnd)
        isHaveNoonBreak = !template.breaks.isEmpty
        if let b = template.breaks.first {
            breakStartDate = today(secondsInDay: b.startSeconds)
            breakEndDate = today(secondsInDay: b.endSeconds)
        }
        overtimeEnabled = template.overtimeThreshold > 0 || template.overtimeRate > OvertimeMinRate
    }

    // MARK: - Body

    /// 启动每秒刷新的 Timer（修复 #xx：TimelineView 在 macOS 15 偶发不刷新）
    private func startTickTimer() {
        tickTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let newNow = Date()
            // 跨秒才更新（节省渲染）
            if Int(newNow.timeIntervalSince1970) != Int(now.timeIntervalSince1970) {
                now = newNow
                let r = computeEarnings(at: newNow)
                handlePercentChange(r.percent)
            }
        }
        // 加入 RunLoop common 模式，保证窗口拖动时也触发
        RunLoop.current.add(timer, forMode: .common)
        tickTimer = timer
    }

    /// 100% 触发 Confetti（含去重）
    private func handlePercentChange(_ newPct: Double) {
        if newPct >= 1.0 {
            if !hasShownConfetti {
                hasShownConfetti = true
                confettiTrigger = true
                PerfSignpost.event("Earnings.reached100")
            }
        } else if newPct < 0.9 {
            // 收入下降后允许下次达成再次触发
            hasShownConfetti = false
        }
    }

    var body: some View {
        ZStack {
            // 暖色/暗色渐变背景
            WindowBackground(scheme: colorScheme).ignoresSafeArea()

            // 100% 达成时的五彩纸屑（背景层）
            ConfettiView(trigger: $confettiTrigger, particleCount: 60)
                .ignoresSafeArea()

            // 柔光斑
            GeometryReader { geo in
                Circle()
                    .fill(AppTheme.gold.opacity(colorScheme == .dark ? 0.15 : 0.18))
                    .frame(width: 400, height: 400)
                    .blur(radius: 100)
                    .offset(x: -150, y: -100)
                Circle()
                    .fill(AppTheme.pink.opacity(colorScheme == .dark ? 0.18 : 0.15))
                    .frame(width: 360, height: 360)
                    .blur(radius: 110)
                    .offset(x: geo.size.width - 250, y: geo.size.height - 350)
                Circle()
                    .fill(AppTheme.mint.opacity(colorScheme == .dark ? 0.10 : 0.12))
                    .frame(width: 300, height: 300)
                    .blur(radius: 90)
                    .offset(x: geo.size.width * 0.5, y: geo.size.height - 200)
            }
            .ignoresSafeArea()

            // 主内容（铺满窗口，顶部对齐）
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 12) {
                        topBar
                        heroSection
                        progressCard
                        configSection
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadSchedule()
            withAnimation(.easeOut(duration: 0.8)) {
                animateProgress = 1
            }
            // 启动每秒刷新的 Timer
            startTickTimer()
        }
        .onDisappear {
            tickTimer?.invalidate()
            tickTimer = nil
        }
        .onChange(of: schedule) { _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateProgress = 1
            }
            refreshTrigger = UUID()
        }
        .sheet(isPresented: $showHistorySheet) {
            HistoryView()
                .frame(width: 720, height: 480)
        }
        .sheet(isPresented: $showHolidayEditor) {
            HolidayEditorView(
                customHolidays: Binding(
                    get: { schedule.customHolidays },
                    set: { newVal in
                        var s = schedule
                        s.customHolidays = newVal
                        schedule = s
                        persistSchedule()
                    }
                ),
                officialHolidays: HolidayCalendar.chineseOfficial
            )
        }
        .sheet(isPresented: $showTemplatePicker) {
            ShiftTemplatePicker { template in
                applyTemplate(template)
            }
        }
        .sheet(isPresented: $showGoalSheet) {
            GoalSettingView(
                schedule: $schedule,
                currencyUnit: currencyUnit,
                onChange: persistSchedule
            )
        }
        .sheet(isPresented: $showMonthlyReport) {
            MonthlyReportView(menubar: menubar)
                .frame(width: 600, height: 540)
        }
        .sheet(isPresented: $openCoinTypePicker) {
            CoinTypePicker {
                currencyUnit
            } onComplete: { setUnit in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    currencyUnit = setUnit
                    currencyStorage = setUnit
                }
            }
        }
        .sheet(isPresented: $showAboutSheet) {
            AboutSheet(appVersion: getAppVersion())
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
                .frame(minWidth: 620, minHeight: 520)
        }
        .alert(isPresented: $isShowAlert) {
            switch alertType {
            case .moneyCountInvalid:
                return Alert(
                    title: Text("This is it?".localized),
                    message: Text("💰 Make negative money, what work do you work? Please check if your salary is negative.".localized)
                )
            case .workDayInvalid:
                return Alert(
                    title: Text("This is it?".localized),
                    message: Text("💰 How many days do you work in a month? Please check if your working days are reasonable.".localized)
                )
            case .timeInvalid:
                return Alert(
                    title: Text("invalid_time_range_tip".localized),
                    message: Text("time_range_tip".localized)
                )
            }
        }
    }

    // MARK: - 顶部状态栏（单行紧凑布局）

    private var topBar: some View {
        HStack(spacing: 8) {
            // 品牌 Logo + 应用名
            HStack(spacing: 7) {
                BrandLogo(
                    size: 32,
                    showRing: menubar.menubarRunning,
                    progress: menubar.menubarRunning ? menubar.todayPercent : 0
                )
                VStack(alignment: .leading, spacing: 0) {
                    Text("薪辛".localized)
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(Color.primaryText(scheme: colorScheme))
                    Text("Earnest")
                        .font(.system(size: 9, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                }
            }
            .padding(.leading, 4)
            .help("关于 薪辛".localized)
            .onTapGesture { showAboutSheet = true }

            // 状态指示
            HStack(spacing: 6) {
                Circle()
                    .fill(menubar.menubarRunning ? AppTheme.mint : Color.gray.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .shadow(color: (menubar.menubarRunning ? AppTheme.mint : .clear).opacity(0.7), radius: 4)
                Text(menubar.menubarRunning ? "运行中" : "未启动")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(menubar.menubarRunning ? AppTheme.mintDeep : Color.secondaryText(scheme: colorScheme))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(menubar.menubarRunning ? AppTheme.mint.opacity(0.15) : Color.cardSurface(scheme: colorScheme)))
            .overlay(Capsule().stroke(
                menubar.menubarRunning ? AppTheme.mint.opacity(0.4) : Color.cardStroke(scheme: colorScheme),
                lineWidth: 1
            ))

            Spacer()

            // 工具栏（紧凑一行）
            HStack(spacing: 6) {
                toolbarButton(icon: "rectangle.stack", help: "班次模板".localized, tint: AppTheme.cyan) {
                    Self.log("模板"); showTemplatePicker = true
                }
                toolbarButton(icon: "trophy.fill", help: "目标".localized, tint: AppTheme.gold) {
                    Self.log("目标"); showGoalSheet = true
                }
                toolbarButton(icon: "calendar.badge.checkmark", help: "月度报告".localized, tint: AppTheme.mintDeep) {
                    Self.log("月报"); showMonthlyReport = true
                }
                toolbarButton(icon: "chart.line.uptrend.xyaxis", help: "📊 历史统计".localized, tint: AppTheme.purple) {
                    Self.log("历史"); showHistorySheet = true
                }
                toolbarButton(
                    icon: menubar.menubarRunning ? "pause.circle.fill" : "play.circle.fill",
                    help: menubar.menubarRunning ? "Remove from status bar!".localized : "Hang on the status bar to start pricing!".localized,
                    tint: menubar.menubarRunning ? AppTheme.pink : AppTheme.mint
                ) {
                    Self.log("播放")
                    if !checkInputIfValid() { return }
                    if menubar.menubarRunning { menubar.stop() } else { menubar.run() }
                }
                toolbarButton(icon: "arrow.counterclockwise", help: "Restore Default (9 to 6 CNY)".localized, tint: AppTheme.coral) {
                    Self.log("重置")
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        schedule = .default
                        currencyUnit = "CNY"
                        currencyStorage = "CNY"
                        compactMode = false
                        isHaveNoonBreak = false
                        overtimeEnabled = false
                        holidayEnabled = true
                        notificationsEnabled = true
                    }
                    fillInitialData()
                }
                // 设置按钮：用标准 toolbarButton（Button + 圆环样式）
                // 触发走 NotificationCenter — 避免 NSApp.delegate 转换失败导致设置窗口不弹出
                toolbarButton(icon: "gearshape.fill", help: "设置 (⌘,)".localized, tint: AppTheme.cyan) {
                    Self.log("设置-点击")
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
            }
        }
    }

    /// 调试日志（写文件 + 打印）
    static func log(_ tag: String) {
        print("🔧 \(tag)")
        let path = "/tmp/earnest_btn.log"
        let msg = "[\(Date())] \(tag)\n"
        if let d = msg.data(using: .utf8) {
            if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                h.seekToEndOfFile(); h.write(d); try? h.close()
            } else {
                try? d.write(to: URL(fileURLWithPath: path))
            }
        }
    }

    @ViewBuilder
    private func toolbarButton(icon: String, help: String, tint: Color = .secondary, size: CGFloat = 30, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(tint.opacity(colorScheme == .dark ? 0.20 : 0.15))
                )
                .overlay(
                    Circle()
                        .stroke(tint.opacity(colorScheme == .dark ? 0.5 : 0.4), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.3), radius: 4, y: 1)
        }
        .buttonStyle(PressableButtonStyle())
        .help(help)
    }

    // MARK: - 英雄区（大数字展示 + 鲜亮金色圆环）

    private var heroSection: some View {
        let live = liveResult
        let isPaused = !menubar.menubarRunning
        let percent = isPaused ? 0 : live.percent
        let earned = isPaused ? 0 : live.earned
        let target = live.dailyEarnings
        let isHoliday = (holidayEnabled && !isPaused && HolidayCalendar(customHolidays: schedule.customHolidays).isRestDay(Date()))

        // 固定圆环尺寸（不用 GeometryReader — 避免 ScrollView 内 HStack 错乱）
        let ringSize: CGFloat = 180
        let outerGlow = ringSize + 26

        return HStack(alignment: .center, spacing: 22) {
            // 圆形进度环（鲜亮金黄色 + 强烈发光）
            ZStack {
                // 外圈柔光（大）
                Circle()
                    .fill((isHoliday ? AppTheme.purple : AppTheme.gold).opacity(0.20))
                    .frame(width: outerGlow, height: outerGlow)
                    .blur(radius: 22)

                // 背景圆
                Circle()
                    .stroke((isHoliday ? AppTheme.purple : AppTheme.gold).opacity(0.20), lineWidth: 14)
                    .frame(width: ringSize, height: ringSize)

                // 进度圆
                Circle()
                    .trim(from: 0, to: min(1, percent) * animateProgress)
                    .stroke(
                        isHoliday ? AppTheme.holidayGradient : AppTheme.goldGradient,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: (isHoliday ? AppTheme.purple : AppTheme.gold).opacity(0.9), radius: 16)
                    .animation(.linear(duration: 1.0), value: percent)

                // 圆环内部：数字 / 状态
                VStack(spacing: 2) {
                    if isPaused {
                        Text("⏸")
                            .font(.system(size: 36))
                        Text("ui.paused".localized)
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                    } else if isHoliday {
                        Text("🎉")
                            .font(.system(size: 36))
                        Text("ui.holiday".localized)
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(AppTheme.purple)
                    } else if percent <= 0 {
                        Text("💤")
                        Text("ui.notStarted".localized)
                            .font(.system(.caption, design: .rounded).bold())
                            .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                    } else {
                        Text(String(format: "%.2f", earned))
                            .font(.system(size: DesignTokens.fontHero, weight: .heavy, design: .rounded))
                            .foregroundStyle(isHoliday ? AppTheme.holidayGradient : AppTheme.goldGradient)
                            .shadow(color: (isHoliday ? AppTheme.purple : AppTheme.gold).opacity(0.6), radius: 8)
                            .contentTransition(.numericText())
                        Text(AppTheme.currencyLabel(currencyUnit))
                            .font(.system(size: 11, design: .rounded).bold())
                            .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                    }
                }

                // 底部存钱罐 + 落币循环动画（仅在计时进行中时显示）
                if !isPaused && percent > 0 {
                    PiggyBankAnimation(
                        interval: 1.8,
                        coinCount: 1,
                        tint: isHoliday ? AppTheme.purple : AppTheme.gold
                    )
                    .frame(width: ringSize * 0.85, height: ringSize * 0.55)
                    .offset(y: ringSize * 0.22)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: ringSize, height: ringSize)

            // 右侧：4 指标
            VStack(alignment: .leading, spacing: 7) {
                metricChip(title: "metric.target".localized,
                           value: "\(NumberFormatter.compact(target)) \(AppTheme.currencyLabel(currencyUnit))",
                           color: AppTheme.gold, icon: "target")
                metricChip(title: "metric.hourly".localized,
                           value: "\(NumberFormatter.smartCurrency(live.coinPerSecond * 3600)) \(AppTheme.currencyLabel(currencyUnit))",
                           color: AppTheme.mintDeep, icon: "clock.fill")
                metricChip(title: "metric.perMinute".localized,
                           value: "\(NumberFormatter.smartCurrency(live.coinPerSecond * 60)) \(AppTheme.currencyLabel(currencyUnit))",
                           color: AppTheme.mint, icon: "stopwatch.fill")
                metricChip(title: "metric.perSecond".localized,
                           value: "\(NumberFormatter.smartCurrency(live.coinPerSecond)) \(AppTheme.currencyLabel(currencyUnit))",
                           color: AppTheme.cyan, icon: "bolt.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardSurface(scheme: colorScheme))
                .shadow(color: AppTheme.gold.opacity(colorScheme == .dark ? 0.15 : 0.20), radius: 12, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.gold.opacity(colorScheme == .dark ? 0.30 : 0.25), lineWidth: 1)
        )
    }

    private func metricChip(title: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color.opacity(colorScheme == .dark ? 0.25 : 0.18))
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(colorScheme == .dark ? 0.5 : 0.4), lineWidth: 0.5)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, design: .rounded).bold())
                    .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                Text(value)
                    .font(.system(.callout, design: .rounded).bold())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(color.opacity(colorScheme == .dark ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(color.opacity(colorScheme == .dark ? 0.35 : 0.25), lineWidth: 1)
        )
    }

    /// P0 #5 状态徽章：加班/跨午夜/节假日 小标签
    private func badgeChip(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.18)))
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.5))
    }

    /// 货币代码本地化显示（保留向后兼容 — 推荐用 AppTheme.currencyLabel）
    private func currencyDisplay(_ code: String) -> String {
        AppTheme.currencyLabel(code)
    }

    // MARK: - 进度条卡片

    private var progressCard: some View {
        VStack(spacing: 8) {
            HStack {
                Label("工作时间", systemImage: "clock.fill")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(AppTheme.mintDeep)
                Spacer()
                if schedule.crossesMidnight {
                    Label("跨午夜", systemImage: "moon.stars.fill")
                        .font(.system(size: 10, design: .rounded).bold())
                        .foregroundColor(AppTheme.purple)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(AppTheme.purple.opacity(0.18)))
                }
            }

            // 进度条 + 整点标签（精确按 24 等分位置放置）
            VStack(spacing: 4) {
                GeometryReader { r in
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.cardSurface(scheme: colorScheme))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cardStroke(scheme: colorScheme), lineWidth: 1))
                            .frame(height: 40)

                        // 24 个整点刻度线（精确按 h/24 * width 位置）
                        ForEach(0...24, id: \.self) { h in
                            let isMajor = h % 6 == 0
                            Rectangle()
                                .fill((isMajor
                                       ? Color.primary.opacity(colorScheme == .dark ? 0.55 : 0.40)
                                       : Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.15)))
                                .frame(width: isMajor ? 1.5 : 1, height: isMajor ? 20 : 12)
                                .offset(x: r.size.width * CGFloat(h) / 24.0, y: isMajor ? 10 : 14)
                        }

                        // 工作区间高亮（24h 背景条 + 当前时间指示）
                        workRangeOverlay
                            .frame(height: 24)
                            .offset(y: 8)

                        // 当前时间指示器
                        nowIndicator
                            .frame(height: 40)
                    }
                    .onAppear { sliderWidth = r.size.width }
                    .onChange(of: r.size) { newValue in
                        if sliderWidth != newValue.width { sliderWidth = newValue.width }
                    }
                }
                .frame(height: 40)

                // 整点标签（全部 24 整点，主次区分）
                GeometryReader { r in
                    ZStack(alignment: .topLeading) {
                        ForEach(0..<24, id: \.self) { h in
                            let isMajor = h % 6 == 0
                            let isWork = h >= (schedule.workStartSeconds / 3600) && h <= (schedule.workEndSeconds / 3600)
                            Text(h < 10 ? "0\(h)" : "\(h)")
                                .font(.system(size: isMajor ? 9 : 7, design: .rounded).bold())
                                .foregroundStyle(isMajor
                                                 ? (isWork ? AppTheme.mintDeep : AppTheme.goldDeep)
                                                 : Color.secondaryText(scheme: colorScheme).opacity(0.65))
                                .frame(width: 18, alignment: .center)
                                .offset(x: r.size.width * CGFloat(h) / 24.0 - 9)
                        }
                    }
                }
                .frame(height: 14)
            }

            // 起止时间标记
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "alarm.fill")
                        .foregroundStyle(AppTheme.mintDeep)
                        .font(.system(size: 11))
                    Text(String(format: "%02d:%02d", schedule.workStartSeconds / 3600, (schedule.workStartSeconds % 3600) / 60))
                        .font(.system(.callout, design: .rounded).bold())
                        .foregroundStyle(AppTheme.mintDeep)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text(String(format: "%02d:%02d", schedule.workEndSeconds / 3600, (schedule.workEndSeconds % 3600) / 60))
                        .font(.system(.callout, design: .rounded).bold())
                        .foregroundStyle(AppTheme.goldDeep)
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(AppTheme.goldDeep)
                        .font(.system(size: 11))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.cardSurface(scheme: colorScheme))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.04), radius: 6, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.cardStroke(scheme: colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var workRangeOverlay: some View {
        // 精确按 h/24 位置（与整点刻度线同一坐标系）
        let beginSec = schedule.workStartSeconds
        let endSec = schedule.workEndSeconds == 0 ? 86400 : schedule.workEndSeconds
        let beginFrac = Double(beginSec) / 86400.0
        let endFrac = Double(endSec) / 86400.0
        let workX = sliderWidth * beginFrac
        let workW = max(8, sliderWidth * (endFrac - beginFrac))

        if !schedule.crossesMidnight {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.progressGradient.opacity(0.55))
                .frame(width: workW, height: 24)
                .offset(x: workX, y: 8)
        } else {
            // 跨午夜：左半（0→endFrac） + 右半（beginFrac→1）
            let rightW = max(8, sliderWidth * (1.0 - beginFrac))
            let leftW = max(8, sliderWidth * endFrac)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.progressGradient.opacity(0.75))
                    .frame(width: rightW, height: 24)
                    .offset(x: workX, y: 8)
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.progressGradient.opacity(0.75))
                    .frame(width: leftW, height: 24)
                    .offset(x: 0, y: 8)
            }
            .frame(width: sliderWidth, height: 24)
        }
    }

    @ViewBuilder
    private var nowIndicator: some View {
        let cal = Calendar.current
        let nowH = Double(cal.component(.hour, from: Date()))
        let nowM = Double(cal.component(.minute, from: Date()))
        let nowFrac = (nowH + nowM / 60.0) / 24.0
        let x = sliderWidth * nowFrac
        ZStack(alignment: .top) {
            // P1 #11 圆点 + 加粗
            Circle()
                .fill(AppTheme.coral)
                .frame(width: 8, height: 8)
                .offset(x: x - 4, y: 0)
                .shadow(color: AppTheme.coral.opacity(0.9), radius: 4)
            Rectangle()
                .fill(AppTheme.coral)
                .frame(width: 2.5, height: 32)
                .offset(x: x - 1.25, y: 5)
                .shadow(color: AppTheme.coral.opacity(0.7), radius: 4)
        }
    }

    // MARK: - 配置区（响应式网格）

    private var configSection: some View {
        VStack(spacing: 10) {
            salaryCard
            HStack(spacing: 10) {
                timeCard
                otCard
            }
            featuresCard
        }
    }

    private var salaryCard: some View {
        card {
            VStack(spacing: 10) {
                // 月薪
                HStack(spacing: 14) {
                    Button {
                        openCoinTypePicker = true
                    } label: {
                        Text(currencyDisplay(currencyUnit))
                            .font(.system(.callout, design: .rounded).bold())
                            .foregroundStyle(AppTheme.goldGradient)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(AppTheme.gold.opacity(0.18)))
                            .overlay(Capsule().stroke(AppTheme.gold.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        Text("月薪".localized)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                        TextField("20000", text: Binding<String>(
                            get: { String(schedule.monthPaidCents / 100) },
                            set: { str in
                                let v = Int(str) ?? 0
                                if v < 0 { isMoneyInvalid = true; return }
                                isMoneyInvalid = false
                                var s = schedule
                                s.monthPaidCents = v * 100
                                schedule = s
                                debouncedPersist()
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(Color.primaryText(scheme: colorScheme))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Rectangle()
                    .fill(Color.cardStroke(scheme: colorScheme))
                    .frame(height: 1)

                // 工作几天
                HStack(spacing: 6) {
                    Text("一个月工作几天".localized)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                    TextField("20", text: Binding<String>(
                        get: { String(schedule.dayWorkOfMonth) },
                        set: { str in
                            let v = Int(str) ?? 0
                            if v <= 0 || v >= 32 { isWorkDayInvalid = true; return }
                            isWorkDayInvalid = false
                            var s = schedule
                            s.dayWorkOfMonth = v
                            schedule = s
                            debouncedPersist()
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(Color.primaryText(scheme: colorScheme))
                    .frame(maxWidth: 60, alignment: .leading)
                    Text("days".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                    Spacer()
                }
            }
        }
    }

    private var timeCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Label("工作时间", systemImage: "clock.fill")
                    .font(.system(size: 10, design: .rounded).bold())
                    .foregroundStyle(AppTheme.mintDeep)

                // P2 #18 紧凑 Stepper（替代 DatePicker）
                HStack(spacing: 6) {
                    timeStepper(label: "上班", date: $workStartDate, tint: AppTheme.mintDeep)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                    timeStepper(label: "下班", date: $workEndDate, tint: AppTheme.goldDeep)
                }
            }
        }
    }

    /// P2 #18 紧凑时间步进器（HH:MM ↑↓ 5min）
    private func timeStepper(label: String, date: Binding<Date>, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
            Text(String(format: "%02d:%02d",
                       Calendar.current.component(.hour, from: date.wrappedValue),
                       Calendar.current.component(.minute, from: date.wrappedValue)))
                .font(.system(.callout, design: .rounded).bold())
                .foregroundStyle(tint)
            Stepper("", value: date, in: Date(timeIntervalSince1970: 0)...Date(timeIntervalSince1970: 86400), step: 300)
                .labelsHidden()
                .controlSize(.mini)
                .onChange(of: date.wrappedValue) { newValue in
                    let hms = hmsFromDate(newValue)
                    if label == "上班" {
                        var s = schedule; s.workStartSeconds = hms; schedule = s
                    } else {
                        var s = schedule; s.workEndSeconds = hms; schedule = s
                    }
                    persistSchedule()
                }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.3), lineWidth: 0.5))
    }

    private var otCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle(isOn: $overtimeEnabled) {
                        Label("加班", systemImage: "briefcase.fill")
                            .font(.system(size: 10, design: .rounded).bold())
                            .foregroundStyle(AppTheme.pink)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(AppTheme.pink)
                    .onChange(of: overtimeEnabled) { newValue in
                        var s = schedule
                        s.overtimeThresholdSeconds = newValue ? 8 * 3600 : 0
                        s.overtimeRate = newValue ? 1.5 : 1.0
                        schedule = s
                        persistSchedule()
                    }
                }
                if overtimeEnabled {
                    HStack(spacing: 4) {
                        Text("阈值")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                        TextField("8", text: Binding<String>(
                            get: { String(schedule.overtimeThresholdSeconds / 3600) },
                            set: { str in
                                let v = max(0, Int(str) ?? 0)
                                var s = schedule
                                s.overtimeThresholdSeconds = v * 3600
                                schedule = s
                                persistSchedule()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 40)
                        .font(.system(.caption, design: .rounded))
                        Text("h ×")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                        TextField("1.5", text: Binding<String>(
                            get: { String(schedule.overtimeRate) },
                            set: { str in
                                let v = Double(str) ?? 1.0
                                var s = schedule
                                s.overtimeRate = max(1.0, v)
                                schedule = s
                                persistSchedule()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .font(.system(.caption, design: .rounded))
                    }
                } else {
                    Text("开启后，超出阈值按倍率计费")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Color.secondaryText(scheme: colorScheme))
                        .lineLimit(2)
                }
            }
        }
    }

    private var featuresCard: some View {
        card {
            VStack(spacing: 6) {
                // P0 #3 第一行：4 toggle
                HStack(spacing: 8) {
                    featureToggle(icon: "bell.fill", label: "feature.notify".localized, color: AppTheme.gold, isOn: $notificationsEnabled)
                    featureToggle(icon: "sparkles", label: "feature.holiday".localized, color: AppTheme.purple, isOn: $holidayEnabled)
                    featureToggle(icon: "rectangle.compress.vertical", label: "feature.compact".localized, color: AppTheme.mint, isOn: $compactMode)
                    featureToggle(icon: "power", label: "feature.launchAtLogin".localized, color: AppTheme.cyan, isOn: Binding(
                        get: { launchAtLogin },
                        set: { newVal in
                            if LaunchAtLogin.setEnabled(newVal) {
                                launchAtLogin = newVal
                            }
                        }
                    ))
                }
                // P0 #3 第二行：节假日表 + 导出 + 状态
                HStack(spacing: 8) {
                    Button {
                        showHolidayEditor = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("feature.holidayList".localized)
                                .font(.system(size: 11, design: .rounded).bold())
                            Text("\(schedule.customHolidays.count)")
                                .font(.system(size: 9, design: .rounded).bold())
                                .padding(.horizontal, 4)
                                .background(Capsule().fill(AppTheme.purple.opacity(0.3)))
                        }
                        .foregroundStyle(AppTheme.purple)
                    }
                    .buttonStyle(.plain)
                    Button {
                        HistoryExporter.shared.exportToDesktop(menubar: menubar)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                            Text("feature.export".localized)
                                .font(.system(size: 11, design: .rounded).bold())
                        }
                        .foregroundStyle(AppTheme.mintDeep)
                    }
                    .buttonStyle(.plain)
                    .help("feature.exportHelp".localized)
                    Spacer()
                    // P2 #16 开机启动状态文字
                    if launchAtLogin {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 8))
                            Text("已启用")
                                .font(.system(size: 9, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.cyan)
                    }
                }
            }
        }
    }

    private func featureToggle(icon: String, label: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 11, design: .rounded).bold())
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isOn.wrappedValue
                          ? color.opacity(colorScheme == .dark ? 0.25 : 0.20)
                          : color.opacity(colorScheme == .dark ? 0.08 : 0.06))
            )
            .overlay(
                Capsule()
                    .stroke(isOn.wrappedValue
                            ? color.opacity(0.6)
                            : color.opacity(colorScheme == .dark ? 0.25 : 0.20),
                            lineWidth: 1)
            )
            .foregroundStyle(isOn.wrappedValue ? color : Color.secondaryText(scheme: colorScheme))
        }
        .buttonStyle(.plain)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardSurface(scheme: colorScheme))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.05), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cardStroke(scheme: colorScheme), lineWidth: 1)
            )
    }

    // MARK: - 计算属性

    private var liveResult: EarningResult {
        computeEarnings(at: Date())
    }

    /// 用 Performance Monitoring 包裹的核心计算路径
    private func computeEarnings(at date: Date) -> EarningResult {
        PerfSignpost.measure("EarningsCalculator.compute") {
            EarningsCalculator.compute(
                schedule: schedule,
                now: date,
                holidays: holidayEnabled ? HolidayCalendar(customHolidays: schedule.customHolidays) : nil
            )
        }
    }

    /// 当前是否在 100%（用于触发 Confetti）
    private var isFullyEarned: Bool {
        let r = liveResult
        return !r.notStartedYet && r.completed && !r.earned.isNaN
    }

    var coinPerSecond: Double {
        let totalWork = schedule.totalWorkSecondsToday
        guard totalWork > 0 else { return 0 }
        return schedule.dailyEarnings / Double(totalWork)
    }

    // MARK: - 校验

    func checkInputIfValid() -> Bool {
        var inputValid = true
        if isMoneyInvalid {
            inputValid = false
            alertType = .moneyCountInvalid
        }
        if isWorkDayInvalid {
            inputValid = false
            alertType = .workDayInvalid
        }
        if !timeIsValid() {
            inputValid = false
            alertType = .timeInvalid
        }
        isShowAlert = !inputValid
        return inputValid
    }

    func timeIsValid() -> Bool {
        if schedule.workStartSeconds == schedule.workEndSeconds { return false }
        if !isHaveNoonBreak { return true }
        guard let b = schedule.breaks.first else { return true }
        return b.startSeconds < b.endSeconds
    }

    // MARK: - 进度条几何

    var offsetForBegin: CGFloat {
        let percent = Double(schedule.workStartSeconds) / 86400.0
        return sliderWidth * (percent - 0.5)
    }

    var offsetForEnd: CGFloat {
        let endSec = schedule.workEndSeconds == 0 ? 86400 : schedule.workEndSeconds
        let percent = Double(endSec) / 86400.0
        return sliderWidth * (percent - 0.5)
    }

    // MARK: - 持久化

    private func loadSchedule() {
        if let data = rawSchedule.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(WorkSchedule.self, from: data) {
            schedule = decoded
        } else {
            schedule = WorkSchedule.migrateFromLegacy()
            persistSchedule()
        }
        currencyUnit = currencyStorage
        isHaveNoonBreak = !schedule.breaks.isEmpty
        overtimeEnabled = schedule.overtimeThresholdSeconds > 0
        workStartDate = today(secondsInDay: schedule.workStartSeconds)
        workEndDate = today(secondsInDay: schedule.workEndSeconds)
        if let b = schedule.breaks.first {
            breakStartDate = today(secondsInDay: b.startSeconds)
            breakEndDate = today(secondsInDay: b.endSeconds)
        }
    }

    // MARK: - 工具

    func fillInitialData() {
        schedule = .default
        persistSchedule()
        isHaveNoonBreak = false
        workStartDate = today(secondsInDay: 9 * 3600)
        workEndDate = today(secondsInDay: 18 * 3600)
        breakStartDate = today(secondsInDay: 12 * 3600)
        breakEndDate = today(secondsInDay: 14 * 3600)
    }

    private func hmsFromDate(_ date: Date) -> Int {
        let cal = Calendar.current
        return cal.component(.hour, from: date) * 3600
            + cal.component(.minute, from: date) * 60
    }

    private func today(secondsInDay: Int) -> Date {
        let cal = Calendar.current
        let h = secondsInDay / 3600
        let m = (secondsInDay % 3600) / 60
        return cal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }
}
