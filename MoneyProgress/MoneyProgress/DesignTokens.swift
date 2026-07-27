//
//  DesignTokens.swift
//  MoneyProgress
//
//  设计令牌（P1 #8）：统一的间距、圆角、字号
//  解决 padding/radius 散落 12/14/16/18/20 混用问题
//

import SwiftUI

enum DesignTokens {
    // MARK: 间距
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 20

    // MARK: 内边距
    static let cardPadding: CGFloat = 16      // 卡片内 padding
    static let cardPaddingTight: CGFloat = 12  // 紧凑卡片
    static let sectionSpacing: CGFloat = 12   // 卡片间垂直 spacing

    // MARK: 圆角
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 16
    static let radiusXL: CGFloat = 20

    // MARK: 字号
    static let fontHero: CGFloat = 36          // 圆环大数字
    static let fontStat: CGFloat = 16          // metricChip 数值
    static let fontStatTitle: CGFloat = 10
    static let fontLabelMajor: CGFloat = 8     // 主整点
    static let fontLabelMinor: CGFloat = 6     // 次整点
    static let fontCaption: CGFloat = 10

    // MARK: 尺寸
    static let toolbarButtonSize: CGFloat = 30
    static let cardStrokeWidth: CGFloat = 1
    static let currentTimeIndicatorWidth: CGFloat = 2
}
