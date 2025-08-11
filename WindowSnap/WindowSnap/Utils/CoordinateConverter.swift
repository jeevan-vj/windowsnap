import Foundation
import AppKit
import CoreGraphics

class CoordinateConverter {
    
    /// Convert from NSScreen coordinates (bottom-left origin) to Accessibility API coordinates (top-left origin)
    static func convertToAccessibilityCoordinates(_ point: CGPoint, on screen: NSScreen) -> CGPoint {
        let screenFrame = screen.frame
        
        // NSScreen uses bottom-left origin, AX API uses top-left origin
        // Y needs to be flipped within the screen bounds
        let convertedY = screenFrame.maxY - point.y
        
        return CGPoint(x: point.x, y: convertedY)
    }
    
    /// Convert from NSScreen coordinates (bottom-left origin) to Accessibility API coordinates (top-left origin)
    static func convertRectToAccessibilityCoordinates(_ rect: CGRect, on screen: NSScreen) -> CGRect {
        let screenFrame = screen.frame
        
        // Convert the origin point
        let convertedOrigin = convertToAccessibilityCoordinates(rect.origin, on: screen)
        
        // For rectangles, we also need to account for the height of the rect
        // because the origin moves from bottom-left to top-left
        let adjustedY = convertedOrigin.y - rect.height
        
        return CGRect(
            x: rect.origin.x,
            y: adjustedY,
            width: rect.width,
            height: rect.height
        )
    }
    
    /// Convert from Accessibility API coordinates (top-left origin) to NSScreen coordinates (bottom-left origin)  
    static func convertFromAccessibilityCoordinates(_ point: CGPoint, on screen: NSScreen) -> CGPoint {
        let screenFrame = screen.frame
        
        // AX API uses top-left origin, NSScreen uses bottom-left origin
        let convertedY = screenFrame.maxY - point.y
        
        return CGPoint(x: point.x, y: convertedY)
    }
    
    /// Get the primary screen (contains menu bar)
    static func getPrimaryScreen() -> NSScreen {
        return NSScreen.main ?? NSScreen.screens[0]
    }
    
    /// Convert coordinates from one screen's coordinate system to global coordinates
    static func convertToGlobalCoordinates(_ point: CGPoint, from screen: NSScreen) -> CGPoint {
        let screenFrame = screen.frame
        return CGPoint(
            x: screenFrame.origin.x + point.x,
            y: screenFrame.origin.y + point.y
        )
    }
    
    /// Debug method to print coordinate system information
    static func debugCoordinateSystems(window: CGRect, screen: NSScreen) {
        print("=== COORDINATE SYSTEM DEBUG ===")
        print("Screen frame: \(screen.frame)")
        print("Screen visible frame: \(screen.visibleFrame)")
        print("Window frame (current): \(window)")
        
        let windowCenter = CGPoint(x: window.midX, y: window.midY)
        print("Window center (NSScreen coords): \(windowCenter)")
        
        let axCoords = convertToAccessibilityCoordinates(window.origin, on: screen)
        print("Window origin (AX coords): \(axCoords)")
        
        let axRect = convertRectToAccessibilityCoordinates(window, on: screen)
        print("Window rect (AX coords): \(axRect)")
        print("=== END COORDINATE DEBUG ===")
    }
    
    /// Check if a point is valid for the given screen
    static func isPointOnScreen(_ point: CGPoint, screen: NSScreen) -> Bool {
        return screen.frame.contains(point)
    }
    
    /// Get screen bounds in accessibility coordinates
    static func getScreenBoundsInAccessibilityCoordinates(_ screen: NSScreen) -> CGRect {
        let frame = screen.frame
        
        return CGRect(
            x: frame.origin.x,
            y: 0, // In AX coordinates, Y starts at 0 for the topmost screen
            width: frame.width,
            height: frame.height
        )
    }
}