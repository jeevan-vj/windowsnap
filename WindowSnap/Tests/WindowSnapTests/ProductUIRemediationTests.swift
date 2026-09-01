import AppKit
@testable import WindowSnap
import XCTest

final class ProductUIRemediationTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults.standard.removePersistentDomain(forName: name) }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testShortcutSyntaxAcceptsDocumentedFormatAndRejectsIncompleteInput() {
        let manager = ShortcutManager()
        XCTAssertTrue(manager.isValidShortcutSyntax("cmd+option+1"))
        XCTAssertTrue(manager.isValidShortcutSyntax("ctrl+cmd+r"))
        XCTAssertTrue(manager.isValidShortcutSyntax("cmd+shift+;"))
        XCTAssertFalse(manager.isValidShortcutSyntax("cmd+option"))
        XCTAssertFalse(manager.isValidShortcutSyntax("not-a-shortcut"))
    }

    func testSnippetPickerPlacementStaysInsideVisibleScreen() {
        let visibleFrame = NSRect(x: 0, y: 24, width: 1_440, height: 876)
        let windowSize = NSSize(width: 520, height: 420)

        let nearBottom = SnippetPickerWindow.constrainedOrigin(
            nearMouse: NSPoint(x: 720, y: 40),
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )
        let nearRightEdge = SnippetPickerWindow.constrainedOrigin(
            nearMouse: NSPoint(x: 1_435, y: 700),
            windowSize: windowSize,
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThanOrEqual(nearBottom.y, visibleFrame.minY)
        XCTAssertLessThanOrEqual(nearBottom.y + windowSize.height, visibleFrame.maxY)
        XCTAssertGreaterThanOrEqual(nearRightEdge.x, visibleFrame.minX)
        XCTAssertLessThanOrEqual(nearRightEdge.x + windowSize.width, visibleFrame.maxX)
    }

    func testCustomPositionMutationsReportDuplicateNamesAndPreserveIdentityOnEdit() throws {
        let defaults = makeDefaults()
        let manager = CustomPositionManager(userDefaults: defaults)
        let original = CustomPosition(name: "Writing", widthPercent: 0.5, heightPercent: 1, xPercent: 0, yPercent: 0)

        XCTAssertNoThrow(try manager.addPosition(original).get())
        let duplicate = CustomPosition(name: "Writing", widthPercent: 0.4, heightPercent: 0.4, xPercent: 0.2, yPercent: 0.2)
        XCTAssertThrowsError(try manager.addPosition(duplicate).get()) { error in
            XCTAssertEqual(error as? ManagedConfigurationError, .duplicateName)
        }

        let updated = original.updating(name: "Editing", widthPercent: 0.6, heightPercent: 0.8, xPercent: 0.1, yPercent: 0.1, shortcut: nil)
        XCTAssertNoThrow(try manager.updatePosition(updated).get())
        XCTAssertEqual(manager.getAllPositions().first?.id, original.id)
        XCTAssertEqual(manager.getAllPositions().first?.name, "Editing")
    }

    func testWorkspaceMetadataEditingPersistsAndDuplicateNamesAreRejected() throws {
        let defaults = makeDefaults()
        let manager = WorkspaceManager(userDefaults: defaults)
        let original = WorkspaceArrangement(name: "Morning", appLayouts: [])

        XCTAssertNoThrow(try manager.addArrangement(original).get())
        XCTAssertThrowsError(try manager.addArrangement(WorkspaceArrangement(name: "Morning", appLayouts: [])).get()) { error in
            XCTAssertEqual(error as? ManagedConfigurationError, .duplicateName)
        }

        let updated = original.updatingMetadata(name: "Afternoon", shortcut: nil)
        XCTAssertNoThrow(try manager.updateArrangement(updated).get())
        XCTAssertEqual(manager.getAllArrangements().first?.id, original.id)
        XCTAssertEqual(manager.getAllArrangements().first?.name, "Afternoon")
    }

    func testClipboardClearBroadcastsGeneralChangeNotification() {
        let defaults = makeDefaults()
        let center = NotificationCenter()
        let store = ClipboardHistoryStore(
            applicationSupportDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
            userDefaults: defaults
        )
        let manager = ClipboardManager(store: store, userDefaults: defaults, notificationCenter: center)
        let expectation = expectation(description: "history changed")
        let token = center.addObserver(forName: .clipboardHistoryDidChange, object: nil, queue: nil) { _ in expectation.fulfill() }

        manager.clearHistory()

        wait(for: [expectation], timeout: 1)
        center.removeObserver(token)
    }

    func testTextExpanderDoesNotEnableWhilePermissionIsMissing() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "WindowSnap_TextExpanderHasPopulatedDefaults")
        let manager = TextExpanderManager(userDefaults: defaults)
        manager.isEnabled = false
        let controller = TextExpanderRuntimeController(
            manager: manager,
            missingPermissions: { [.inputMonitoring] }
        )

        XCTAssertEqual(controller.setDesiredEnabled(true), .needsPermission([.inputMonitoring]))
        XCTAssertFalse(manager.isEnabled)
    }

    func testSettingsUsesFiveItemNativeToolbar() throws {
        let controller = PreferencesWindow()
        let toolbar = try XCTUnwrap(controller.window?.toolbar)

        XCTAssertEqual(toolbar.items.map(\.itemIdentifier), PreferencesWindow.toolbarIdentifiers)
        XCTAssertGreaterThanOrEqual(controller.window?.minSize.width ?? 0, 640)
        XCTAssertGreaterThanOrEqual(controller.window?.minSize.height ?? 0, 480)
        XCTAssertTrue(controller.window?.title.contains("Settings") == true)
        XCTAssertFalse(controller.window?.contentView?.subviews.contains(where: { $0 is NSTabView }) == true)
    }

    func testStatusMenuUsesNativeShortcutColumnsAndReducedHierarchy() throws {
        let controller = StatusBarController()
        let menu = try XCTUnwrap(controller.menuForTesting)
        let visibleTitles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)

        XCTAssertEqual(Array(visibleTitles.prefix(5)), ["Left Half", "Right Half", "Maximize", "Center", "More Positions"])
        XCTAssertTrue(visibleTitles.contains("Settings…"))
        XCTAssertFalse(visibleTitles.contains("Preferences…"))
        XCTAssertFalse(visibleTitles.contains("Restart WindowSnap"))
        XCTAssertFalse(visibleTitles.contains(where: { $0.contains("(") && $0.contains("⌘") }))

        let leftHalf = try XCTUnwrap(menu.item(withTitle: "Left Half"))
        XCTAssertEqual(leftHalf.keyEquivalent, "\u{F702}")
        XCTAssertEqual(leftHalf.keyEquivalentModifierMask, [.command, .shift])

        let clipboard = try XCTUnwrap(menu.item(withTitle: "Clipboard History")?.submenu)
        let showClipboard = try XCTUnwrap(clipboard.item(withTitle: "Show Clipboard History"))
        XCTAssertEqual(showClipboard.keyEquivalent, "v")
        XCTAssertEqual(showClipboard.keyEquivalentModifierMask, [.command, .shift])
        XCTAssertNotNil(clipboard.item(withTitle: "Pause History"))
    }

    private func makeDefaults() -> UserDefaults {
        let name = "ProductUIRemediationTests.\(UUID().uuidString)"
        suiteNames.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
