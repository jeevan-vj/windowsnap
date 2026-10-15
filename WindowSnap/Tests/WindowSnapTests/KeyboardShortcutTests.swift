@testable import WindowSnap
import XCTest

final class KeyboardShortcutTests: XCTestCase {
    func testParsingAcceptsSupportedShortcutAndRoundTripsDisplayString() throws {
        let shortcut = try KeyboardShortcut.parse("Control+Alt+Shift+Left")

        XCTAssertEqual(shortcut, try KeyboardShortcut.parse(shortcut.displayString))
        XCTAssertEqual(shortcut.displayString, "ctrl+option+shift+left")
        XCTAssertEqual(shortcut.glyphString, "⌃⌥⇧←")
    }

    func testParsingRejectsShiftOnlyShortcut() {
        XCTAssertThrowsError(try KeyboardShortcut.parse("shift+a")) { error in
            XCTAssertEqual(error as? KeyboardShortcutParseError, .missingModifier)
        }
    }

    func testParsingRejectsJunkEmptyAndDuplicateModifiers() {
        XCTAssertThrowsError(try KeyboardShortcut.parse(""))
        XCTAssertThrowsError(try KeyboardShortcut.parse("cmd+banana"))
        XCTAssertThrowsError(try KeyboardShortcut.parse("cmd+command+a")) { error in
            XCTAssertEqual(error as? KeyboardShortcutParseError, .duplicateModifier("command"))
        }
        XCTAssertThrowsError(try KeyboardShortcut.parse("cmd+a+b"))
    }

    func testConflictDetectionUsesNormalizedShortcutValues() throws {
        let shortcuts = [
            "left": try KeyboardShortcut.parse("ctrl+option+left"),
            "alsoLeft": try KeyboardShortcut.parse("control+alt+left"),
            "right": try KeyboardShortcut.parse("ctrl+option+right")
        ]

        let conflicts = KeyboardShortcut.conflicts(in: shortcuts)

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[try KeyboardShortcut.parse("ctrl+option+left")], ["left", "alsoLeft"])
    }

    func testExactLegacyDefaultsMigrateButCustomShortcutsArePreserved() {
        XCTAssertEqual(
            ShortcutDefaultsMigration.migrate(ShortcutDefaultsMigration.legacy),
            ShortcutDefaultsMigration.rectangleStyle
        )

        var customized = ShortcutDefaultsMigration.legacy
        customized["center"] = "ctrl+option+x"
        XCTAssertEqual(ShortcutDefaultsMigration.migrate(customized), customized)
        XCTAssertEqual(
            ShortcutDefaultsMigration.migrate(ShortcutDefaultsMigration.legacy, explicitlyKeptLegacy: true),
            ShortcutDefaultsMigration.legacy
        )
    }
}
