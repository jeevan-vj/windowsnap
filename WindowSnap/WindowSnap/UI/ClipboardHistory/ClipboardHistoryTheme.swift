import AppKit

enum ClipboardHistoryTheme {
    static let animationFast: TimeInterval = 0.12
    static let animationNormal: TimeInterval = 0.18
    static let searchDebounceInterval: TimeInterval = 0.25

    static let cardCornerRadius: CGFloat = 10
    static let iconCornerRadius: CGFloat = 8
    static let chipCornerRadius: CGFloat = 8
    static let controlCornerRadius: CGFloat = 10

    static let windowCornerRadius: CGFloat = 16
    static let windowWidth: CGFloat = 440
    static let windowHeight: CGFloat = 540
    static let rowHeight: CGFloat = 64
    static let imageRowHeight: CGFloat = 76
    static let headerRowHeight: CGFloat = 24

    static let contentInset: CGFloat = 16
    static let topInset: CGFloat = 20

    static let selectionBackgroundAlpha: CGFloat = 0.08
    static let selectionBorderAlpha: CGFloat = 0.28
    static let selectionBorderWidth: CGFloat = 1
    static let hoverBackgroundAlpha: CGFloat = 0.04

    static let chipActiveBackgroundAlpha: CGFloat = 0.14
    static let chipInactiveBackgroundAlpha: CGFloat = 0.10

    static var windowBackingAlpha: CGFloat { 0.88 }
    static var searchBorderAlpha: CGFloat { 0.35 }
    static var searchFocusBorderAlpha: CGFloat { 0.55 }

    static var footerFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    }

    static var footerTextColor: NSColor { .secondaryLabelColor }
}
