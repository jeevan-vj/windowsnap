# Multi-Monitor Support in WindowSnap

WindowSnap now provides enhanced multi-monitor support, ensuring that windows snap within their current display rather than always moving to the primary screen.

## How It Works

### Screen Detection Algorithm

1. **Center Point Detection**: WindowSnap first identifies which screen contains the window's center point
2. **Overlap Calculation**: If the center point is off-screen (e.g., window spans multiple displays), it finds the screen with the maximum window overlap
3. **Fallback**: If no overlap is found, it defaults to the primary screen

### Smart Window Positioning

- **Stay on Current Display**: Windows always snap within their current display boundaries
- **Respect Display Boundaries**: Each display's visible area (excluding dock/menu bar) is calculated separately
- **Multi-Resolution Support**: Works with displays of different resolutions and scaling factors

## Example Scenarios

### Scenario 1: Window on Secondary Display
```
Display 1 (Primary): 1800x1169 at (0, 0)
Display 2: 5120x1440 at (-1794, 1169)

Window on Display 2 at (566, 1739)
→ Left Half: Snaps to (-1794, 1169) with size (2560, 1440)
→ Stays on Display 2, doesn't move to Display 1
```

### Scenario 2: Window on Vertical Display
```
Display 3 (Vertical): 1080x1920 at (3326, 513)

Window on Display 3 at (3666, 1323)
→ Left Half: Snaps to (3326, 513) with size (540, 1920)
→ Correctly handles portrait orientation
```

## Technical Implementation

### Enhanced Screen Detection
```swift
static func getScreenContaining(window: CGRect) -> NSScreen? {
    // Try center point first
    let centerPoint = CGPoint(x: window.midX, y: window.midY)
    if let screen = getScreenContaining(point: centerPoint) {
        return screen
    }
    
    // Find screen with most overlap
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
```

### Improved Window Snapping
```swift
func snapWindow(_ window: WindowInfo, to position: GridPosition) {
    // Find the screen that contains this window
    guard let containingScreen = ScreenUtils.getScreenContaining(window: window.frame) else {
        return
    }
    
    // Calculate target frame on the window's current screen
    guard let targetFrame = calculator.calculateFrame(for: position, on: containingScreen.visibleFrame) else {
        return
    }
    
    // Move and resize within the same display
    moveWindow(window, to: targetFrame.origin)
    resizeWindow(window, to: targetFrame.size)
}
```

## Debug Information

When debug logging is enabled, WindowSnap provides detailed information about multi-monitor operations:

```
Snapping window 'Safari' to Left Half
Current screen: Display 2 (LS49A950U) - (-1794.0, 1169.0, 5120.0, 1440.0)
Target frame: (-1794.0, 1169.0, 2560.0, 1440.0)
GridCalculator: Calculating Left Half
  Working area: (-1794.0, 1169.0, 5120.0, 1440.0)
```

## Benefits

1. **Intuitive Behavior**: Windows stay on their current display, matching user expectations
2. **Multi-Resolution Support**: Works correctly with displays of different sizes and orientations
3. **Edge Case Handling**: Properly handles windows that span multiple displays
4. **Performance**: Efficient screen detection with minimal overhead
5. **Debugging**: Comprehensive logging for troubleshooting display issues

## Tested Configurations

- ✅ Primary display + ultrawide secondary display
- ✅ Portrait-oriented displays
- ✅ Mixed resolution setups (Retina + non-Retina)
- ✅ Three+ monitor configurations
- ✅ Windows spanning multiple displays

## Usage Notes

- No changes to keyboard shortcuts - they work the same on all displays
- Menu bar actions respect the currently focused window's display
- Preferences and settings apply consistently across all displays
- Works with both mirrored and extended display modes

This enhancement makes WindowSnap much more usable in multi-monitor setups, providing a seamless window management experience across all connected displays.