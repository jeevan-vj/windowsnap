# WindowSnap - Spectacle/Rectangle Approach Fix

## Research Findings ✅

After analyzing Spectacle and Rectangle source code, I discovered the **correct approach**:

### **Key Insight from Spectacle**
Spectacle works **entirely in the Accessibility API coordinate system** and only converts when necessary for screen detection. They don't mix coordinate systems like we were doing.

### **Spectacle's Approach**
1. **Get window position using AX API**: `AXUIElementCopyAttributeValue` with `kAXPositionAttribute`
2. **Work in AX coordinates throughout**: All calculations done in top-left origin system
3. **Convert screen bounds to AX**: Convert NSScreen frames to AX coordinate system 
4. **Set window position using AX API**: `AXUIElementSetAttributeValue` with converted coordinates

## Root Cause of Our Issue ❌

**We were mixing coordinate systems:**
1. Getting window position with `CGWindowListCopyWindowInfo` (global display coordinates)
2. Detecting screens using `NSScreen` (bottom-left origin)
3. Setting position with `AXUIElementSetAttributeValue` (top-left origin)
4. Converting between systems incorrectly

## New Implementation ✅

### **1. Pure AX API Window Detection**
```swift
// OLD: Mixed approach (WRONG)
CGWindowListCopyWindowInfo() → NSScreen detection → AX positioning

// NEW: Pure AX approach (CORRECT)
AXUIElementCopyAttributeValue() → AX calculations → AX positioning
```

### **2. Spectacle-Style Coordinate Handling**
```swift
// Get window info directly from AX API
private func getWindowInfoFromAccessibility(axElement: AXUIElement, processID: pid_t) -> WindowInfo? {
    var position: CFTypeRef?
    AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &position)
    // Window frame is now in AX coordinate system (top-left origin)
    let axFrame = CGRect(origin: axPoint, size: axSize)
    return WindowInfo(frame: axFrame, axElement: axElement) // Store AX coordinates
}
```

### **3. Screen Frame Conversion to AX**
```swift
// Convert NSScreen visible frame to AX coordinate system
private func convertNSScreenToAXCoordinates(_ nsFrame: CGRect) -> CGRect {
    let mainScreenHeight = NSScreen.screens[0].frame.height
    let axY = mainScreenHeight - nsFrame.maxY // Y-axis flip
    return CGRect(x: nsFrame.origin.x, y: axY, width: nsFrame.width, height: nsFrame.height)
}
```

### **4. Direct AX Window Positioning**
```swift
// Move window directly in AX coordinate system (like Spectacle)
private func moveWindowToAXFrame(_ window: WindowInfo, frame: CGRect) {
    var position = frame.origin
    let positionValue = AXValueCreate(AXValueType.cgPoint, &position)
    AXUIElementSetAttributeValue(axElement, kAXPositionAttribute as CFString, positionValue!)
    
    var size = frame.size  
    let sizeValue = AXValueCreate(AXValueType.cgSize, &size)
    AXUIElementSetAttributeValue(axElement, kAXSizeAttribute as CFString, sizeValue!)
}
```

## Expected Results ✅

### **Multi-Monitor Behavior:**
- Window on ultrawide display → `⌘⇧←` → Snaps to left half of ultrawide ✅
- Window on portrait display → `⌘⇧←` → Snaps to left half of portrait ✅ 
- Window on primary display → `⌘⇧←` → Snaps to left half of primary ✅

### **Debug Output:**
```
=== WINDOW SNAP (SPECTACLE APPROACH) ===
Window: 'Safari'
Current AX frame: (566.0, 301.0, 400.0, 300.0)
Detected screen: Display 2 (LS49A950U)
Screen visible frame (NSScreen): (-1794.0, 1169.0, 5120.0, 1440.0)
Screen visible frame (AX): (-1794.0, 0.0, 5120.0, 1440.0)
Target AX frame: (-1794.0, 0.0, 2560.0, 1440.0)
AX Position result: 0
AX Size result: 0
SUCCESS: Window moved to AX frame: (-1794.0, 0.0, 2560.0, 1440.0)
```

## Why This Approach Works ✅

1. **Consistent Coordinate System**: Everything works in AX coordinates (top-left origin)
2. **No Mixed APIs**: Uses AX API for both detection and positioning  
3. **Proper Screen Detection**: Converts AX window position back to NSScreen coordinates only for screen detection
4. **Direct Positioning**: Sets window position directly in AX coordinates without conversion errors
5. **Spectacle-Proven**: Uses the same approach as successful apps like Spectacle and Rectangle

## Benefits Over Previous Attempts

1. **Eliminates Coordinate Confusion**: No more mixing NSScreen and AX coordinate systems
2. **Follows Proven Pattern**: Uses the exact approach that works in Spectacle/Rectangle
3. **Simplified Logic**: Cleaner, more understandable code flow
4. **Better Debugging**: Clear separation of coordinate systems
5. **Multi-Monitor Reliability**: Handles complex monitor arrangements correctly

This implementation follows Spectacle's proven architecture and should finally resolve the multi-monitor window positioning issue by working entirely within the Accessibility API coordinate system.