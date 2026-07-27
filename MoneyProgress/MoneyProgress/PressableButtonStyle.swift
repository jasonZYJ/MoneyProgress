//
//  PressableButtonStyle.swift
//  MoneyProgress
//
//  按钮按下反馈（hover/press 动画）
//

import SwiftUI

/// 按下时缩放反馈 + 透明度变化的按钮样式
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
