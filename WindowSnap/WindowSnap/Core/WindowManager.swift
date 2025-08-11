import Foundation
import AppKit
import ApplicationServices
import Carbon

class WindowManager {
    static let shared = WindowManager()
    
    private init() {}
    
    func getAllWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var windows: [WindowInfo] = []
        
        for windowDict in windowList {
            guard let windowInfo = parseWindowInfo(from: windowDict) else {
                continue
            }
            windows.append(windowInfo)
        }
        
        return excludeSystemWindows(windows)
    }
    
    func getFocusedWindow() -> WindowInfo? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        var focusedWindow: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        guard result == .success,
              let windowElement = focusedWindow else {
            return nil
        }
        
        let axElement = windowElement as! AXUIElement
        return getWindowInfoFromAccessibility(axElement: axElement, processID: frontmostApp.processIdentifier)
    }
    
    // NEW: Get window info directly from AX API (like Spectacle does)
    private func getWindowInfoFromAccessibility(axElement: AXUIElement, processID: pid_t) -> WindowInfo? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        var title: CFTypeRef?
        
        // Get window attributes using AX API
        AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &size)
        AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &title)
        
        var axPoint = CGPoint.zero
        var axSize = CGSize.zero
        
        if let pos = position {
            AXValueGetValue(pos as! AXValue, AXValueType.cgPoint, &axPoint)
        }
        
        if let sz = size {
            AXValueGetValue(sz as! AXValue, AXValueType.cgSize, &axSize)
        }
        
        // This frame is already in AX coordinate system (top-left origin)
        let axFrame = CGRect(origin: axPoint, size: axSize)
        
        let windowTitle = title as? String ?? ""
        let app = NSRunningApplication(processIdentifier: processID)
        let applicationName = app?.localizedName ?? "Unknown"
        
        print("AX API Window Info:")
        print("  Position: \(axPoint) (AX coordinates)")
        print("  Size: \(axSize)")
        print("  Frame: \(axFrame) (AX coordinates)")
        
        return WindowInfo(
            windowID: 0, // Not needed since we use AX element directly
            processID: processID,
            applicationName: applicationName,
            windowTitle: windowTitle,
            frame: axFrame, // Store in AX coordinate system
            axElement: axElement
        )
    }
    
    func snapWindow(_ window: WindowInfo, to position: GridPosition) {
        print("=== WINDOW SNAP (SPECTACLE APPROACH) ===")
        print("Window: '\(window.windowTitle)'")
        print("Current AX frame: \(window.frame)")
        
        // Find screen containing this window (using AX coordinates)
        guard let containingScreen = getScreenContainingAXRect(window.frame) else {
            print("ERROR: Could not determine screen for AX window frame: \(window.frame)")
            return
        }
        
        print("Detected screen: \(getScreenDisplayName(containingScreen))")
        print("Screen visible frame (NSScreen): \(containingScreen.visibleFrame)")
        
        // Convert screen visible frame to AX coordinates (like Spectacle does)
        let axScreenFrame = convertNSScreenToAXCoordinates(containingScreen.visibleFrame)
        print("Screen visible frame (AX): \(axScreenFrame)")
        
        // Calculate target frame directly in AX coordinate system
        guard let targetAXFrame = calculateAXFrame(for: position, in: axScreenFrame) else {
            print("ERROR: Could not calculate AX target frame for position: \(position)")
            return
        }
        
        print("Target AX frame: \(targetAXFrame)")
        
        // Move window directly (already in correct AX coordinate system)
        moveWindowToAXFrame(window, frame: targetAXFrame)
        
        print("=== END DEBUG ===")
    }
    
    // Convert NSScreen visible frame to AX coordinate system
    private func convertNSScreenToAXCoordinates(_ nsFrame: CGRect) -> CGRect {
        // Get the main screen height for Y conversion
        let mainScreenHeight = NSScreen.screens[0].frame.height
        
        // Convert NSScreen (bottom-left origin) to AX (top-left origin)
        let axY = mainScreenHeight - nsFrame.maxY
        
        return CGRect(
            x: nsFrame.origin.x,
            y: axY,
            width: nsFrame.width,
            height: nsFrame.height
        )
    }
    
    // Find screen containing AX coordinate rectangle
    private func getScreenContainingAXRect(_ axRect: CGRect) -> NSScreen? {
        // Convert AX center point to NSScreen coordinates for detection
        let axCenter = CGPoint(x: axRect.midX, y: axRect.midY)
        let mainScreenHeight = NSScreen.screens[0].frame.height
        let nsCenter = CGPoint(x: axCenter.x, y: mainScreenHeight - axCenter.y)
        
        for screen in NSScreen.screens {
            if screen.frame.contains(nsCenter) {
                return screen
            }
        }
        
        return NSScreen.main
    }
    
    // Calculate frame in AX coordinate system
    private func calculateAXFrame(for position: GridPosition, in axScreenFrame: CGRect) -> CGRect? {
        switch position {
        // Halves
        case .leftHalf:
            return CGRect(x: axScreenFrame.minX, y: axScreenFrame.minY, 
                         width: axScreenFrame.width / 2, height: axScreenFrame.height)
        case .rightHalf:
            return CGRect(x: axScreenFrame.minX + axScreenFrame.width / 2, y: axScreenFrame.minY,
                         width: axScreenFrame.width / 2, height: axScreenFrame.height)
        case .topHalf:
            return CGRect(x: axScreenFrame.minX, y: axScreenFrame.minY,
                         width: axScreenFrame.width, height: axScreenFrame.height / 2)
        case .bottomHalf:
            return CGRect(x: axScreenFrame.minX, y: axScreenFrame.minY + axScreenFrame.height / 2,
                         width: axScreenFrame.width, height: axScreenFrame.height / 2)
        
        // Quarters
        case .topLeft:
            return CGRect(x: axScreenFrame.minX, y: axScreenFrame.minY,
                         width: axScreenFrame.width / 2, height: axScreenFrame.height / 2)
        case .topRight:
            return CGRect(x: axScreenFrame.minX + axScreenFrame.width / 2, y: axScreenFrame.minY,
                         width: axScreenFrame.width / 2, height: axScreenFrame.height / 2)
        case .bottomLeft:
            return CGRect(x: axScreenFrame.minX, y: axScreenFrame.minY + axScreenFrame.height / 2,
                         width: axScreenFrame.width / 2, height: axScreenFrame.height / 2)
        case .bottomRight:
            return CGRect(x: axScreenFrame.minX + axScreenFrame.width / 2, y: axScreenFrame.minY + axScreenFrame.height / 2,
                         width: axScreenFrame.width / 2, height: axScreenFrame.height / 2)
        
        // Thirds
        case .leftThird:
            return CGRect(x: axScreenFrame.minX, y: axScreenFrame.minY,
                         width: axScreenFrame.width / 3, height: axScreenFrame.height)
        case .centerThird:
            return CGRect(x: axScreenFrame.minX + axScreenFrame.width / 3, y: axScreenFrame.minY,
                         width: axScreenFrame.width / 3, height: axScreenFrame.height)
        case .rightThird:
            return CGRect(x: axScreenFrame.minX + (axScreenFrame.width * 2 / 3), y: axScreenFrame.minY,
                         width: axScreenFrame.width / 3, height: axScreenFrame.height)
        
        // Two-Thirds
        case .leftTwoThirds:
            return CGRect(x: axScreenFrame.minX, y: axScreenFrame.minY,
                         width: axScreenFrame.width * 2 / 3, height: axScreenFrame.height)
        case .rightTwoThirds:
            return CGRect(x: axScreenFrame.minX + axScreenFrame.width / 3, y: axScreenFrame.minY,
                         width: axScreenFrame.width * 2 / 3, height: axScreenFrame.height)
        
        // Special
        case .maximize:
            return axScreenFrame
        case .center:
            let defaultSize = CGSize(width: min(800, axScreenFrame.width * 0.8), 
                                   height: min(600, axScreenFrame.height * 0.8))
            let centerOrigin = CGPoint(
                x: axScreenFrame.minX + (axScreenFrame.width - defaultSize.width) / 2,
                y: axScreenFrame.minY + (axScreenFrame.height - defaultSize.height) / 2
            )
            return CGRect(origin: centerOrigin, size: defaultSize)
        }
    }
    
    // Move window to AX frame (like Spectacle does)
    private func moveWindowToAXFrame(_ window: WindowInfo, frame: CGRect) {
        guard let axElement = window.axElement else {
            print("ERROR: No AX element for window")
            return
        }
        
        // Set position
        var position = frame.origin
        let positionValue = AXValueCreate(AXValueType.cgPoint, &position)
        let posResult = AXUIElementSetAttributeValue(axElement, kAXPositionAttribute as CFString, positionValue!)
        
        // Set size  
        var size = frame.size
        let sizeValue = AXValueCreate(AXValueType.cgSize, &size)
        let sizeResult = AXUIElementSetAttributeValue(axElement, kAXSizeAttribute as CFString, sizeValue!)
        
        print("AX Position result: \(posResult.rawValue)")
        print("AX Size result: \(sizeResult.rawValue)")
        
        if posResult == .success && sizeResult == .success {
            print("SUCCESS: Window moved to AX frame: \(frame)")
        } else {
            print("ERROR: Failed to set window frame")
        }
    }
    
    func moveWindow(_ window: WindowInfo, to position: CGPoint) {
        guard let axElement = window.axElement else {
            print("ERROR: No AXUIElement reference available for window: \(window.windowTitle)")
            return
        }
        
        // Find which screen the window should be on based on the target position
        guard let targetScreen = ScreenUtils.getScreenContaining(point: position) else {
            print("ERROR: Could not determine target screen for position: \(position)")
            return
        }
        
        print("Moving window to NSScreen position: \(position)")
        print("Target screen: \(targetScreen.frame)")
        
        // CRITICAL FIX: Convert from NSScreen coordinates to Accessibility API coordinates
        let accessibilityPosition = CoordinateConverter.convertToAccessibilityCoordinates(position, on: targetScreen)
        
        print("Converted to Accessibility coordinates: \(accessibilityPosition)")
        
        var mutablePosition = accessibilityPosition
        let positionValue = AXValueCreate(AXValueType.cgPoint, &mutablePosition)
        let result = AXUIElementSetAttributeValue(axElement, kAXPositionAttribute as CFString, positionValue!)
        
        if result != .success {
            print("ERROR: Failed to move window '\(window.windowTitle)' to \(accessibilityPosition), result: \(result.rawValue)")
        } else {
            print("SUCCESS: Set AX position to \(accessibilityPosition)")
            
            // Verify the actual position after moving
            var newPosition: CFTypeRef?
            AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &newPosition)
            if let pos = newPosition {
                var actualPoint = CGPoint.zero
                AXValueGetValue(pos as! AXValue, AXValueType.cgPoint, &actualPoint)
                print("ACTUAL AX position after move: \(actualPoint)")
                
                // Convert back to NSScreen coordinates for comparison
                let actualNSScreenPosition = CoordinateConverter.convertFromAccessibilityCoordinates(actualPoint, on: targetScreen)
                print("ACTUAL NSScreen position: \(actualNSScreenPosition)")
                
                if abs(actualNSScreenPosition.x - position.x) > 10 || abs(actualNSScreenPosition.y - position.y) > 10 {
                    print("WARNING: Window moved to different position than requested!")
                    print("  Requested (NSScreen): \(position)")
                    print("  Actual (NSScreen): \(actualNSScreenPosition)")
                }
            }
        }
    }
    
    func resizeWindow(_ window: WindowInfo, to size: CGSize) {
        guard let axElement = window.axElement else {
            print("Error: No AXUIElement reference available for window: \(window.windowTitle)")
            return
        }
        
        var mutableSize = size
        let sizeValue = AXValueCreate(AXValueType.cgSize, &mutableSize)
        let result = AXUIElementSetAttributeValue(axElement, kAXSizeAttribute as CFString, sizeValue!)
        
        if result != .success {
            print("Error: Failed to resize window '\(window.windowTitle)' to \(size)")
        } else {
            print("Successfully resized window '\(window.windowTitle)' to \(size)")
        }
    }
    
    func getScreenBounds() -> [CGRect] {
        return NSScreen.screens.map { $0.frame }
    }
    
    private func parseWindowInfo(from dict: [String: Any]) -> WindowInfo? {
        guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
              let processID = dict[kCGWindowOwnerPID as String] as? pid_t,
              let boundsDict = dict[kCGWindowBounds as String] as? [String: CGFloat],
              let x = boundsDict["X"],
              let y = boundsDict["Y"],
              let width = boundsDict["Width"],
              let height = boundsDict["Height"] else {
            return nil
        }
        
        let applicationName = dict[kCGWindowOwnerName as String] as? String ?? "Unknown"
        let windowTitle = dict[kCGWindowName as String] as? String ?? ""
        let frame = CGRect(x: x, y: y, width: width, height: height)
        let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? true
        
        return WindowInfo(
            windowID: windowID,
            processID: processID,
            applicationName: applicationName,
            windowTitle: windowTitle,
            frame: frame,
            isOnScreen: isOnScreen
        )
    }
    
    private func getWindowInfo(from axElement: AXUIElement, processID: pid_t, axElement axRef: AXUIElement? = nil) -> WindowInfo? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        var title: CFTypeRef?
        
        AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &position)
        AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &size)
        AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &title)
        
        var point = CGPoint.zero
        var cgSize = CGSize.zero
        
        if let pos = position {
            AXValueGetValue(pos as! AXValue, AXValueType.cgPoint, &point)
        }
        
        if let sz = size {
            AXValueGetValue(sz as! AXValue, AXValueType.cgSize, &cgSize)
        }
        
        let windowTitle = title as? String ?? ""
        let frame = CGRect(origin: point, size: cgSize)
        
        let app = NSRunningApplication(processIdentifier: processID)
        let applicationName = app?.localizedName ?? "Unknown"
        
        // WindowID is not needed for AX-based windows since we use direct element reference
        let windowID: CGWindowID = 0
        
        return WindowInfo(
            windowID: windowID,
            processID: processID,
            applicationName: applicationName,
            windowTitle: windowTitle,
            frame: frame,
            axElement: axRef ?? axElement
        )
    }
    
    private func excludeSystemWindows(_ windows: [WindowInfo]) -> [WindowInfo] {
        let systemApps = ["Dock", "SystemUIServer", "Window Server", "Spotlight"]
        
        return windows.filter { window in
            !systemApps.contains(window.applicationName) &&
            !window.windowTitle.isEmpty &&
            window.frame.width > 100 &&
            window.frame.height > 100
        }
    }
    
    private func getScreenDisplayName(_ screen: NSScreen) -> String {
        let screenIndex = ScreenUtils.getScreenIndex(for: screen) ?? -1
        let isPrimary = screen == NSScreen.main
        let displayName = screen.localizedName
        
        if isPrimary {
            return "Primary (\(displayName))"
        } else {
            return "Display \(screenIndex + 1) (\(displayName))"
        }
    }
}