# WindowSnap v1.1.0 - Release Notes

## 🚀 Launch at Login Feature Release

We're excited to announce **WindowSnap v1.1.0**, featuring the highly requested **Launch at Login** functionality with intelligent user prompting and seamless system integration.

## ✨ What's New in v1.1.0

### 🔄 Launch at Login Support
- **Automatic startup** when your Mac boots up or when you log in
- **Smart first-run prompt** - Friendly dialog asks users if they want to enable auto-start
- **User choice respected** - One-time prompt with clear options and confirmations
- **Manual configuration** - Always changeable later through Preferences
- **Cross-version compatibility** - Modern `SMAppService` (macOS 13+) with legacy fallback

### 🎯 Enhanced User Experience
- **Intelligent timing** - Prompt appears 1.5 seconds after app startup for full initialization
- **Clear options**: 
  - "Yes, Start Automatically" - Enables launch at login immediately
  - "No, Don't Auto-Start" - Respects user choice with confirmation
  - "Decide Later" - Provides guidance on accessing preferences
- **Preferences integration** - Easy toggle in General tab: "Launch WindowSnap at login"

### 🛠 Technical Improvements
- **Robust error handling** for launch service registration
- **Preference synchronization** between system and app settings
- **Apple-recommended APIs** for reliable functionality
- **Automatic macOS version detection** for optimal compatibility

## 🔧 Architecture Enhancements

### New Components
- **LaunchAtLoginManager** (`WindowSnap/Utils/LaunchAtLoginManager.swift`)
  - Cross-platform launch service management
  - Error handling and preference sync
  - Modern and legacy API support

- **LaunchAtLoginPrompt** (`WindowSnap/Utils/LaunchAtLoginPrompt.swift`)
  - First-run user experience
  - Smart detection and user interaction tracking
  - Direct preferences access integration

### Compatibility
- **macOS 13+**: Uses modern `SMAppService` framework
- **macOS 12**: Uses legacy `SMLoginItemSetEnabled` API
- **Backward compatible** with all existing functionality

## 📋 System Requirements

- **macOS 12.0 (Monterey)** or later
- **Intel x64** or **Apple Silicon (ARM64)** architecture
- **Accessibility permissions** (required for window management)

## 🚀 Installation & Upgrade

### New Installation
1. Download `WindowSnap.zip` from the release assets
2. Unzip and move `WindowSnap.app` to your Applications folder
3. Launch WindowSnap - it will appear in your menu bar
4. Grant Accessibility permissions when prompted
5. Choose your auto-start preference in the first-run prompt

### Upgrading from v1.0.0
1. Download the new version and replace your existing app
2. Launch WindowSnap - existing settings will be preserved
3. You'll see the launch at login prompt on first run with the new version

## ⚙️ Using Launch at Login

### First-Time Setup
When you launch WindowSnap v1.1.0 for the first time, you'll see a friendly prompt asking about auto-start preferences. Make your choice and WindowSnap will remember it.

### Changing Settings Later
1. Click the WindowSnap icon (⊞) in your menu bar
2. Select "Preferences"
3. In the General tab, toggle "Launch WindowSnap at login"

## 📖 All Features (v1.1.0)

### Core Window Management
- **Lightning-fast window positioning** with global keyboard shortcuts
- **8 positioning options** including halves, quarters, thirds, and two-thirds
- **Special actions** for maximize and center window operations
- **Multi-monitor support** with automatic screen detection
- **Native performance** built with Swift and AppKit

### Keyboard Shortcuts
**Halves:**
- `⌘⇧←` Left Half
- `⌘⇧→` Right Half  
- `⌘⇧↑` Top Half
- `⌘⇧↓` Bottom Half

**Quarters:**
- `⌘⌥1` Top Left
- `⌘⌥2` Top Right
- `⌘⌥3` Bottom Left
- `⌘⌥4` Bottom Right

**Thirds:**
- `⌘⌥←` Left Third
- `⌘⌥→` Right Third

**Two-Thirds:**
- `⌘⌥↑` Left Two-Thirds
- `⌘⌥↓` Right Two-Thirds

**Special:**
- `⌘⇧M` Maximize
- `⌘⇧C` Center

### Advanced Features
- **Launch at login** - NEW! Automatic startup with user choice
- **Sleep/wake recovery** - Robust handling of system sleep/wake cycles
- **Health monitoring** - Built-in health checks to ensure managers stay responsive
- **Accessibility permissions** - Smart permission checking without unnecessary prompts
- **Undo/redo functionality** - Easily revert window position changes
- **Display switching** - Seamless window management across multiple monitors

## 🐛 Known Issues

- Some applications (like System Preferences) may restrict window manipulation
- First launch requires manual accessibility permission grant
- Menu bar icon may not appear immediately on some systems

## 🔮 What's Next

Future releases will include:
- Custom grid size preferences
- Additional positioning options
- Improved visual feedback
- Auto-update functionality
- Localization support

## 🙏 Acknowledgments

Built with ❤️ using Swift and AppKit. Special thanks to the community for feature requests and feedback that led to this launch at login implementation.

## 📞 Support

- **Issues**: Report bugs or request features on our GitHub repository
- **Documentation**: Complete setup and usage guide available in README.md
- **Compatibility**: Tested on macOS Monterey, Ventura, and Sonoma

---

**Version**: 1.1.0  
**Build**: 20250829180000  
**Release Date**: August 29, 2025  
**Copyright**: © 2025 WindowSnap. All rights reserved.
