# WindowSnap

A native macOS window management application that allows you to quickly arrange application windows using keyboard shortcuts, similar to window management features in Alfred.

## Features

- **Fast Window Positioning**: Snap windows to predefined grid positions using keyboard shortcuts
- **Launch at Login**: Smart auto-start with first-run prompt and user choice respect
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

### Download Pre-Built App

**⚠️ Important: First-Time Opening on macOS**

When you first open WindowSnap, macOS may show a security warning:
> "WindowSnap.app" cannot be opened because Apple cannot verify it is free of malware.

This happens because the app isn't notarized by Apple. **The app is safe** - it's just not signed with an Apple Developer certificate ($99/year).

**To open the app, use ONE of these methods:**

**Method 1 - Right-Click Open (Easiest):**
1. Right-click (or Control+click) on `WindowSnap.app`
2. Select **"Open"** from the menu
3. Click **"Open"** in the confirmation dialog
4. macOS will remember this choice

**Method 2 - Remove Quarantine Flag:**
```bash
xattr -d com.apple.quarantine /Applications/WindowSnap.app
```

**Method 3 - System Settings (macOS Ventura+):**
1. Try to open the app (it will be blocked)
2. Go to **System Settings** → **Privacy & Security**
3. Scroll to see "WindowSnap was blocked"
4. Click **"Open Anyway"**

---

### Option 1: Build from Source (Recommended)

Building from source ensures you trust the code:

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd windowsnap
   ```

2. **Build the app bundle:**
   ```bash
   cd WindowSnap
   bash scripts/build_bundle.sh
   ```

3. **Install to Applications:**
   ```bash
   cp -R dist/WindowSnap.app /Applications/
   ```

4. **Launch:**
   ```bash
   open /Applications/WindowSnap.app
   ```

### Option 2: Xcode

1. Open `WindowSnap/Package.swift` in Xcode
2. Build and run the project (⌘R)
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
cd WindowSnap

# Unit tests (clipboard filter logic, previews, sorting)
swift test

# Run app in bundle context for UI verification
bash scripts/quick-run.sh

# Manual clipboard history smoke test
bash ../test_clipboard_history.sh
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

- **v1.1.0** - Launch at Login feature with smart user prompting and system integration
- **v1.0** - Initial release with core window management functionality

---

*Built with ❤️ using Swift and AppKit*

## Distribution

### For Developers: Signing & Notarization

To eliminate the security warning for users, you need to **code sign** and **notarize** your app with Apple:

**Quick Start:**
```bash
# 1. Set your Apple Developer credentials
export CODESIGN_ID="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="your-notary-profile"

# 2. Build and sign
cd WindowSnap
bash scripts/build_bundle.sh

# 3. Notarize (removes user warnings)
bash scripts/sign-and-notarize.sh
```

**📖 For complete instructions, see:** [DISTRIBUTION_GUIDE.md](DISTRIBUTION_GUIDE.md)

The guide covers:
- Getting Apple Developer certificate
- Setting up notarization
- Automated signing with GitHub Actions
- Cost-free alternatives (Homebrew, build from source)

### Quick Distribution (Without Signing)

For testing or personal use:

```bash
cd WindowSnap
bash scripts/distribute.sh
```

This creates:
- `dist/WindowSnap.app` - Application bundle
- `dist/WindowSnap.dmg` - Disk image
- `dist/WindowSnap.zip` - Zip archive
- `dist/install.sh` - Installation script
- `dist/README.txt` - User instructions (includes workarounds)

**Note:** Users will need to use the right-click method to open the app.

## Future Improvements
- Migrate deprecated `NSUserNotification` to `UNUserNotificationCenter` or custom HUD.
- Add tests for coordinate conversion & multi-monitor snapping.
- Provide localization for menu items.
- Add preferences for custom grid sizes.
