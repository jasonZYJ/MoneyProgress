//
//  PiggyBankAnimation.swift
//  MoneyProgress
//
//  圆环内的"金币落入存钱罐"循环动画
//  - 存钱罐位于圆环底部（不挡数字）
//  - 每 1.6 秒从顶部落下一枚金币
//  - 暗色 / 浅色 自动适配
//

import SwiftUI

/// 存钱罐 + 落币动画（嵌入大圆环底部）
struct PiggyBankAnimation: View {
    /// 动画播放速度（秒 / 循环）
    var interval: Double = 1.6
    /// 落币数量（每循环几枚）
    var coinCount: Int = 1
    /// 调色板
    var tint: Color = AppTheme.gold
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase: Double = 0  // 0..1 循环
    @State private var startTime: Date = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            let elapsed = context.date.timeIntervalSince(startTime)
            let total = interval * Double(coinCount)
            let raw = (elapsed.truncatingRemainder(dividingBy: total)) / interval
            Canvas { ctx, size in
                drawPiggyBank(in: ctx, size: size)
                // 多枚金币依次落下
                for i in 0..<coinCount {
                    let phase = raw - Double(i) * (1.0 / Double(coinCount))
                    if phase >= 0 && phase < 1.0 {
                        drawCoin(in: ctx, size: size, progress: phase, index: i)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 绘制存钱罐

    private func drawPiggyBank(in ctx: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let baseY = h * 0.92  // 罐底
        let centerX = w * 0.5

        // 罐身（圆角矩形）
        let bodyW = w * 0.50
        let bodyH = h * 0.42
        let bodyRect = CGRect(
            x: centerX - bodyW / 2,
            y: baseY - bodyH,
            width: bodyW,
            height: bodyH
        )
        let bodyPath = Path(roundedRect: bodyRect, cornerRadius: bodyH * 0.35)
        // 罐身渐变
        let bodyGradient = Gradient(colors: [
            tint.opacity(colorScheme == .dark ? 0.85 : 0.95),
            tint.opacity(colorScheme == .dark ? 0.55 : 0.70)
        ])
        ctx.fill(bodyPath, with: .linearGradient(
            bodyGradient,
            startPoint: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
            endPoint: CGPoint(x: bodyRect.midX, y: bodyRect.maxY)
        ))
        // 罐身边框
        ctx.stroke(bodyPath, with: .color(tint.opacity(0.9)), lineWidth: 1.2)

        // 罐口（顶部槽）
        let slotW = bodyW * 0.42
        let slotH = h * 0.045
        let slotRect = CGRect(
            x: centerX - slotW / 2,
            y: bodyRect.minY - slotH * 0.4,
            width: slotW,
            height: slotH
        )
        let slotPath = Path(roundedRect: slotRect, cornerRadius: slotH * 0.4)
        ctx.fill(slotPath, with: .color(
            colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.5)
        ))
        ctx.stroke(slotPath, with: .color(tint.opacity(0.7)), lineWidth: 0.8)

        // 耳朵（左）
        let earSize = h * 0.10
        let leftEar = Path { p in
            p.move(to: CGPoint(x: bodyRect.minX + bodyW * 0.15, y: bodyRect.minY + bodyH * 0.10))
            p.addLine(to: CGPoint(x: bodyRect.minX + bodyW * 0.10, y: bodyRect.minY - earSize * 0.2))
            p.addLine(to: CGPoint(x: bodyRect.minX + bodyW * 0.25, y: bodyRect.minY + bodyH * 0.15))
            p.closeSubpath()
        }
        ctx.fill(leftEar, with: .color(tint.opacity(0.85)))
        // 耳朵（右）
        let rightEar = Path { p in
            p.move(to: CGPoint(x: bodyRect.maxX - bodyW * 0.15, y: bodyRect.minY + bodyH * 0.10))
            p.addLine(to: CGPoint(x: bodyRect.maxX - bodyW * 0.10, y: bodyRect.minY - earSize * 0.2))
            p.addLine(to: CGPoint(x: bodyRect.maxX - bodyW * 0.25, y: bodyRect.minY + bodyH * 0.15))
            p.closeSubpath()
        }
        ctx.fill(rightEar, with: .color(tint.opacity(0.85)))

        // 鼻孔（两个小点）
        let noseR = h * 0.022
        let noseY = bodyRect.maxY - bodyH * 0.30
        ctx.fill(
            Path(ellipseIn: CGRect(x: centerX - bodyW * 0.18 - noseR, y: noseY - noseR, width: noseR * 2, height: noseR * 2)),
            with: .color(tint.opacity(0.55))
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: centerX + bodyW * 0.18 - noseR, y: noseY - noseR, width: noseR * 2, height: noseR * 2)),
            with: .color(tint.opacity(0.55))
        )

        // 四条小短腿
        let legW = bodyW * 0.10
        let legH = h * 0.06
        let legY = bodyRect.maxY - legH * 0.4
        for xOffset in [bodyW * 0.18, bodyW * 0.82] {
            let legRect = CGRect(
                x: bodyRect.minX + xOffset - legW / 2,
                y: legY,
                width: legW,
                height: legH
            )
            ctx.fill(
                Path(roundedRect: legRect, cornerRadius: legW * 0.3),
                with: .color(tint.opacity(0.80))
            )
        }

        // 闪光高光（罐身左上）
        let highlightRect = CGRect(
            x: bodyRect.minX + bodyW * 0.15,
            y: bodyRect.minY + bodyH * 0.15,
            width: bodyW * 0.18,
            height: bodyH * 0.10
        )
        ctx.fill(
            Path(roundedRect: highlightRect, cornerRadius: highlightRect.height * 0.4),
            with: .color(.white.opacity(colorScheme == .dark ? 0.25 : 0.50))
        )
    }

    // MARK: - 绘制金币

    private func drawCoin(in ctx: GraphicsContext, size: CGSize, progress: Double, index: Int) {
        let w = size.width
        let h = size.height
        let centerX = w * 0.5
        let baseY = h * 0.92  // 罐底（同上）
        let coinR = h * 0.085

        // 起点：圆环顶部
        let startY = h * 0.08
        // 终点：罐口
        let endY = baseY - h * 0.42 + h * 0.005  // bodyRect.minY 附近

        // 加速度：先快后慢（重力）
        let p = progress
        let easedP = p * p  // 二次方 — 模拟重力加速
        let y = startY + (endY - startY) * CGFloat(easedP)

        // 横向轻微摆动（不规则感）
        let swing = sin(p * .pi * 3 + Double(index)) * (w * 0.06)
        let x = centerX + CGFloat(swing)

        // 入罐前最后 20% 渐隐（视觉"落入"）
        let fadeOut = progress > 0.80 ? (1.0 - (progress - 0.80) / 0.20) : 1.0
        let scale: CGFloat = progress > 0.75 ? CGFloat(1.0 - (progress - 0.75) * 2.0) : 1.0

        // 金币渐变
        let coinRect = CGRect(x: x - coinR * scale, y: y - coinR * scale, width: coinR * 2 * scale, height: coinR * 2 * scale)
        let coinGradient = Gradient(colors: [
            Color(red: 1.0, green: 0.95, blue: 0.55),
            Color(red: 1.0, green: 0.80, blue: 0.30)
        ])
        ctx.fill(
            Path(ellipseIn: coinRect),
            with: .linearGradient(
                coinGradient,
                startPoint: CGPoint(x: coinRect.minX, y: coinRect.minY),
                endPoint: CGPoint(x: coinRect.maxX, y: coinRect.maxY)
            )
        )
        // 描边
        ctx.stroke(
            Path(ellipseIn: coinRect),
            with: .color(Color.orange.opacity(0.6)),
            lineWidth: 0.6
        )
        // 中心高光（小圆点）
        let hi = CGRect(
            x: coinRect.midX - coinR * 0.35 * scale,
            y: coinRect.midY - coinR * 0.45 * scale,
            width: coinR * 0.7 * scale,
            height: coinR * 0.55 * scale
        )
        ctx.fill(
            Path(ellipseIn: hi),
            with: .color(.white.opacity(0.55 * fadeOut))
        )

        // 阴影（罐底）
        if progress < 0.8 {
            let shadowY = endY + h * 0.04
            let shadowRect = CGRect(x: x - coinR * 0.6, y: shadowY, width: coinR * 1.2, height: coinR * 0.25)
            ctx.fill(
                Path(ellipseIn: shadowRect),
                with: .color(.black.opacity(0.18 * (1.0 - progress)))
            )
        }
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.black
        PiggyBankAnimation(interval: 1.6, coinCount: 2, tint: .yellow)
            .frame(width: 180, height: 180)
    }
    .frame(width: 300, height: 300)
}
#endif
