//
//  ConfettiView.swift
//  MoneyProgress
//
//  五彩纸屑效果（Feature 38）
//  达到 100% 完成今日工作后触发
//

import SwiftUI

struct ConfettiView: View {
    @Binding var trigger: Bool  // 改 true 时触发
    let particleCount: Int

    @State private var pieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                ConfettiShape(piece: p)
                    .frame(width: p.size, height: p.size * 0.4)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { newValue in
            if newValue {
                spawn()
                trigger = false
            }
        }
    }

    private func spawn() {
        PerfSignpost.event("Confetti.spawn")
        pieces = (0..<particleCount).map { _ in ConfettiPiece.random() }
        // 自动清理
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            pieces = []
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat       // 0-1 (相对宽度)
    let drift: CGFloat   // 水平漂移
    let size: CGFloat
    let color: Color
    let rotation: Double
    let delay: Double    // 0-1 (相对开始时间)
    let duration: Double // 0.5-1.5s

    static func random() -> ConfettiPiece {
        let palette: [Color] = [
            AppTheme.gold, AppTheme.pink, AppTheme.mint, AppTheme.purple,
            AppTheme.cyan, .orange, .yellow, AppTheme.coral,
        ]
        return ConfettiPiece(
            x: .random(in: 0...1),
            drift: .random(in: -120...120),
            size: .random(in: 6...14),
            color: palette.randomElement()!,
            rotation: .random(in: 0...360),
            delay: .random(in: 0...0.4),
            duration: .random(in: 1.2...2.0)
        )
    }
}

struct ConfettiShape: View {
    let piece: ConfettiPiece
    @State private var animating = false
    @State private var rotation: Double = 0

    var body: some View {
        Rectangle()
            .fill(piece.color)
            .rotationEffect(.degrees(rotation))
            .offset(
                x: animating ? piece.drift : 0,
                y: animating ? 700 : -50
            )
            .opacity(animating ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: piece.duration).delay(piece.delay)) {
                    animating = true
                }
                withAnimation(.linear(duration: piece.duration * 1.5).delay(piece.delay)) {
                    rotation = piece.rotation + .random(in: 360...1080)
                }
            }
    }
}
