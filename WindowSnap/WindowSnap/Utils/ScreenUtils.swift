import Foundation
import AppKit

class ScreenUtils {
    
    static func getMainScreen() -> NSScreen? {
        return NSScreen.main
    }
    
    static func getAllScreens() -> [NSScreen] {
        return NSScreen.screens
    }
    
    static func getScreenContaining(point: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main
    }
    
    static func getScreenContaining(rect: CGRect) -> NSScreen? {
        let centerPoint = CGPoint(x: rect.midX, y: rect.midY)
        return getScreenContaining(point: centerPoint)
    }
    
    static func getScreenContaining(window: CGRect) -> NSScreen? {
        // First try to find screen that contains the window center
        let centerPoint = CGPoint(x: window.midX, y: window.midY)
        if let screen = getScreenContaining(point: centerPoint) {
            return screen
        }
        
        // If center is not on any screen, find screen with most overlap
        var bestScreen: NSScreen?
        var maxOverlapArea: CGFloat = 0
        
        for screen in NSScreen.screens {
            let intersection = window.intersection(screen.frame)
            let overlapArea = intersection.width * intersection.height
            
            if overlapArea > maxOverlapArea {
                maxOverlapArea = overlapArea
                bestScreen = screen
            }
        }
        
        return bestScreen ?? NSScreen.main
    }
    
    static func getAllScreensInfo() -> [(screen: NSScreen, index: Int, isPrimary: Bool)] {
        return NSScreen.screens.enumerated().map { (index, screen) in
            (screen: screen, index: index, isPrimary: screen == NSScreen.main)
        }
    }
    
    static func getScreenIndex(for screen: NSScreen) -> Int? {
        return NSScreen.screens.firstIndex(of: screen)
    }
    
    static func getVisibleFrame(for screen: NSScreen) -> CGRect {
        return screen.visibleFrame
    }
    
    static func convertFromScreenCoordinates(_ point: CGPoint, for screen: NSScreen) -> CGPoint {
        let screenFrame = screen.frame
        return CGPoint(
            x: point.x,
            y: screenFrame.height - point.y
        )
    }
    
    static func convertToScreenCoordinates(_ point: CGPoint, for screen: NSScreen) -> CGPoint {
        let screenFrame = screen.frame
        return CGPoint(
            x: point.x,
            y: screenFrame.height - point.y
        )
    }
    
    static func isPointOnAnyScreen(_ point: CGPoint) -> Bool {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return true
            }
        }
        return false
    }
    
    static func getScreenInfo() -> String {
        var info = "Screen Configuration:\n"
        for (index, screen) in NSScreen.screens.enumerated() {
            info += "Screen \(index + 1): \(screen.frame), Visible: \(screen.visibleFrame)\n"
        }
        return info
    }
}