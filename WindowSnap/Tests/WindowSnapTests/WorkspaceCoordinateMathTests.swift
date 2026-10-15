import CoreGraphics
import XCTest
@testable import WindowSnap

final class WorkspaceCoordinateMathTests: XCTestCase {
    func testNormalizedFramesRoundTripAcrossScreenLayouts() {
        let cases: [(visible: CGRect, window: CGRect)] = [
            (
                CGRect(x: 0, y: 25, width: 1728, height: 1080),
                CGRect(x: 100, y: 125, width: 864, height: 540)
            ),
            (
                CGRect(x: -1920, y: 0, width: 1920, height: 1040),
                CGRect(x: -1800, y: 80, width: 900, height: 700)
            ),
            (
                CGRect(x: 1728, y: -900, width: 1440, height: 900),
                CGRect(x: 1900, y: -800, width: 720, height: 450)
            )
        ]

        for item in cases {
            let normalized = WorkspaceCoordinateMath.normalizedFrame(item.window, in: item.visible)
            let restored = WorkspaceCoordinateMath.denormalizedFrame(normalized, in: item.visible)
            assertEqual(restored, item.window)
        }
    }

    func testNormalizedFrameMovesProportionallyToNewDisplay() {
        let oldVisible = CGRect(x: -1920, y: 0, width: 1920, height: 1040)
        let oldWindow = CGRect(x: -1440, y: 260, width: 960, height: 520)
        let normalized = WorkspaceCoordinateMath.normalizedFrame(oldWindow, in: oldVisible)

        let newVisible = CGRect(x: 0, y: 30, width: 2560, height: 1410)
        let restored = WorkspaceCoordinateMath.denormalizedFrame(normalized, in: newVisible)

        assertEqual(restored, CGRect(x: 640, y: 382.5, width: 1280, height: 705))
    }

    func testAppKitAndAXTopLeftConversionRoundTrips() {
        let appKitFrame = CGRect(x: -800, y: 120, width: 640, height: 480)
        let axFrame = WorkspaceCoordinateMath.axFrame(
            fromAppKit: appKitFrame,
            primaryScreenHeight: 1117
        )

        XCTAssertEqual(axFrame, CGRect(x: -800, y: 517, width: 640, height: 480))
        assertEqual(
            WorkspaceCoordinateMath.appKitFrame(fromAX: axFrame, primaryScreenHeight: 1117),
            appKitFrame
        )
    }

    func testLegacyMigrationPrefersDisplayIDThenFallsBackToIndex() {
        let screens = [
            WorkspaceScreenGeometry(
                displayUUID: "main",
                displayID: 10,
                index: 0,
                visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 800)
            ),
            WorkspaceScreenGeometry(
                displayUUID: "side",
                displayID: 20,
                index: 1,
                visibleFrame: CGRect(x: -800, y: 0, width: 800, height: 600)
            )
        ]

        let byID = WorkspaceCoordinateMath.migrateLegacyFrame(
            CGRect(x: -600, y: 150, width: 400, height: 300),
            displayUUID: nil,
            legacyDisplayID: 20,
            legacyIndex: 0,
            screens: screens
        )
        XCTAssertEqual(byID?.screen.displayUUID, "side")
        assertEqual(byID?.frame, CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5))

        let byIndex = WorkspaceCoordinateMath.migrateLegacyFrame(
            CGRect(x: -800, y: 0, width: 800, height: 600),
            displayUUID: nil,
            legacyDisplayID: 999,
            legacyIndex: 1,
            screens: screens
        )
        XCTAssertEqual(byIndex?.screen.displayUUID, "side")
        assertEqual(byIndex?.frame, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testLegacyMigrationUsesFrameCenterBeforeStaleScreenIndex() {
        let screens = migrationScreens()

        let migrated = WorkspaceCoordinateMath.migrateLegacyFrame(
            CGRect(x: -700, y: 100, width: 400, height: 300),
            displayUUID: nil,
            legacyDisplayID: nil,
            legacyIndex: 0,
            screens: screens
        )

        XCTAssertEqual(migrated?.screen.displayUUID, "side")
        assertEqual(migrated?.frame, CGRect(x: 0.125, y: 1.0 / 6.0, width: 0.5, height: 0.5))
    }

    func testLegacyMigrationUsesLargestIntersectionWhenCenterIsOffscreen() {
        let screens = migrationScreens()

        let migrated = WorkspaceCoordinateMath.migrateLegacyFrame(
            CGRect(x: -900, y: 100, width: 200, height: 300),
            displayUUID: nil,
            legacyDisplayID: nil,
            legacyIndex: 0,
            screens: screens
        )

        XCTAssertEqual(migrated?.screen.displayUUID, "side")
    }

    func testLegacyMigrationUsesIndexOnlyWhenGeometryDoesNotMatch() {
        let migrated = WorkspaceCoordinateMath.migrateLegacyFrame(
            CGRect(x: 4_000, y: 4_000, width: 200, height: 100),
            displayUUID: nil,
            legacyDisplayID: nil,
            legacyIndex: 1,
            screens: migrationScreens()
        )

        XCTAssertEqual(migrated?.screen.displayUUID, "side")
    }

    func testArrangementRemainsVersionOneWhenLegacyScreenCannotBeMatched() throws {
        let decoded = try makeLegacyArrangement(
            frame: CGRect(x: 4_000, y: 4_000, width: 200, height: 100),
            screenIndex: 9
        )

        let migrated = decoded.migrated(to: migrationScreens())

        XCTAssertEqual(migrated, decoded)
        XCTAssertEqual(migrated.formatVersion, 1)
    }

    func testLegacyArrangementDecodesAsVersionOneAndMigrates() throws {
        let legacy = WorkspaceArrangement(
            name: "Legacy",
            appLayouts: [
                AppLayout(
                    bundleIdentifier: "example.app",
                    applicationName: "Example",
                    windowLayouts: [
                        WindowLayout(
                            windowTitle: "Document",
                            frame: CGRect(x: 100, y: 200, width: 500, height: 400),
                            screenIndex: 0
                        )
                    ]
                )
            ]
        )
        let encoded = try JSONEncoder().encode(legacy)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "formatVersion")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(WorkspaceArrangement.self, from: legacyData)
        XCTAssertEqual(decoded.formatVersion, 1)

        let migrated = decoded.migrated(to: [
            WorkspaceScreenGeometry(
                displayUUID: "display-a",
                displayID: 42,
                index: 0,
                visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800)
            )
        ])
        XCTAssertEqual(migrated.formatVersion, WorkspaceArrangement.currentFormatVersion)
        XCTAssertEqual(migrated.appLayouts[0].windowLayouts[0].displayUUID, "display-a")
        assertEqual(
            migrated.appLayouts[0].windowLayouts[0].frame,
            CGRect(x: 0.1, y: 0.25, width: 0.5, height: 0.5)
        )
    }

    private func migrationScreens() -> [WorkspaceScreenGeometry] {
        [
            WorkspaceScreenGeometry(
                displayUUID: "main",
                displayID: 10,
                index: 0,
                visibleFrame: CGRect(x: 0, y: 0, width: 1_000, height: 800)
            ),
            WorkspaceScreenGeometry(
                displayUUID: "side",
                displayID: 20,
                index: 1,
                visibleFrame: CGRect(x: -800, y: 0, width: 800, height: 600)
            )
        ]
    }

    private func makeLegacyArrangement(frame: CGRect, screenIndex: Int) throws -> WorkspaceArrangement {
        let arrangement = WorkspaceArrangement(
            name: "Legacy",
            appLayouts: [
                AppLayout(
                    bundleIdentifier: "example.app",
                    applicationName: "Example",
                    windowLayouts: [
                        WindowLayout(windowTitle: "Document", frame: frame, screenIndex: screenIndex)
                    ]
                )
            ]
        )
        let encoded = try JSONEncoder().encode(arrangement)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "formatVersion")
        return try JSONDecoder().decode(
            WorkspaceArrangement.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func assertEqual(
        _ actual: CGRect?,
        _ expected: CGRect,
        accuracy: CGFloat = 0.000_001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected a frame", file: file, line: line)
            return
        }
        XCTAssertEqual(actual.origin.x, expected.origin.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.origin.y, expected.origin.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: accuracy, file: file, line: line)
    }
}
