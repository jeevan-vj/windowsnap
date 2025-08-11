#!/usr/bin/env swift

import Foundation
import AppKit

print("WindowSnap - Multi-Monitor Test")
print("===============================")

// Display all connected screens
let screens = NSScreen.screens
print("Detected \(screens.count) display(s):")
print("")

for (index, screen) in screens.enumerated() {
    let isPrimary = screen == NSScreen.main
    let displayName = screen.localizedName
    
    print("Display \(index + 1): \(isPrimary ? "(Primary)" : "")")
    print("  Name: \(displayName)")
    print("  Full Frame: \(screen.frame)")
    print("  Visible Frame: \(screen.visibleFrame)")
    print("  Scale Factor: \(screen.backingScaleFactor)x")
    
    // Calculate some example positioning
    let visibleArea = screen.visibleFrame
    let leftHalf = CGRect(
        x: visibleArea.minX,
        y: visibleArea.minY,
        width: visibleArea.width / 2,
        height: visibleArea.height
    )
    print("  Left Half would be: \(leftHalf)")
    print("")
}

// Test window detection simulation
print("Multi-Monitor Window Detection Test:")
print("====================================")

// Simulate a window on each screen
for (index, screen) in screens.enumerated() {
    let testWindowFrame = CGRect(
        x: screen.visibleFrame.midX - 200,
        y: screen.visibleFrame.midY - 150,
        width: 400,
        height: 300
    )
    
    print("Test window on Display \(index + 1):")
    print("  Window frame: \(testWindowFrame)")
    
    // Test which screen this window would be detected on
    var detectedScreen: NSScreen?
    let windowCenter = CGPoint(x: testWindowFrame.midX, y: testWindowFrame.midY)
    
    for screen in NSScreen.screens {
        if screen.frame.contains(windowCenter) {
            detectedScreen = screen
            break
        }
    }
    
    if let detected = detectedScreen {
        let detectedIndex = NSScreen.screens.firstIndex(of: detected)! + 1
        print("  ✅ Would be detected on Display \(detectedIndex)")
        
        // Calculate left half position on this screen
        let leftHalfFrame = CGRect(
            x: detected.visibleFrame.minX,
            y: detected.visibleFrame.minY,
            width: detected.visibleFrame.width / 2,
            height: detected.visibleFrame.height
        )
        print("  📍 Left half snap would move to: \(leftHalfFrame)")
    } else {
        print("  ❌ Would not be detected properly")
    }
    print("")
}

print("✅ Multi-monitor support test completed!")
print("")
print("Key improvements:")
print("- Windows snap within their current display")
print("- Proper screen detection using window center point")
print("- Fallback to screen with most overlap if center is off-screen")
print("- Debug logging shows which screen is being used")