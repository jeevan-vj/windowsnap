import AppKit
@testable import WindowSnap
import XCTest

final class ClipboardHistoryUIPolishTests: XCTestCase {
    func testThemeUsesCompactStableClipboardRows() {
        XCTAssertEqual(ClipboardHistoryTheme.rowHeight, 58)
        XCTAssertEqual(ClipboardHistoryTheme.imageRowHeight, 68)
        XCTAssertEqual(ClipboardHistoryTheme.headerRowHeight, 24)
        XCTAssertEqual(ClipboardHistoryTheme.footerHeight, 24)
        XCTAssertEqual(ClipboardHistoryTheme.searchHeight, 38)
        XCTAssertEqual(ClipboardHistoryTheme.searchActionButtonSize, 32)
        XCTAssertEqual(ClipboardHistoryTheme.filterBarHeight, 24)
    }

    func testSearchBarActionButtonsUseMatchingHitTargets() {
        let searchBar = ClipboardHistorySearchBar(frame: NSRect(x: 0, y: 0, width: 440, height: ClipboardHistoryTheme.searchHeight))
        searchBar.layoutSubtreeIfNeeded()

        let actionButtons = searchBar.allSubviews(of: NSButton.self)
            .filter { $0.accessibilityLabel() == "Clear all clipboard history" || $0.accessibilityLabel() == "Close clipboard history" }

        XCTAssertEqual(actionButtons.count, 2)
        let allViews: [NSView] = searchBar.allSubviews(of: NSView.self)
        let actionContainers = allViews.filter { (view: NSView) -> Bool in
            abs(view.frame.width - ClipboardHistoryTheme.searchActionButtonSize) < 0.5 &&
                abs(view.frame.height - ClipboardHistoryTheme.searchActionButtonSize) < 0.5
        }
        XCTAssertGreaterThanOrEqual(actionContainers.count, 2)
        for button in actionButtons {
            XCTAssertLessThanOrEqual(button.frame.width, ClipboardHistoryTheme.searchActionButtonSize)
            XCTAssertLessThanOrEqual(button.frame.height, ClipboardHistoryTheme.searchActionButtonSize)
        }
    }

    func testClipboardViewsRenderNonBlankBitmaps() throws {
        let sampleTextItem = ClipboardHistoryItem(content: "https://screenshot-enhancer.vercel.app/", type: .url)

        let views: [NSView] = [
            ClipboardHistorySearchBar(frame: NSRect(x: 0, y: 0, width: 440, height: ClipboardHistoryTheme.searchHeight)),
            ClipboardHistoryFilterBar(frame: NSRect(x: 0, y: 0, width: 440, height: ClipboardHistoryTheme.filterBarHeight)),
            ClipboardHistoryFooterView(frame: NSRect(x: 0, y: 0, width: 440, height: ClipboardHistoryTheme.footerHeight)),
            configuredCell(for: sampleTextItem, frame: NSRect(x: 0, y: 0, width: 420, height: ClipboardHistoryTheme.rowHeight)),
        ]

        for view in views {
            view.layoutSubtreeIfNeeded()
            let image = try render(view)
            XCTAssertGreaterThan(nonTransparentPixelCount(in: image), 50, "Expected \(type(of: view)) to render visible content")
        }
    }

    func testSelectedCellKeepsStableBounds() {
        let item = ClipboardHistoryItem(content: "Copied text", type: .text)
        let cell = configuredCell(for: item, frame: NSRect(x: 0, y: 0, width: 420, height: ClipboardHistoryTheme.rowHeight))
        let originalBounds = cell.bounds

        cell.isSelected = true
        cell.layoutSubtreeIfNeeded()

        XCTAssertEqual(cell.bounds, originalBounds)
    }

    private func configuredCell(for item: ClipboardHistoryItem, frame: NSRect) -> ClipboardHistoryCellView {
        let cell = ClipboardHistoryCellView(frame: frame)
        cell.configure(with: item)
        cell.layoutSubtreeIfNeeded()
        return cell
    }

    private func render(_ view: NSView) throws -> NSBitmapImageRep {
        view.wantsLayer = true
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw XCTSkip("Unable to create bitmap representation")
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep
    }

    private func nonTransparentPixelCount(in rep: NSBitmapImageRep) -> Int {
        var count = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.01 {
                    count += 1
                }
            }
        }
        return count
    }
}

private extension NSView {
    func allSubviews<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { subview -> [T] in
            var matches = subview.allSubviews(of: type)
            if let typed = subview as? T {
                matches.insert(typed, at: 0)
            }
            return matches
        }
    }
}
