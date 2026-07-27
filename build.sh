#!/bin/bash
#
# build.sh - 薪辛 / Earnest macOS 应用构建脚本
#
# 步骤：
# 1. 编译单元测试并运行
# 2. 编译 SwiftUI 应用
# 3. 打包 .app
# 4. 复制资源（avatar、JSON、多语言）
# 5. ad-hoc 签名
# 6. 制作 DMG
#

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Earnest"
DISPLAY_NAME="薪辛"
BUNDLE_ID="wiki.qaq.Earnest"
APP_VERSION="1.2.0"
BUILD_NUMBER="$(date +%Y%m%d%H%M%S)"

# 路径
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_DIR="$PROJECT_DIR/build"
DMG_PATH="$DMG_DIR/$APP_NAME-v$APP_VERSION.dmg"
SRC_DIR="$PROJECT_DIR/MoneyProgress/MoneyProgress"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] ⚠️${NC} $1"; }
err() { echo -e "${RED}[$(date +%H:%M:%S)] ❌${NC} $1"; }

# 步骤 0：环境检查
log "环境检查..."
if ! command -v swiftc &> /dev/null; then
    err "swiftc 未找到，请安装 Xcode 或 Command Line Tools"
    exit 1
fi
if ! command -v hdiutil &> /dev/null; then
    err "hdiutil 未找到（仅 macOS 支持）"
    exit 1
fi
SWIFT_VERSION=$(swift --version 2>&1 | head -1)
log "Swift: $SWIFT_VERSION"

# 步骤 1：编译 + 跑单元测试
log "步骤 1/6: 编译单元测试..."
cd "$SRC_DIR/Models"

# 先创建 build 目录
mkdir -p "$PROJECT_DIR/build"

swiftc -O \
    EarningsCalculatorTests.swift \
    WorkSchedule.swift \
    EarningsCalculator.swift \
    -o "$PROJECT_DIR/build/unit_tests" 2>&1 | grep -v "warning" || true

if [ ! -f "$PROJECT_DIR/build/unit_tests" ]; then
    err "单元测试编译失败"
    exit 1
fi

log "运行单元测试..."
"$PROJECT_DIR/build/unit_tests"
if [ $? -ne 0 ]; then
    err "单元测试失败，请修复后重试"
    exit 1
fi
log "✅ 单元测试通过"

cd "$PROJECT_DIR"

# 步骤 2：清理
log "步骤 2/6: 清理构建目录..."
rm -rf "$APP_DIR"
rm -f "$DMG_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 步骤 3：编译 SwiftUI 应用
log "步骤 3/6: 编译 SwiftUI 应用..."

# 收集 Swift 源文件（排除单元测试）
SWIFT_SOURCES=()
for f in "$SRC_DIR"/*.swift "$SRC_DIR/Extension"/*.swift "$SRC_DIR/Models"/*.swift; do
    # 排除测试文件（含 @main）
    if [[ "$f" == *Tests* ]] || [[ "$f" == *tests* ]]; then
        continue
    fi
    if [ -f "$f" ]; then
        SWIFT_SOURCES+=("$f")
    fi
done

# Colorful 包源
COLORFUL_DIR="$PROJECT_DIR/MoneyProgress/Colorful"
COLORFUL_SOURCES=()
if [ -d "$COLORFUL_DIR/Sources/Colorful" ]; then
    for f in "$COLORFUL_DIR/Sources/Colorful"/*.swift; do
        if [ -f "$f" ]; then
            COLORFUL_SOURCES+=("$f")
        fi
    done
fi

log "  找到 ${#SWIFT_SOURCES[@]} 个主源文件 + ${#COLORFUL_SOURCES[@]} 个 Colorful 源文件"

MACOS_DEPLOYMENT_TARGET="13.0"

# 第一步：编译 Colorful 为静态库 + module
COLORFUL_MODULE_DIR="$PROJECT_DIR/build/ColorfulModule"
rm -rf "$COLORFUL_MODULE_DIR"
mkdir -p "$COLORFUL_MODULE_DIR"

log "  编译 Colorful 模块..."

# 1) 生成 .swiftmodule（驱动 module 编译）
swiftc -O \
    -target arm64-apple-macos$MACOS_DEPLOYMENT_TARGET \
    -parse-as-library \
    -module-name Colorful \
    -emit-module -emit-module-path "$COLORFUL_MODULE_DIR/Colorful.swiftmodule" \
    -emit-object \
    "${COLORFUL_SOURCES[@]}" 2>&1 | tail -5

# 移动所有 .o 到模块目录
mv Colorful-*.o "$COLORFUL_MODULE_DIR/" 2>/dev/null || true
mv *.o "$COLORFUL_MODULE_DIR/" 2>/dev/null || true

# 2) 打包为静态库
ar -rcs "$COLORFUL_MODULE_DIR/libColorful.a" "$COLORFUL_MODULE_DIR"/*.o
ranlib "$COLORFUL_MODULE_DIR/libColorful.a"

# 验证
if [ ! -f "$COLORFUL_MODULE_DIR/libColorful.a" ]; then
    err "Colorful 静态库未生成"
    exit 1
fi
log "  Colorful.a: $(ls -lh $COLORFUL_MODULE_DIR/libColorful.a | awk '{print $5}')"

# 第二步：编译主应用，链接 Colorful
log "  编译主应用..."
swiftc -O \
    -target arm64-apple-macos$MACOS_DEPLOYMENT_TARGET \
    -I "$COLORFUL_MODULE_DIR" \
    -L "$COLORFUL_MODULE_DIR" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Charts \
    -framework UserNotifications \
    -parse-as-library \
    "${SWIFT_SOURCES[@]}" \
    -lColorful \
    -o "$MACOS_DIR/$APP_NAME" 2>&1 | tee /tmp/mp_build.log | tail -20

if [ ! -f "$MACOS_DIR/$APP_NAME" ]; then
    err "编译失败，详情见 /tmp/mp_build.log"
    cat /tmp/mp_build.log
    exit 1
fi
log "✅ 编译成功"

# 步骤 4：打包 .app（复制资源 + Info.plist）
log "步骤 4/6: 打包 .app..."

# 复制资源（Assets.xcassets 由后续 actool 编译，不在此处复制）
cp "$SRC_DIR/Resoucre/ISO_4217_Currency _Codes.json" "$RESOURCES_DIR/" 2>/dev/null || true

# 复制多语言
for lang in en.lproj zh-Hans.lproj zh-Hant.lproj; do
    if [ -d "$SRC_DIR/$lang" ]; then
        cp -R "$SRC_DIR/$lang" "$RESOURCES_DIR/"
    fi
done

# 生成完整 Info.plist
log "  生成 Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MACOS_DEPLOYMENT_TARGET}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
    </array>
</dict>
</plist>
PLIST

# 编译 Assets.xcassets → Assets.car（Dock/Launchpad/系统设置识别 AppIcon）
if command -v actool >/dev/null 2>&1 && [ -d "$SRC_DIR/Assets.xcassets" ]; then
    log "  编译 Assets.xcassets..."
    rm -rf "$RESOURCES_DIR/Assets.xcassets"  # 不再需要散文件
    actool \
        --output "$RESOURCES_DIR" \
        --output-format human-readable-text \
        --notices -w \
        --minimum-deployment-target "$MACOS_DEPLOYMENT_TARGET" \
        --target-type app \
        --bundle-id "$BUNDLE_ID" \
        --compile-resources-for-install \
        --platform macosx \
        --include-all-app-store-resources \
        "$SRC_DIR/Assets.xcassets" 2>&1 | tail -5 || warn "actool 失败，回退为复制 png"
    if [ -f "$RESOURCES_DIR/Assets.car" ]; then
        log "  ✅ Assets.car 已生成 ($(du -h $RESOURCES_DIR/Assets.car | cut -f1))"
    fi
fi

# 如果 actool 不可用或失败：回退方案——直接复制 png + 经典 CFBundleIconFile
if [ ! -f "$RESOURCES_DIR/Assets.car" ]; then
    warn "回退为复制 png（actool 不可用）"
    rm -rf "$RESOURCES_DIR/Assets.xcassets"
    if [ -d "$SRC_DIR/Assets.xcassets" ]; then
        cp -R "$SRC_DIR/Assets.xcassets" "$RESOURCES_DIR/"
        # 按优先级查找最大尺寸图标
        ICON_SRC="$SRC_DIR/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"
        [ -f "$ICON_SRC" ] || ICON_SRC="$SRC_DIR/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png"
        [ -f "$ICON_SRC" ] || ICON_SRC="$SRC_DIR/Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
        if [ -f "$ICON_SRC" ]; then
            cp "$ICON_SRC" "$RESOURCES_DIR/AppIcon.png"
            # 经典 CFBundleIconFile 优先级高于 CFBundleIconName
            /usr/libexec/PlistBuddy -c "Delete :CFBundleIconFile" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
            /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS_DIR/Info.plist" 2>/dev/null || true
            log "  ✅ AppIcon.png 复制完成（$(du -h "$RESOURCES_DIR/AppIcon.png" | cut -f1)）"
        else
            warn "未找到合适尺寸的图标源文件"
        fi
    fi
fi

# 创建 PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

log "✅ .app 打包完成"

# 步骤 5：ad-hoc 签名（iCloud entitlements 可选）
# 注：ad-hoc 签名不支持 iCloud KVS entitlement（需要付费 Apple Developer 账号）
# 所以默认不带 entitlement，iCloud 同步会自动降级为本地模式
# 如需启用 iCloud 同步：
#   1) 注册 Apple Developer 账号
#   2) 修改 MoneyProgress.entitlements 中的 TeamIdentifierPrefix 为你的 Team ID
#   3) 重新构建
log "步骤 5/6: ad-hoc 签名..."
codesign --force --deep --sign - "$APP_DIR" 2>&1 | tail -5
log "✅ 签名完成"

# 验证可启动
log "  验证可执行文件..."
file "$MACOS_DIR/$APP_NAME"
log "✅ 文件存在"

# 步骤 6：打包（DMG + ZIP）
log "步骤 6/6: 打包分发文件..."

DMG_PATH="$DMG_DIR/${APP_NAME}-v${APP_VERSION}.dmg"

# 6a. 尝试 DMG（用 UDIF 模式，无需挂载）
DMG_OK=false
if hdiutil create -size 16m -fs HFS+ -volname "$DISPLAY_NAME" -srcfolder "$APP_DIR" "$DMG_PATH" 2>/dev/null; then
    DMG_OK=true
fi

if [ "$DMG_OK" = true ] && [ -f "$DMG_PATH" ]; then
    SIZE=$(du -h "$DMG_PATH" | cut -f1)
    log "✅ DMG: $DMG_PATH ($SIZE)"
else
    warn "DMG 创建失败（沙盒限制），改用 ZIP 打包"
    ZIP_PATH="$DMG_DIR/${APP_NAME}-v${APP_VERSION}.zip"
    cd "$DMG_DIR"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "${APP_NAME}-v${APP_VERSION}.zip" 2>&1 | tail -3
    if [ -f "$ZIP_PATH" ]; then
        SIZE=$(du -h "$ZIP_PATH" | cut -f1)
        log "✅ ZIP: $ZIP_PATH ($SIZE)"
        DMG_PATH="$ZIP_PATH"
    else
        err "DMG 和 ZIP 打包都失败"
        exit 1
    fi
fi

# 总结
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  🎉 构建完成${NC}"
echo -e "${GREEN}========================================${NC}"
echo "  App:   $APP_DIR"
echo "  分发:  $DMG_PATH"
echo "  版本:  $APP_VERSION ($BUILD_NUMBER)"
echo ""
echo "  安装方式："
if [[ "$DMG_PATH" == *.dmg ]]; then
    echo "    方式 A: 双击 .dmg，将 薪辛.app 拖入 Applications"
    echo "    方式 B: open '$APP_DIR'"
else
    echo "    方式 A: 解压 .zip，将 薪辛.app 移入 Applications"
    echo "    方式 B: open '$APP_DIR'"
fi
echo ""
