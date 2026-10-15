import CoreGraphics

/// A value-only description of a display used by workspace persistence and tests.
struct WorkspaceScreenGeometry: Equatable {
    let displayUUID: String?
    let displayID: UInt32?
    let index: Int
    let visibleFrame: CGRect
}

enum WorkspaceCoordinateMath {
    static func normalizedFrame(_ frame: CGRect, in visibleFrame: CGRect) -> CGRect {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else { return .zero }
        return CGRect(
            x: (frame.minX - visibleFrame.minX) / visibleFrame.width,
            y: (frame.minY - visibleFrame.minY) / visibleFrame.height,
            width: frame.width / visibleFrame.width,
            height: frame.height / visibleFrame.height
        )
    }

    static func denormalizedFrame(_ frame: CGRect, in visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: visibleFrame.minX + frame.minX * visibleFrame.width,
            y: visibleFrame.minY + frame.minY * visibleFrame.height,
            width: frame.width * visibleFrame.width,
            height: frame.height * visibleFrame.height
        )
    }

    static func appKitFrame(fromAX frame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: frame.minX,
            y: primaryScreenHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func axFrame(fromAppKit frame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: frame.minX,
            y: primaryScreenHeight - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func screen(
        matchingUUID displayUUID: String?,
        legacyDisplayID: UInt32?,
        legacyIndex: Int,
        in screens: [WorkspaceScreenGeometry]
    ) -> WorkspaceScreenGeometry? {
        if let displayUUID,
           let match = screens.first(where: { $0.displayUUID == displayUUID }) {
            return match
        }
        if let legacyDisplayID,
           let match = screens.first(where: { $0.displayID == legacyDisplayID }) {
            return match
        }
        if let match = screens.first(where: { $0.index == legacyIndex }) {
            return match
        }
        return screens.first
    }

    static func migrateLegacyFrame(
        _ absoluteFrame: CGRect,
        displayUUID: String?,
        legacyDisplayID: UInt32?,
        legacyIndex: Int,
        screens: [WorkspaceScreenGeometry]
    ) -> (frame: CGRect, screen: WorkspaceScreenGeometry)? {
        let screen: WorkspaceScreenGeometry?
        if displayUUID != nil || legacyDisplayID != nil {
            screen = self.screen(
                matchingUUID: displayUUID,
                legacyDisplayID: legacyDisplayID,
                legacyIndex: legacyIndex,
                in: screens
            )
        } else {
            screen = legacyScreen(
                containing: absoluteFrame,
                legacyIndex: legacyIndex,
                screens: screens
            )
        }
        guard let screen else { return nil }
        return (normalizedFrame(absoluteFrame, in: screen.visibleFrame), screen)
    }

    private static func legacyScreen(
        containing absoluteFrame: CGRect,
        legacyIndex: Int,
        screens: [WorkspaceScreenGeometry]
    ) -> WorkspaceScreenGeometry? {
        let usableScreens = screens.filter {
            $0.visibleFrame.width > 0 && $0.visibleFrame.height > 0
        }
        let center = CGPoint(x: absoluteFrame.midX, y: absoluteFrame.midY)
        if let centerMatch = usableScreens.first(where: { $0.visibleFrame.contains(center) }) {
            return centerMatch
        }

        let intersections = usableScreens.map { screen in
            let intersection = screen.visibleFrame.intersection(absoluteFrame)
            return (screen, intersection.isNull ? 0 : intersection.width * intersection.height)
        }
        if let largest = intersections.max(by: { $0.1 < $1.1 }), largest.1 > 0 {
            return largest.0
        }

        return usableScreens.first(where: { $0.index == legacyIndex })
    }
}
