//
//  StatusBarIconAnimator.swift
//  MoneyProgress
//
//  状态栏图标动画：金币落入存钱罐（Timer 逐帧渲染）
//  - macOS NSStatusItem 不支持 SwiftUI 动画，只能逐帧替换 NSImage
//  - 12fps，每 ~2s 循环一轮金币下落
//

import AppKit
import SwiftUI

final class StatusBarIconAnimator {
    private var timer: Timer?
    private var phase: Double = 0           // 0..1 动画阶段
    private let cycleDuration: Double = 2.0  // 每轮动画时长（秒）
    private let fps: Double = 12.0           // 帧率
    private let iconSize: CGFloat = 36       // 渲染尺寸（@2x → 18pt 显示）
    private let coinSize: CGFloat = 8        // 金币直径（渲染尺寸）

    weak var button: NSStatusBarButton?

    /// 启动动画
    @MainActor
    func start(with button: NSStatusBarButton) {
        stop()
        self.button = button
        phase = 0
        let interval = 1.0 / fps
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.tick()
            }
        }
        RunLoop.current.add(timer!, forMode: .common)
        // 立即渲染第一帧
        updateIcon()
    }

    /// 停止动画（恢复静态图标）
    @MainActor
    func stop() {
        timer?.invalidate()
        timer = nil
        // 恢复静态图标
        if let button = button {
            applyStaticIcon(to: button)
        }
    }

    // MARK: - 帧更新

    @MainActor
    private func tick() {
        phase += (1.0 / fps) / cycleDuration
        if phase > 1.0 { phase -= 1.0 }
        updateIcon()
    }

    @MainActor
    private func updateIcon() {
        guard let button = button else { return }
        guard let cgImage = renderAnimatedFrame() else {
            applyStaticIcon(to: button)
            return
        }
        let img = NSImage(cgImage: cgImage, size: NSSize(width: 18, height: 18))
        img.isTemplate = false
        button.image = img
    }

    @MainActor
    private func applyStaticIcon(to button: NSStatusBarButton) {
        if let cgImage = renderStaticLogo() {
            let img = NSImage(cgImage: cgImage, size: NSSize(width: 18, height: 18))
            img.isTemplate = false
            button.image = img
        }
    }

    // MARK: - 渲染

    /// 渲染静态 logo（无动画）
    @MainActor
    private func renderStaticLogo() -> CGImage? {
        let logo = BrandLogo(size: iconSize, showRing: false, progress: 0)
            .frame(width: iconSize, height: iconSize)
        let renderer = ImageRenderer(content: logo)
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(width: iconSize, height: iconSize)
        return renderer.cgImage
    }

    /// 渲染动画帧：logo + 下落金币
    @MainActor
    private func renderAnimatedFrame() -> CGImage? {
        let view = ZStack {
            // 底层：logo
            BrandLogo(size: iconSize, showRing: false, progress: 0)
                .frame(width: iconSize, height: iconSize)

            // 上层：金币动画（仅在下落阶段显示）
            if phase >= 0.05 && phase <= 0.65 {
                coinView
            }
        }
        .frame(width: iconSize, height: iconSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        renderer.proposedSize = ProposedViewSize(width: iconSize, height: iconSize)
        return renderer.cgImage
    }

    /// 金币视图（根据 phase 计算位置和透明度）
    @ViewBuilder
    private var coinView: some View {
        let p = (phase - 0.05) / 0.60  // 0→1 下落阶段

        // 金币下落：二次方缓动（重力加速）
        let eased = p * p
        let yOffset = CGFloat(eased) * (iconSize * 0.55)

        // 金币大小：开始时 1.0x，入罐时缩小到 0.3x
        let scale: CGFloat = {
            if p < 0.75 {
                return 1.0
            } else {
                return 1.0 - CGFloat((p - 0.75) / 0.25) * 0.7
            }
        }()

        // 透明度：入罐阶段渐隐
        let opacity: CGFloat = {
            if p < 0.75 { return 1.0 }
            return 1.0 - CGFloat((p - 0.75) / 0.25) * 0.8
        }()

        // 横向轻微摆动
        let swing = sin(p * .pi * 2.5) * 2.0

        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.95, blue: 0.5), Color(red: 1.0, green: 0.75, blue: 0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.orange.opacity(0.5), lineWidth: 0.4)
            )
            .overlay(
                // 高光
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: coinSize * 0.4 * scale, height: coinSize * 0.35 * scale)
                    .offset(x: -coinSize * 0.12 * scale, y: -coinSize * 0.15 * scale)
            )
            .frame(width: coinSize * scale, height: coinSize * scale)
            .offset(x: CGFloat(swing), y: yOffset)
            .opacity(opacity)
    }
}