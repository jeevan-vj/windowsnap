#!/usr/bin/env swift

import Foundation
import AppKit
import ApplicationServices
import Carbon

// Include the required classes inline for the test
// Note: In a real scenario, you would import these from the module

print("Testing WindowSnap Window Detection")
print("=====================================")

// Check accessibility permissions
print("Accessibility permissions:", AccessibilityPermissions.hasPermissions())

if !AccessibilityPermissions.hasPermissions() {
    print("ERROR: Accessibility permissions not granted. Please grant permissions in System Preferences.")
    exit(1)
}

// Get all windows
print("\nDetecting all windows...")
let windows = windowManager.getAllWindows()
print("Found \(windows.count) windows:")

for (index, window) in windows.enumerated() {
    print("\(index + 1). \(window.applicationName): \(window.windowTitle)")
    print("   Frame: \(window.frame)")
    print("   Process ID: \(window.processID)")
    print("")
}

// Get focused window
print("Getting focused window...")
if let focusedWindow = windowManager.getFocusedWindow() {
    print("Focused window: \(focusedWindow.applicationName) - \(focusedWindow.windowTitle)")
    print("Frame: \(focusedWindow.frame)")
} else {
    print("No focused window found")
}

// Get screen bounds
print("\nScreen information:")
let screenBounds = windowManager.getScreenBounds()
for (index, screen) in screenBounds.enumerated() {
    print("Screen \(index + 1): \(screen)")
}

print("\nWindow detection test completed successfully!")