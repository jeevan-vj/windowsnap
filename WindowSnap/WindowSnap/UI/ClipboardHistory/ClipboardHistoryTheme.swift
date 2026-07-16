import AppKit

enum ClipboardHistoryTheme {
    static let animationFast: TimeInterval = 0.12
    static let animationNormal: TimeInterval = 0.18
    static let searchDebounceInterval: TimeInterval = 0.25

    static let cardCornerRadius: CGFloat = 10
    static let iconCornerRadius: CGFloat = 8
    static let chipCornerRadius: CGFloat = 7
    static let controlCornerRadius: CGFloat = 12
    static let actionButtonCornerRadius: CGFloat = 8

    static let windowCornerRadius: CGFloat = 16
    static let windowWidth: CGFloat = 440
    static let windowHeight: CGFloat = 540
    static let rowHeight: CGFloat = 58
    static let imageRowHeight: CGFloat = 68
    static let headerRowHeight: CGFloat = 24
    static let footerHeight: CGFloat = 24

    static let contentInset: CGFloat = 16
    static let topInset: CGFloat = 22
    static let searchHeight: CGFloat = 38
    static let searchActionButtonSize: CGFloat = 32
    static let searchActionIconSize: CGFloat = 18
    static let searchActionSpacing: CGFloat = 6
    static let filterBarHeight: CGFloat = 24
    static let filterTopSpacing: CGFloat = 10
    static let listTopSpacing: CGFloat = 14
    static let footerBottomInset: CGFloat = 14
    static let footerTopSpacing: CGFloat = 10

    static let selectionBackgroundAlpha: CGFloat = 0.10
    static let selectionBorderAlpha: CGFloat = 0.34
    static let selectionBorderWidth: CGFloat = 1
    static let hoverBackgroundAlpha: CGFloat = 0.04

    static let chipActiveBackgroundAlpha: CGFloat = 0.16
    static let chipInactiveBackgroundAlpha: CGFloat = 0.06

    static var windowBackingAlpha: CGFloat { 0.88 }
    static var searchBorderAlpha: CGFloat { 0.28 }
    static var searchFocusBorderAlpha: CGFloat { 0.50 }

    static var footerFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    }

    static var footerTextColor: NSColor { .secondaryLabelColor }
}
