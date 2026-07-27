import SwiftUI
import AppKit

/// 薪辛 品牌 Logo —— 直接用 Dock 的 PNG（单一数据源，方向绝对正确）
/// PNG 路径：Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png
struct BrandLogo: View {
    let size: CGFloat
    var showRing: Bool = false
    var progress: Double = 0

    init(size: CGFloat, showRing: Bool = false, progress: Double = 0) {
        self.size = size
        self.showRing = showRing
        self.progress = progress
    }

    var body: some View {
        AppIconImage(size: size)
    }
}

/// 直接渲染 App 图标 PNG（透明背景版本，自适应暗/亮模式）
struct AppIconImage: View {
    let size: CGFloat
    var cornerRadiusRatio: CGFloat = 0.225   // 与 macOS app icon 圆角比例一致

    var body: some View {
        if let image = AppIconLoader.loadIcon() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // 兜底：纯色块
            RoundedRectangle(cornerRadius: size * cornerRadiusRatio, style: .continuous)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
        }
    }
}

/// 巨大背景品牌标识（透明度低，直接复用同一张 PNG）
struct BackgroundBrandMark: View {
    let opacity: Double
    var body: some View {
        AppIconImage(size: 600)
            .opacity(opacity)
            .blur(radius: 2)
            .offset(x: 200, y: -100)
    }
}

/// 兼容旧接口：极简金币图标（用于其他需要小图的地方）
struct GoldBarSmall: View {
    let size: CGFloat
    var body: some View {
        AppIconImage(size: size)
    }
}
