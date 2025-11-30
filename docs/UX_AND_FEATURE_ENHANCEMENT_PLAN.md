# WindowSnap UX & Feature Enhancement Plan
## Making WindowSnap a Best-Loved Mac App

**Date:** November 2025  
**Version:** Analysis for v2.0

---

## Executive Summary

WindowSnap already has an impressive feature set rivaling Rectangle Pro. To become a **best-loved Mac app**, it needs to focus on three pillars:

1. **Delight** - Visual polish, animations, and thoughtful micro-interactions
2. **Discoverability** - Making features accessible without reading documentation
3. **Reliability** - Rock-solid performance and seamless system integration

---

## 🎯 Priority 1: Critical UX Improvements

### 1.1 Visual Feedback During Window Snapping

**Problem:** Users have no visual confirmation that snapping is happening.

**Solution:** Add a brief overlay animation showing the target zone.

```swift
// New file: WindowSnap/UI/SnapPreviewOverlay.swift
class SnapPreviewOverlay: NSWindow {
    func show(for position: GridPosition, on screen: NSScreen) {
        // Show translucent colored preview of where window will snap
        // Fade in quickly (0.1s), hold briefly (0.15s), fade out (0.1s)
        // Use accent color gradient with rounded corners
    }
}
```

**Visual spec:**
- 🎨 Use system accent color at 30% opacity
- 📐 Show rounded rect matching target frame
- ⚡ Total animation: 250ms (imperceptible delay, clear feedback)

---

### 1.2 Modern Preferences Window

**Problem:** Current preferences window is basic and dated.

**Solution:** Complete redesign with SwiftUI-style aesthetic.

```
┌─────────────────────────────────────────────────────────────┐
│  WindowSnap Preferences                              ⊗ ⊖ ⊕  │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌────────────────────────────────────────────┐  │
│ │ General │ │  🚀 Startup                                │  │
│ │ Shortcuts│ │  ┌──────────────────────────────────────┐ │  │
│ │ Appearance│ │  │ [✓] Launch WindowSnap at login     │ │  │
│ │ Advanced │ │  └──────────────────────────────────────┘ │  │
│ └─────────┘ │                                            │  │
│             │  🔔 Notifications                          │  │
│             │  ┌──────────────────────────────────────┐  │  │
│             │  │ [✓] Show when windows are snapped   │  │  │
│             │  │ [✓] Play haptic feedback (trackpad) │  │  │
│             │  └──────────────────────────────────────┘  │  │
│             │                                            │  │
│             │  🔐 Accessibility                          │  │
│             │  ┌──────────────────────────────────────┐  │  │
│             │  │ ● Status: ✓ Granted                 │  │  │
│             │  │   [ Open System Settings ]          │  │  │
│             │  └──────────────────────────────────────┘  │  │
│             └────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Features:**
- Sidebar navigation with SF Symbols
- Visual section grouping
- In-line shortcut recording
- Live preview of changes

---

### 1.3 Migrate from Deprecated NSUserNotification

**Problem:** `NSUserNotification` is deprecated since macOS 10.14.

**Solution:** Use custom HUD notification (better UX anyway).

```swift
// New file: WindowSnap/UI/SnapHUD.swift
class SnapHUD: NSWindow {
    // Beautiful floating HUD that shows:
    // - Grid position icon
    // - Position name
    // - Keyboard shortcut reminder
    // Auto-dismisses after 1 second
    // Positioned at screen center-bottom
}
```

**Design:**
```
    ┌────────────────────────┐
    │   ⬛⬜   Left Half     │
    │        ⌘⇧←            │
    └────────────────────────┘
```

---

### 1.4 Onboarding Experience

**Problem:** New users don't know about all features.

**Solution:** First-launch onboarding flow.

```
┌─────────────────────────────────────────────┐
│           Welcome to WindowSnap             │
│                                             │
│     ┌─────────────────────────────────┐    │
│     │                                 │    │
│     │   [Animation showing window     │    │
│     │    snapping in action]          │    │
│     │                                 │    │
│     └─────────────────────────────────┘    │
│                                             │
│  Organize your windows with simple          │
│  keyboard shortcuts.                        │
│                                             │
│     ● ● ○ ○ ○                               │
│                                             │
│  [ Skip ]              [ Get Started → ]    │
└─────────────────────────────────────────────┘
```

**Flow:**
1. Welcome + value proposition
2. Grant accessibility permission (guided)
3. Try your first snap (interactive)
4. Learn about advanced features
5. Set launch at login preference

---

## 🎯 Priority 2: Feature Enhancements

### 2.1 Drag-to-Edge Snapping

**Problem:** Users expect to drag windows to screen edges to snap.

**Solution:** Add hot corners/edges like native macOS + Rectangle.

```swift
// New file: WindowSnap/Core/DragSnapController.swift
class DragSnapController {
    // Monitor window drag events
    // Show preview overlay when window approaches edge
    // Snap zones:
    //   - Left/Right edges → half
    //   - Corners → quarters
    //   - Top center → maximize
    //   - Double-tap top edge → cycle through sizes
}
```

**Hot zones:**
```
┌─────────┬─────────┬─────────┐
│ Top-L   │   Max   │  Top-R  │
│ Quarter │         │ Quarter │
├─────────┤         ├─────────┤
│         │         │         │
│  Left   │         │  Right  │
│  Half   │         │  Half   │
│         │         │         │
├─────────┤         ├─────────┤
│ Bot-L   │         │  Bot-R  │
│ Quarter │         │ Quarter │
└─────────┴─────────┴─────────┘
```

---

### 2.2 Customizable Keyboard Shortcuts

**Problem:** Users can't customize shortcuts from the UI.

**Solution:** Interactive shortcut recording in preferences.

```
┌───────────────────────────────────────────────────────────┐
│  Keyboard Shortcuts                                       │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  Position          Current         Action                 │
│  ────────────────────────────────────────────────────     │
│  Left Half         ⌘⇧←            [ Record ]  [ Reset ]  │
│  Right Half        ⌘⇧→            [ Record ]  [ Reset ]  │
│  Top Half          ⌘⇧↑            [ Record ]  [ Reset ]  │
│  Bottom Half       ⌘⇧↓            [ Record ]  [ Reset ]  │
│  ─────────────────────────────────────────────────────    │
│  Top Left          ⌘⌥1            [ Record ]  [ Reset ]  │
│  ...                                                      │
│                                                           │
│  [ Reset All to Defaults ]    [ Import ]  [ Export ]      │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

**Features:**
- Conflict detection (warn if shortcut used elsewhere)
- Import/export shortcut profiles
- Preset profiles (Spectacle, Rectangle, BetterSnapTool)

---

### 2.3 Window Gaps/Padding

**Problem:** Users may want gaps between snapped windows.

**Solution:** Configurable window padding.

```swift
// Add to PreferencesManager.swift
var windowPadding: CGFloat {
    get { CGFloat(userDefaults.double(forKey: "WindowPadding")) }
    set { userDefaults.set(Double(newValue), forKey: "WindowPadding") }
}

var screenEdgePadding: CGFloat {
    get { CGFloat(userDefaults.double(forKey: "ScreenEdgePadding")) }
    set { userDefaults.set(Double(newValue), forKey: "ScreenEdgePadding") }
}
```

**UI:**
```
┌───────────────────────────────────────────┐
│  Window Gaps                              │
│                                           │
│  Gap between windows:    [====|====] 8px  │
│                                           │
│  Screen edge padding:    [===|=====] 4px  │
│                                           │
│  Preview:                                 │
│  ┌──────────────────────────────────────┐ │
│  │ ┌─────────┐  ┌─────────┐            │ │
│  │ │         │  │         │            │ │
│  │ │  Left   │  │  Right  │            │ │
│  │ │  Half   │  │  Half   │            │ │
│  │ │         │  │         │            │ │
│  │ └─────────┘  └─────────┘            │ │
│  └──────────────────────────────────────┘ │
└───────────────────────────────────────────┘
```

---

### 2.4 Quick Shortcut Reference (Cheat Sheet)

**Problem:** Users forget shortcuts.

**Solution:** Keyboard shortcut overlay accessible via `⌘⇧/`.

```
┌───────────────────────────────────────────────────────────────────┐
│                     WindowSnap Shortcuts                          │
│                                                                   │
│  ┌─────────────────────┐  ┌─────────────────────┐                │
│  │      HALVES         │  │     QUARTERS        │                │
│  │  ⌘⇧←  Left Half    │  │  ⌘⌥1  Top Left     │                │
│  │  ⌘⇧→  Right Half   │  │  ⌘⌥2  Top Right    │                │
│  │  ⌘⇧↑  Top Half     │  │  ⌘⌥3  Bottom Left  │                │
│  │  ⌘⇧↓  Bottom Half  │  │  ⌘⌥4  Bottom Right │                │
│  └─────────────────────┘  └─────────────────────┘                │
│                                                                   │
│  ┌─────────────────────┐  ┌─────────────────────┐                │
│  │      THIRDS         │  │     SPECIAL         │                │
│  │  ⌘⌥←  Left Third   │  │  ⌘⇧M  Maximize     │                │
│  │  ⌘⌥→  Right Third  │  │  ⌘⇧C  Center       │                │
│  │  ⌘⌥↑  Left 2/3     │  │  ⌘⌥Z  Undo         │                │
│  │  ⌘⌥↓  Right 2/3    │  │  ⌘⌥⇧Z Redo        │                │
│  └─────────────────────┘  └─────────────────────┘                │
│                                                                   │
│                    Press any key to close                         │
└───────────────────────────────────────────────────────────────────┘
```

---

### 2.5 App-Specific Rules

**Problem:** Some apps need different behavior (always center, always maximize, etc.)

**Solution:** Per-app position rules.

```
┌───────────────────────────────────────────────────────────┐
│  App-Specific Rules                                       │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌────────┬──────────────────┬──────────────────────────┐ │
│  │  Icon  │  Application     │  Default Position        │ │
│  ├────────┼──────────────────┼──────────────────────────┤ │
│  │  🗓️    │  Calendar        │  Maximize                │ │
│  │  💬    │  Messages        │  Right Third             │ │
│  │  📺    │  Music           │  Bottom Right Quarter    │ │
│  │  📝    │  Notes           │  Left Third              │ │
│  └────────┴──────────────────┴──────────────────────────┘ │
│                                                           │
│  [ + Add Rule ]    [ - Remove ]    [ Edit ]               │
│                                                           │
│  Options:                                                 │
│  [✓] Apply rule when app launches                        │
│  [ ] Apply rule when switching to app                    │
│  [✓] Ignore rule if window was manually positioned       │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

### 2.6 Restore Previous Position

**Problem:** After snapping, users can't easily restore original position.

**Solution:** "Restore" shortcut (`⌘⌥⇧R`) returns window to pre-snap state.

```swift
// Enhance WindowActionHistory.swift
func getOriginalState(for window: WindowInfo) -> WindowState? {
    // Find the first state for this window in history
    // (before any snap operations)
}
```

---

## 🎯 Priority 3: Polish & Delight

### 3.1 Menu Bar Icon Animation

**Problem:** Menu bar icon is static.

**Solution:** Subtle animation on window snap.

```swift
// StatusBarController.swift
func animateIconOnSnap() {
    // Quick bounce animation (0.3s)
    // Or glow effect
    // Visual confirmation that action happened
}
```

---

### 3.2 Haptic Feedback (Force Touch Trackpad)

**Problem:** No tactile feedback on snap.

**Solution:** Haptic pulse when window snaps.

```swift
// Add to WindowManager.swift
func snapWindow(_ window: WindowInfo, to position: GridPosition) {
    // ... existing code ...
    
    // Trigger haptic feedback
    NSHapticFeedbackManager.defaultPerformer.perform(
        .alignment,
        performanceTime: .default
    )
}
```

---

### 3.3 Sound Effects (Optional)

**Problem:** No audio feedback.

**Solution:** Optional subtle sound on snap (like macOS screenshot sound).

```swift
// PreferencesManager.swift
var playSoundOnSnap: Bool {
    get { userDefaults.bool(forKey: "PlaySoundOnSnap") }
    set { userDefaults.set(newValue, forKey: "PlaySoundOnSnap") }
}

// WindowManager.swift
func playSnapSound() {
    NSSound(named: "Pop")?.play()
}
```

---

### 3.4 Better About Window

**Problem:** About window is a basic alert.

**Solution:** Beautiful custom About window.

```
┌─────────────────────────────────────────────┐
│                                             │
│            ┌───────────────┐                │
│            │               │                │
│            │   [App Icon]  │                │
│            │               │                │
│            └───────────────┘                │
│                                             │
│              WindowSnap                     │
│            Version 2.0.0                    │
│                                             │
│     A native window management app          │
│        for macOS power users                │
│                                             │
│  ─────────────────────────────────────────  │
│                                             │
│    [Website]   [Support]   [Rate App]       │
│                                             │
│         Made with ❤️ in [Location]          │
│         © 2025 WindowSnap                   │
│                                             │
└─────────────────────────────────────────────┘
```

---

### 3.5 Enhanced Clipboard History UI

**Problem:** Current clipboard UI, while good, could be more delightful.

**Solution:** Add animations and polish.

```swift
// Improvements:
// 1. Add staggered entry animation when window opens
// 2. Add "swoosh" animation when item is pasted
// 3. Add keyboard number shortcuts (1-9 for quick paste)
// 4. Add "favorites" section (separate from pins)
// 5. Add category tabs: All | Text | URLs | Images | Files
```

---

## 🎯 Priority 4: Advanced Features

### 4.1 Window Groups

Save and restore groups of windows together.

```
┌───────────────────────────────────────────────────────────┐
│  Window Groups                                            │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  "Development"                              [ Activate ]  │
│  Safari (Left Half) + VS Code (Right Half)                │
│                                                           │
│  "Communication"                            [ Activate ]  │
│  Slack (Left Third) + Email (Center Third)                │
│  + Calendar (Right Third)                                 │
│                                                           │
│  "Focus Mode"                               [ Activate ]  │
│  Single app maximized                                     │
│                                                           │
│  [ + Create Group from Current Windows ]                  │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

### 4.2 Stage Manager Integration

Detect when Stage Manager is active and adjust behavior.

---

### 4.3 Siri Shortcuts Integration

Allow voice commands: "Hey Siri, snap Safari to the left half."

---

### 4.4 Touch Bar Support (Legacy)

For MacBooks with Touch Bar:
- Quick position buttons
- Visual position picker

---

## 📊 Implementation Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| Visual snap feedback | High | Low | **P1** |
| Modern preferences | High | Medium | **P1** |
| Replace NSUserNotification | High | Low | **P1** |
| Onboarding flow | High | Medium | **P1** |
| Drag-to-edge snapping | Very High | High | **P2** |
| Custom shortcuts UI | High | Medium | **P2** |
| Window gaps | Medium | Low | **P2** |
| Shortcut cheat sheet | Medium | Low | **P2** |
| Menu bar animation | Low | Low | **P3** |
| Haptic feedback | Low | Very Low | **P3** |
| Sound effects | Low | Very Low | **P3** |
| Better About window | Low | Low | **P3** |
| App-specific rules | Medium | High | **P4** |
| Window groups | Medium | High | **P4** |

---

## 🎨 Design Tokens

For consistency across all UI:

```swift
struct DesignSystem {
    // Colors
    static let accentPrimary = Color(hex: "#6366f1")    // Indigo
    static let accentSecondary = Color(hex: "#8b5cf6")  // Purple
    static let success = Color(hex: "#10b981")          // Emerald
    static let warning = Color(hex: "#f59e0b")          // Amber
    
    // Animation
    static let durationFast: TimeInterval = 0.15
    static let durationNormal: TimeInterval = 0.25
    static let durationSlow: TimeInterval = 0.4
    
    // Spacing
    static let spacingSmall: CGFloat = 8
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24
    
    // Corner Radius
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
}
```

---

## 📝 Success Metrics

A "best-loved" Mac app should achieve:

1. **Reliability**: 99.9% success rate on snap operations
2. **Performance**: < 50ms response time for shortcuts
3. **Discoverability**: New users discover 3+ features in first week
4. **Delight**: Users recommend app to others (NPS > 50)
5. **Retention**: 90% of users still active after 30 days

---

## 🚀 Next Steps

1. **Phase 1 (2 weeks)**: Implement P1 items
   - Visual snap feedback
   - Modern preferences
   - HUD notifications
   - Basic onboarding

2. **Phase 2 (3 weeks)**: Implement P2 items
   - Drag-to-edge snapping
   - Custom shortcuts UI
   - Window gaps
   - Cheat sheet

3. **Phase 3 (1 week)**: Polish
   - Animations
   - Haptics
   - Sounds
   - About window

4. **Phase 4 (2 weeks)**: Advanced features
   - App-specific rules
   - Window groups

---

*This plan transforms WindowSnap from a functional tool into a delightful experience that users will love and recommend.*
