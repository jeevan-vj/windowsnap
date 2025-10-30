# Shortcut Configuration Feature - Architecture Diagram

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            USER INTERFACE LAYER                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────┐      ┌──────────────────────────────────────┐ │
│  │  PreferencesWindow  │─────▶│  ShortcutsConfigurationWindow        │ │
│  │                     │      │  - Grouped by category                │ │
│  │  [Shortcuts Tab]    │      │  - Search/filter                      │ │
│  │  "Configure..."     │      │  - Conflict detection UI              │ │
│  └─────────────────────┘      │  - Reset to defaults                  │ │
│                                │                                        │ │
│                                │  ┌──────────────────────────────────┐│ │
│                                │  │  ShortcutRecorderControl         ││ │
│                                │  │  - Click to record               ││ │
│                                │  │  - Real-time validation          ││ │
│                                │  │  - Visual feedback               ││ │
│                                │  │  - Clear button                  ││ │
│                                │  └──────────────────────────────────┘│ │
│                                └──────────────────────────────────────┘ │
│                                                                           │
│  ┌─────────────────────┐                                                │
│  │ StatusBarController │  (displays current shortcuts in menu)          │
│  └─────────────────────┘                                                │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          BUSINESS LOGIC LAYER                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      ShortcutManager                             │   │
│  │                                                                   │   │
│  │  - registerShortcutsFromConfiguration()                         │   │
│  │  - reloadShortcuts()                                            │   │
│  │  - executeAction(_ action: ShortcutAction)                      │   │
│  │  - validateShortcut(_ string: String) -> Bool                   │   │
│  │  - findConflicts(for: String, excluding: ShortcutAction?)       │   │
│  │                                                                   │   │
│  │  ┌─────────────────────────────────────────────────────────┐   │   │
│  │  │  Action Dispatcher                                       │   │   │
│  │  │  switch action {                                         │   │   │
│  │  │    case .leftHalf: → WindowManager.snap(.leftHalf)      │   │   │
│  │  │    case .undo: → WindowManager.undoLastAction()         │   │   │
│  │  │    case .clipboardHistory: → show clipboard window      │   │   │
│  │  │    ...                                                   │   │   │
│  │  │  }                                                        │   │   │
│  │  └─────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    PreferencesManager                            │   │
│  │                                                                   │   │
│  │  - getShortcutConfiguration() -> [ShortcutAction: Configurable] │   │
│  │  - saveShortcutConfiguration(_ config)                          │   │
│  │  - resetShortcutsToDefaults()                                   │   │
│  │  - getShortcut(for action: ShortcutAction)                      │   │
│  │  - setShortcut(_ shortcut, for action: ShortcutAction)          │   │
│  │                                                                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            DATA MODEL LAYER                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  enum ShortcutAction: String, Codable, CaseIterable             │  │
│  │                                                                   │  │
│  │  Window Positioning (14):                                        │  │
│  │    .leftHalf, .rightHalf, .topHalf, .bottomHalf                 │  │
│  │    .topLeft, .topRight, .bottomLeft, .bottomRight               │  │
│  │    .leftThird, .rightThird, .leftTwoThirds, .rightTwoThirds    │  │
│  │    .maximize, .center                                           │  │
│  │                                                                   │  │
│  │  Productivity (6):                                               │  │
│  │    .undo, .redo                                                  │  │
│  │    .nextDisplay, .previousDisplay                               │  │
│  │    .makeLarger, .makeSmaller                                    │  │
│  │                                                                   │  │
│  │  Advanced (2):                                                   │  │
│  │    .windowThrow, .clipboardHistory                              │  │
│  │                                                                   │  │
│  │  Methods:                                                         │  │
│  │    - var displayName: String                                     │  │
│  │    - var category: ShortcutCategory                              │  │
│  │    - var defaultShortcut: String                                 │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  struct ConfigurableShortcut: Codable, Equatable                │  │
│  │                                                                   │  │
│  │    let action: ShortcutAction                                    │  │
│  │    var shortcutString: String      // "cmd+shift+left"          │  │
│  │    var isEnabled: Bool                                           │  │
│  │                                                                   │  │
│  │    var displayShortcut: String     // "⌘⇧←"                     │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  enum ShortcutCategory: String, CaseIterable                     │  │
│  │                                                                   │  │
│  │    case windowPositioning = "Window Positioning"                 │  │
│  │    case productivity = "Productivity"                            │  │
│  │    case advanced = "Advanced Features"                           │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         PERSISTENCE LAYER                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  UserDefaults.standard                                           │  │
│  │                                                                   │  │
│  │  Key: "ShortcutConfiguration"                                    │  │
│  │  Format: JSON Dictionary                                         │  │
│  │  {                                                                │  │
│  │    "leftHalf": {                                                 │  │
│  │      "action": "leftHalf",                                       │  │
│  │      "shortcutString": "cmd+shift+left",                        │  │
│  │      "isEnabled": true                                           │  │
│  │    },                                                             │  │
│  │    "clipboardHistory": {                                         │  │
│  │      "action": "clipboardHistory",                               │  │
│  │      "shortcutString": "cmd+shift+v",                           │  │
│  │      "isEnabled": true                                           │  │
│  │    },                                                             │  │
│  │    ...                                                            │  │
│  │  }                                                                │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagrams

### 1. Application Startup Flow

```
┌──────────────┐
│ AppDelegate  │
│ didFinishLaunching
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────┐
│ PreferencesManager.shared            │
│ .getShortcutConfiguration()          │
└──────┬───────────────────────────────┘
       │
       ├─▶ Load from UserDefaults
       │   "ShortcutConfiguration"
       │
       ├─▶ If not found:
       │   └─▶ Generate defaults
       │       └─▶ Save to UserDefaults
       │
       ▼
┌──────────────────────────────────────┐
│ Returns:                              │
│ [ShortcutAction: ConfigurableShortcut]│
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│ ShortcutManager                       │
│ .registerShortcutsFromConfiguration() │
└──────┬───────────────────────────────┘
       │
       ├─▶ For each enabled shortcut:
       │   └─▶ registerGlobalShortcut(
       │         shortcutString,
       │         action: { executeAction(action) }
       │       )
       │
       ▼
   [App Ready]
```

### 2. User Customizes Shortcut Flow

```
┌─────────────────┐
│ User clicks     │
│ "Configure..."  │
│ in Preferences  │
└────────┬────────┘
         │
         ▼
┌──────────────────────────────────┐
│ ShortcutsConfigurationWindow     │
│ opens with current configuration │
└────────┬─────────────────────────┘
         │
         ├─▶ Load from PreferencesManager
         │
         ▼
┌──────────────────────────────────┐
│ User double-clicks action row    │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ ShortcutRecorderControl          │
│ enters recording mode            │
└────────┬─────────────────────────┘
         │
         ├─▶ Wait for key press
         │
         ▼
┌──────────────────────────────────┐
│ User presses key combination     │
│ e.g., Cmd+Shift+K                │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ Validate shortcut                │
│ - Has modifier?                  │
│ - Valid key?                     │
│ - Check conflicts                │
└────────┬─────────────────────────┘
         │
         ├─▶ If invalid: Show error
         │
         ├─▶ If conflict: Show warning
         │   └─▶ User resolves
         │
         ▼
┌──────────────────────────────────┐
│ Update ConfigurableShortcut      │
│ shortcutString = "cmd+shift+k"   │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ Save to PreferencesManager       │
│ .setShortcut(shortcut, for:      │
│   action)                        │
└────────┬─────────────────────────┘
         │
         ├─▶ Update UserDefaults
         │
         ▼
┌──────────────────────────────────┐
│ ShortcutManager.reloadShortcuts()│
└────────┬─────────────────────────┘
         │
         ├─▶ Unregister all shortcuts
         ├─▶ Re-register from new config
         │
         ▼
   [Shortcut Active]
```

### 3. Shortcut Execution Flow

```
┌──────────────────┐
│ User presses     │
│ Cmd+Shift+Left   │
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────────┐
│ macOS Event System              │
│ triggers hotkey handler         │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│ ShortcutManager                 │
│ handleHotKeyEvent()             │
└────────┬────────────────────────┘
         │
         ├─▶ Lookup action for hotkey ID
         │
         ▼
┌─────────────────────────────────┐
│ ShortcutManager                 │
│ executeAction(.leftHalf)        │
└────────┬────────────────────────┘
         │
         ├─▶ Switch on action type
         │
         ▼
┌─────────────────────────────────┐
│ WindowManager.shared            │
│ .snapWindow(window, .leftHalf)  │
└────────┬────────────────────────┘
         │
         ▼
   [Window Moved]
```

### 4. Conflict Detection Flow

```
┌─────────────────────────────────┐
│ User records shortcut           │
│ "cmd+shift+v"                   │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│ ShortcutManager                 │
│ .findConflicts(                 │
│   for: "cmd+shift+v",           │
│   excluding: .leftHalf          │
│ )                               │
└────────┬────────────────────────┘
         │
         ├─▶ Get all enabled shortcuts
         ├─▶ Filter out excluded action
         ├─▶ Check if any match string
         │
         ▼
┌─────────────────────────────────┐
│ Found: [.clipboardHistory]      │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────────────────────┐
│ Display conflict warning:       │
│ "⚠️ Already assigned to          │
│  Clipboard History"             │
│                                  │
│ [Change Anyway] [Choose Other]  │
└────────┬────────────────────────┘
         │
         ├─▶ Change Anyway:
         │   └─▶ Update current action
         │       └─▶ Disable conflicting action
         │
         ├─▶ Choose Other:
         │   └─▶ Return to recording
         │
         ▼
   [Resolved]
```

## Component Interaction Matrix

```
┌──────────────────────┬────────────┬────────────┬─────────────┬──────────────┐
│ Component            │ Reads From │ Writes To  │ Depends On  │ Used By      │
├──────────────────────┼────────────┼────────────┼─────────────┼──────────────┤
│ ShortcutAction       │ -          │ -          │ -           │ All          │
│ (enum)               │            │            │             │              │
├──────────────────────┼────────────┼────────────┼─────────────┼──────────────┤
│ ConfigurableShortcut │ -          │ -          │ Shortcut    │ Manager      │
│ (model)              │            │            │ Action      │ classes      │
├──────────────────────┼────────────┼────────────┼─────────────┼──────────────┤
│ PreferencesManager   │ User       │ User       │ Shortcut    │ All UI,      │
│                      │ Defaults   │ Defaults   │ models      │ AppDelegate  │
├──────────────────────┼────────────┼────────────┼─────────────┼──────────────┤
│ ShortcutManager      │ Prefs      │ -          │ Carbon,     │ AppDelegate, │
│                      │ Manager    │            │ models      │ UI           │
├──────────────────────┼────────────┼────────────┼─────────────┼──────────────┤
│ ShortcutRecorder     │ Shortcut   │ Config     │ AppKit      │ Config       │
│ Control              │ Manager    │ Window     │             │ Window       │
├──────────────────────┼────────────┼────────────┼─────────────┼──────────────┤
│ Shortcuts            │ Prefs      │ Prefs      │ Recorder,   │ Preferences  │
│ ConfigurationWindow  │ Manager    │ Manager    │ Shortcut    │ Window       │
│                      │            │            │ Manager     │              │
├──────────────────────┼────────────┼────────────┼─────────────┼──────────────┤
│ PreferencesWindow    │ -          │ -          │ Config      │ StatusBar,   │
│                      │            │            │ Window      │ AppDelegate  │
├──────────────────────┼────────────┼────────────┼─────────────┼──────────────┤
│ AppDelegate          │ Prefs      │ -          │ All         │ macOS        │
│                      │ Manager    │            │             │              │
└──────────────────────┴────────────┴────────────┴─────────────┴──────────────┘
```

## File Structure

```
WindowSnap/
├── Models/
│   ├── ShortcutAction.swift          [NEW]
│   └── ConfigurableShortcut.swift    [NEW]
│
├── Core/
│   ├── PreferencesManager.swift      [MODIFIED - add shortcut methods]
│   └── ShortcutManager.swift         [MODIFIED - add dynamic registration]
│
├── UI/
│   ├── ShortcutRecorderControl.swift [NEW]
│   ├── ShortcutsConfigurationWindow.swift [NEW]
│   ├── PreferencesWindow.swift       [MODIFIED - add link to config]
│   └── StatusBarController.swift     [MODIFIED - dynamic menu generation]
│
└── App/
    └── AppDelegate.swift              [MODIFIED - load custom shortcuts]
```

## State Management

### Application State

```
┌─────────────────────────────────────────────────────────────┐
│                    Application State                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Current Shortcut Configuration                              │
│  ├─ In-Memory: ShortcutManager.registeredShortcuts          │
│  └─ Persisted: UserDefaults["ShortcutConfiguration"]        │
│                                                               │
│  UI State                                                    │
│  ├─ Configuration Window Open/Closed                         │
│  ├─ Currently Recording Action: ShortcutAction?             │
│  └─ Pending Changes: [ShortcutAction: ConfigurableShortcut] │
│                                                               │
│  Validation State                                            │
│  ├─ Active Conflicts: [(ShortcutAction, ShortcutAction)]    │
│  └─ Invalid Shortcuts: [ShortcutAction]                     │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### State Transitions

```
[App Launch]
     │
     ├─▶ Load Configuration
     │   └─▶ [Default Config] or [Custom Config]
     │
     ├─▶ Register Shortcuts
     │   └─▶ [Shortcuts Active]
     │
[User Opens Config Window]
     │
     ├─▶ Display Current Configuration
     │   └─▶ [Editing Mode]
     │
     ├─▶ User Modifies Shortcut
     │   ├─▶ Validate
     │   │   ├─▶ [Valid] → Apply
     │   │   └─▶ [Invalid/Conflict] → Show Warning
     │   │
     │   └─▶ Save Configuration
     │       └─▶ Reload Shortcuts
     │
[User Closes Config Window]
     │
     └─▶ Return to [Shortcuts Active]
```

## Error Handling Strategy

### Error Types

1. **Registration Failures**
   - Cause: System shortcut conflict, invalid key code
   - Handling: Log error, show user notification, suggest alternative

2. **Persistence Failures**
   - Cause: UserDefaults write failure, JSON encoding error
   - Handling: Fall back to defaults, warn user, retry on next launch

3. **Validation Errors**
   - Cause: Invalid key combination, missing modifier
   - Handling: Show inline error in UI, prevent saving

4. **Conflict Errors**
   - Cause: Duplicate shortcut assignment
   - Handling: Show resolution dialog, offer to reassign

### Error Recovery

```
┌──────────────────────────────────────┐
│ Error Occurs                         │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Log Error with Context               │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Attempt Recovery                     │
├──────────────────────────────────────┤
│ - Fall back to defaults              │
│ - Disable problematic shortcut       │
│ - Retry operation once               │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ Notify User (if appropriate)         │
│ - Show alert for critical errors     │
│ - Log only for minor issues          │
└──────────────────────────────────────┘
```

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading**
   - Configuration window UI created only when opened
   - Shortcut recorder controls pooled/reused

2. **Incremental Updates**
   - Only re-register changed shortcuts (diff algorithm)
   - Debounce save operations (e.g., 500ms delay)

3. **Caching**
   - Cache parsed shortcut strings
   - Cache conflict detection results during editing session

4. **Async Operations**
   - Load configuration from disk asynchronously
   - Save to UserDefaults on background queue

### Performance Metrics

- Configuration window open: **< 200ms**
- Shortcut recording response: **< 100ms**
- Conflict detection: **< 50ms**
- Configuration save: **< 100ms**
- Shortcut re-registration: **< 500ms for all 22**

## Security Considerations

### Access Control

1. **Accessibility Permissions**
   - Required for global shortcut registration
   - Check before allowing configuration changes

2. **Data Validation**
   - Sanitize shortcut strings before parsing
   - Validate JSON structure when loading config

3. **User Intent Confirmation**
   - Confirm before disabling all shortcuts
   - Confirm before reset to defaults

### Privacy

- No telemetry on which shortcuts users choose
- No cloud sync (local UserDefaults only)
- No export of sensitive key combinations

---

**Document Version:** 1.0  
**Last Updated:** 2025-10-30  
**Author:** WindowSnap Development Team
