# WindowSnap v1.0 - Release Notes

## 🎉 Initial Release

We're excited to announce the first release of **WindowSnap** - a powerful, native macOS window management application that brings lightning-fast window organization to your workflow.

## ✨ What's New

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

### User Experience
- **Menu bar integration** - Lightweight status bar app with intuitive interface
- **Accessibility compliant** - Uses macOS Accessibility APIs for reliable window management
- **Smart screen detection** - Automatically works with the screen containing the focused window
- **Visual feedback** - Clear menu options and responsive interactions

### Advanced Features
- **Sleep/wake recovery** - Robust handling of system sleep/wake cycles with automatic reinitialization
- **Health monitoring** - Built-in health checks to ensure managers stay responsive
- **Accessibility permissions** - Smart permission checking without unnecessary prompts
- **Undo/redo functionality** - Easily revert window position changes
- **Display switching** - Seamless window management across multiple monitors
- **Incremental resizing** - Fine-tune window sizes with precision controls

## 🔧 Technical Highlights

### Architecture
- **Native Swift implementation** for optimal performance
- **AppKit foundation** ensuring deep macOS integration
- **Modular design** with separate managers for different responsibilities
- **Carbon Event Manager** for global keyboard shortcuts
- **Core Graphics** for precise screen and window calculations

### Reliability Features
- **Robust error handling** throughout the application
- **Automatic recovery** from system events and permission changes
- **Memory efficient** with minimal system resource usage
- **Thread-safe operations** for stable multi-threaded execution

## 📋 System Requirements

- **macOS 12.0 (Monterey)** or later
- **Intel x64** or **Apple Silicon (ARM64)** architecture
- **Accessibility permissions** (required for window management)

## 🚀 Installation

### Download & Install
1. Download `WindowSnap.zip` from the release assets
2. Unzip and move `WindowSnap.app` to your Applications folder
3. Launch WindowSnap - it will appear in your menu bar
4. Grant Accessibility permissions when prompted

### Build from Source
```bash
git clone <repository-url>
cd windowsnap/WindowSnap
swift build -c release
./.build/release/WindowSnap
```

## ⚙️ Setup

1. **Launch WindowSnap** - Look for the grid icon (⊞) in your menu bar
2. **Grant Accessibility Permissions:**
   - Open System Preferences → Security & Privacy → Privacy → Accessibility
   - Add WindowSnap to the list and ensure it's enabled
3. **Start using shortcuts** - Focus any window and use the keyboard shortcuts

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

Built with ❤️ using Swift and AppKit. Special thanks to the macOS developer community for inspiration and guidance.

## 📞 Support

- **Issues**: Report bugs or request features on our GitHub repository
- **Documentation**: Complete setup and usage guide available in README.md
- **Compatibility**: Tested on macOS Monterey, Ventura, and Sonoma

---

**Version**: 1.0  
**Build**: 20250813093234  
**Release Date**: August 2025  
**Copyright**: © 2025 WindowSnap. All rights reserved.