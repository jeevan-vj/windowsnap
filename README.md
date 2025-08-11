# WindowSnap

A native macOS window management application that allows you to quickly arrange application windows using keyboard shortcuts, similar to window management features in Alfred.

## Features

- **Fast Window Positioning**: Snap windows to predefined grid positions using keyboard shortcuts
- **Menu Bar Integration**: Lightweight status bar app with quick actions
- **Multi-Monitor Support**: Works seamlessly across multiple displays
- **Accessibility Compliant**: Uses macOS Accessibility APIs for reliable window management
- **Customizable**: Preferences window for personalization
- **Native Performance**: Built with Swift and AppKit for optimal performance

## Window Positioning Options

### Halves
- **Left Half** (`⌘⇧←`): Position window to left 50% of screen
- **Right Half** (`⌘⇧→`): Position window to right 50% of screen  
- **Top Half** (`⌘⇧↑`): Position window to top 50% of screen
- **Bottom Half** (`⌘⇧↓`): Position window to bottom 50% of screen

### Quarters
- **Top Left** (`⌘⌥1`): Position window to top-left 25% of screen
- **Top Right** (`⌘⌥2`): Position window to top-right 25% of screen
- **Bottom Left** (`⌘⌥3`): Position window to bottom-left 25% of screen
- **Bottom Right** (`⌘⌥4`): Position window to bottom-right 25% of screen

### Thirds
- **Left Third** (`⌘⌥←`): Position window to left 33% of screen
- **Right Third** (`⌘⌥→`): Position window to right 33% of screen

### Two-Thirds
- **Left Two-Thirds** (`⌘⌥↑`): Position window to left 66% of screen
- **Right Two-Thirds** (`⌘⌥↓`): Position window to right 66% of screen

### Special
- **Maximize** (`⌘⇧M`): Fill entire screen (excluding menu bar/dock)
- **Center** (`⌘⇧C`): Center window at original size

## Requirements

- **macOS**: 12.0 (Monterey) or later
- **Architecture**: Intel x64 or Apple Silicon (ARM64)
- **Permissions**: Accessibility access (required)

## Installation

### Option 1: Build from Source

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd windowsnap
   ```

2. **Build the project:**
   ```bash
   cd WindowSnap
   swift build -c release
   ```

3. **Run the application:**
   ```bash
   ./.build/release/WindowSnap
   ```

### Option 2: Xcode

1. Open the `WindowSnap` folder in Xcode
2. Build and run the project
3. The app will appear in your menu bar

## Setup

### 1. Grant Accessibility Permissions

WindowSnap requires accessibility permissions to manage windows:

1. Open **System Preferences** → **Security & Privacy** → **Privacy** → **Accessibility**
2. Click the lock icon and enter your password
3. Click the **"+"** button and add WindowSnap to the list
4. Ensure WindowSnap is checked/enabled

### 2. Launch the Application

- Run WindowSnap (it will appear as an icon in your menu bar)
- The icon looks like a window grid (⊞)
- Right-click the icon to access the context menu

## Usage

### Keyboard Shortcuts

1. **Focus a window** you want to position
2. **Press the keyboard shortcut** for your desired position
3. **The window will snap** to the specified position instantly

### Menu Bar

- **Right-click** the WindowSnap icon in the menu bar
- **Select** a positioning option from the menu
- **Access Preferences** to customize settings

### Multi-Monitor

- WindowSnap automatically detects the screen containing the focused window
- Shortcuts work consistently across all connected displays
- Each monitor's visible area (excluding dock/menu bar) is calculated correctly

## Project Structure

```
WindowSnap/
├── WindowSnap/
│   ├── App/
│   │   ├── AppDelegate.swift         # Application lifecycle
│   │   ├── WindowSnapApp.swift       # Main entry point
│   │   └── Info.plist               # App configuration
│   ├── Core/
│   │   ├── WindowManager.swift       # Window detection & manipulation
│   │   ├── ShortcutManager.swift     # Global keyboard shortcuts
│   │   ├── GridCalculator.swift      # Position calculations
│   │   └── PreferencesManager.swift  # Settings persistence
│   ├── UI/
│   │   ├── StatusBarController.swift # Menu bar interface
│   │   └── PreferencesWindow.swift   # Settings window
│   ├── Models/
│   │   ├── WindowInfo.swift          # Window data structure
│   │   ├── GridPosition.swift        # Position enumerations
│   │   └── ShortcutBinding.swift     # Keyboard shortcut data
│   └── Utils/
│       ├── AccessibilityPermissions.swift  # Permission handling
│       ├── ScreenUtils.swift               # Screen information
│       └── Extensions.swift                # Utility extensions
└── Package.swift                     # Swift Package Manager
```

## Architecture

### Core Components

- **WindowManager**: Handles window detection using Accessibility APIs and CGWindowListCopyWindowInfo
- **GridCalculator**: Calculates precise window frames for different grid positions
- **ShortcutManager**: Registers global keyboard shortcuts using Carbon Event Manager
- **StatusBarController**: Manages the menu bar interface and user interactions

### Key Technologies

- **AppKit**: Native macOS UI framework
- **Accessibility APIs**: For reliable window manipulation
- **Carbon Event Manager**: For global keyboard shortcuts
- **Core Graphics**: For screen and window geometry calculations

## Troubleshooting

### App Won't Start
- Check that you have macOS 12.0 or later
- Ensure accessibility permissions are granted
- Try rebuilding the project

### Shortcuts Not Working
- Verify accessibility permissions in System Preferences
- Check for conflicting keyboard shortcuts in other apps
- Restart WindowSnap after granting permissions

### Windows Not Moving
- Confirm the target application allows window manipulation
- Some apps (like System Preferences) may restrict window changes
- Try with standard apps like Safari, TextEdit, or Finder

### Menu Bar Icon Missing
- WindowSnap runs as a "UI Element" (background app)
- Look for the grid icon (⊞) in your menu bar
- If missing, the app may not have launched properly

## Development

### Building

```bash
# Debug build
swift build

# Release build  
swift build -c release

# Run tests
swift test
```

### Testing

```bash
# Test basic functionality
swift test_simple.swift

# Test window detection
swift -I .build/debug test_windows.swift
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on different macOS versions
5. Submit a pull request

## Technical Notes

### Accessibility APIs

WindowSnap uses both CGWindowListCopyWindowInfo for window enumeration and AX APIs for manipulation:

```swift
// Window detection
CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)

// Window manipulation  
AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute, positionValue)
```

### Multi-Monitor Calculations

Screen coordinates are handled using NSScreen.visibleFrame to exclude dock and menu bar areas:

```swift
let workingArea = screen.visibleFrame  // Excludes dock/menu bar
let targetFrame = calculatePosition(for: .leftHalf, on: workingArea)
```

### Global Shortcuts

Keyboard shortcuts are registered using Carbon Event Manager for system-wide access:

```swift
RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
```

## License

Copyright © 2025 WindowSnap. All rights reserved.

## Version History

- **v1.0** - Initial release with core window management functionality

---

*Built with ❤️ using Swift and AppKit*