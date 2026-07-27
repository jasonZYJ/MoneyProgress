//
//  MoneyProgressApp.swift
//  MoneyProgress
//
//  Created by Lakr Aream on 2022/3/14.
//
//  重构：增加 NSApplicationDelegate 适配、启动时请求通知权限
//

import AppKit
import SwiftUI
import ServiceManagement

@main
struct MoneyProgressApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _ = currencyModels  // 预热
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(
                    minWidth: 720, idealWidth: 800, maxWidth: .infinity,
                    minHeight: 480, idealHeight: 560, maxHeight: .infinity
                )
                .onAppear { _ = Menubar.shared }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            // ⌘N 禁用
            CommandGroup(replacing: .newItem) { }
            // ⌘, 设置 — 用标准 SwiftUI CommandGroup 走 NotificationCenter
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

// 全局 ⌘, 由 SwiftUI CommandGroup(replacing: .appSettings) 处理 — 不再需要 NSEvent 监听

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// 主窗口引用（用于"关闭窗口"时隐藏而非退出）
    var mainWindow: NSWindow?
    /// 设置窗口（独立 NSWindow，避免 SwiftUI 多 sheet 冲突）
    private var settingsWindow: NSWindow?

    private let windowFrameKey = "wiki.qaq.window.frame"

    /// 打开设置窗口（独立 NSWindow，最稳定）
    @objc func openSettingsWindow() {
        // 写文件验证
        let logLine = "[\(Date())] openSettingsWindow 被调用\n"
        let path = "/tmp/earnest_settings.log"
        if let data = logLine.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                handle.seekToEndOfFile(); handle.write(data); try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path))
            }
        }

        // 先把 app 切回 .regular 模式
        NSApp.setActivationPolicy(.regular)

        AppLog.info("打开设置窗口")
        if let existing = settingsWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // 用 contentRect 初始化器 + 手动 contentView，确保 SwiftUI 视图撑满窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "薪辛 · 设置"
        window.minSize = NSSize(width: 660, height: 480)
        window.identifier = NSUserInterfaceItemIdentifier("SettingsWindow")

        // 创建 NSHostingController 后让它的 view 撑满 contentView
        let hosting = NSHostingController(rootView: SettingsView())
        window.contentViewController = hosting
        hosting.view.translatesAutoresizingMaskIntoConstraints = true
        hosting.view.autoresizingMask = [.width, .height]
        hosting.view.frame = window.contentView!.bounds
        // 显式设置 contentSize（设置 contentViewController 后 NSWindow 可能丢失尺寸）
        window.setContentSize(NSSize(width: 720, height: 580))

        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = false
        // 不强制 .aqua — 跟随系统外观，深色模式才能生效
        // window.appearance = NSAppearance(named: .aqua)
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 预热 Menubar
        _ = Menubar.shared

        // 通知权限引导：首次启动时请求注：dock 图标由系统从 bundle 的 Assets.xcassets/AppIcon.appiconset 自动管理
        // 不要再调 AppIconLoader.applyAppIcon() 覆盖 applicationIconImage
        // 否则会强制使用单张 1024x1024 图，导致 dock 显示尺寸异常放大

        // 启动 iCloud 同步（异步执行，不阻塞启动）
        DispatchQueue.main.async {
            iCloudSyncManager.shared.start()
        }

        // 通知权限引导：首次启动时请求
        if !UserDefaults.standard.bool(forKey: "wiki.qaq.notif.didPrompt") {
            UserDefaults.standard.set(true, forKey: "wiki.qaq.notif.didPrompt")
            NotificationManager.shared.requestAuthorization { _ in
                // 无论用户同意与否，UI 仍可用
            }
        }

        // 关联主窗口
        mainWindow = NSApp.windows.first { $0.styleMask.contains(.titled) }
        if let win = mainWindow {
            win.delegate = self  // 接管 close
            // 恢复窗口位置（带屏幕可见性校验）
            if let frameStr = UserDefaults.standard.string(forKey: windowFrameKey) {
                let saved = NSRectFromString(frameStr)
                if isFrameVisible(saved) {
                    win.setFrame(saved, display: true)
                } else {
                    win.center()
                }
            } else {
                win.center()
            }
            // 监听移动/缩放以保存位置
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowDidChange),
                name: NSWindow.didMoveNotification, object: win
            )
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowDidChange),
                name: NSWindow.didResizeNotification, object: win
            )
        }

        // 事件驱动更新激活策略（替代 1 秒轮询 Timer）
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateActivationPolicy),
            name: NSWindow.didBecomeKeyNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateActivationPolicy),
            name: NSWindow.willCloseNotification, object: nil
        )

        // 监听"打开设置"通知 — 绕过 NSApp.delegate 转换失败
        NotificationCenter.default.addObserver(
            self, selector: #selector(openSettingsWindow),
            name: .openSettings, object: nil
        )
    }

    @objc private func windowDidChange(_ note: Notification) {
        guard let win = note.object as? NSWindow else { return }
        // 保存窗口 frame 为字符串（NSStringFromRect 编码）
        let frameStr = NSStringFromRect(win.frame)
        UserDefaults.standard.set(frameStr, forKey: windowFrameKey)
        UserDefaults.standard.set(true, forKey: "wiki.qaq.window.hasSaved")
    }

    /// 事件驱动的激活策略更新（主窗口隐藏 / 关闭 / 全部不可见时切到 .accessory）
    @objc private func updateActivationPolicy() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 是否有任一可见的"用户"窗口（主窗口或设置窗口）
            let hasVisible = NSApp.windows.contains { win in
                guard win.isVisible else { return false }
                // 跳过状态栏窗口
                if let cls = NSClassFromString("NSStatusBarWindow"), win.isKind(of: cls) {
                    return false
                }
                // 必须是 titled 窗口（排除 toolbar 等内部窗口）
                return win.styleMask.contains(.titled)
            }
            if hasVisible {
                NSApp.setActivationPolicy(.regular)
            } else if Menubar.shared.menubarRunning {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    /// 校验 frame 是否至少与某块屏幕相交（避免保存到屏幕外）
    private func isFrameVisible(_ frame: NSRect) -> Bool {
        guard frame.width > 100, frame.height > 100 else { return false }
        for screen in NSScreen.screens {
            let intersection = screen.visibleFrame.intersection(frame)
            if intersection.width > 200, intersection.height > 200 {
                return true
            }
        }
        return false
    }

    /// 关闭最后一个窗口时，不退出 App（菜单栏 app 行为）
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// 拦截窗口关闭：隐藏而非销毁
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == mainWindow {
            sender.orderOut(nil)  // 仅隐藏，App 仍在菜单栏运行
            // 关闭主窗口后立即检查激活策略
            updateActivationPolicy()
            return false
        }
        return true
    }

    /// 窗口关闭后清理引用
    func windowWillClose(_ notification: Notification) {
        if let win = notification.object as? NSWindow, win === settingsWindow {
            settingsWindow = nil
        }
        updateActivationPolicy()
    }

    /// ⌘Q 完全退出时清理
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        AppLog.info("Application terminating")
    }
}

// MARK: - 开机自启动 (Feature 5)

enum LaunchAtLogin {
    /// 是否已启用开机自启动
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 设置开机自启动
    /// - Returns: 成功与否
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            UserDefaults.standard.set(enabled, forKey: "wiki.qaq.launchAtLogin")
            return true
        } catch {
            AppLog.error("LaunchAtLogin failed: \(error.localizedDescription)")
            return false
        }
    }
}
