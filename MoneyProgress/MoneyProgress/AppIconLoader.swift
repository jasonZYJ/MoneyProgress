import AppKit

/// 应用图标加载器 - 仅供界面内的 BrandLogo 复用
/// 注意：不要用 NSApplication.shared.applicationIconImage 设置 dock 图标
/// 否则会覆盖 bundle 多尺寸图标，导致 dock 显示尺寸异常
enum AppIconLoader {
    /// 加载 app 图标 PNG（供 BrandLogo 等界面组件复用）
    static func loadIcon() -> NSImage? {
        // 1) 优先从 bundle Assets.xcassets/AppIcon.appiconset 加载（最大尺寸）
        if let url = Bundle.main.url(forResource: "icon_1024x1024", withExtension: "png", subdirectory: "Assets.xcassets/AppIcon.appiconset"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: "icon_512x512", withExtension: "png", subdirectory: "Assets.xcassets/AppIcon.appiconset"),
           let img = NSImage(contentsOf: url) {
            return img
        }

        // 2) 回退：直接读 Resources/AppIcon.png
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }

        // 3) 最后回退：扫 bundle 中所有可能的 PNG
        if let resourcePath = Bundle.main.resourcePath {
            let candidates = [
                "Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png",
                "Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png",
                "AppIcon.png",
            ]
            for path in candidates {
                let full = (resourcePath as NSString).appendingPathComponent(path)
                if FileManager.default.fileExists(atPath: full),
                   let img = NSImage(contentsOfFile: full) {
                    return img
                }
            }
        }

        return nil
    }
}
