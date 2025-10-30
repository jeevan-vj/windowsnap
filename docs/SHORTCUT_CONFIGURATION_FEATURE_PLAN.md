# Shortcut Configuration Feature - Implementation Plan

## Overview
Implement a comprehensive keyboard shortcut configuration system that allows users to customize all shortcuts in WindowSnap, including window positioning, clipboard history (paste), undo/redo, display switching, incremental resizing, and window throw.

## Current State Analysis

### Existing Shortcuts (Hardcoded)

#### Window Positioning (14 shortcuts)
- `Cmd+Shift+Left` → Left Half
- `Cmd+Shift+Right` → Right Half
- `Cmd+Shift+Up` → Top Half
- `Cmd+Shift+Down` → Bottom Half
- `Cmd+Option+1` → Top Left Quarter
- `Cmd+Option+2` → Top Right Quarter
- `Cmd+Option+3` → Bottom Left Quarter
- `Cmd+Option+4` → Bottom Right Quarter
- `Cmd+Option+Left` → Left Third
- `Cmd+Option+Right` → Right Third
- `Cmd+Option+Up` → Left Two-Thirds
- `Cmd+Option+Down` → Right Two-Thirds
- `Cmd+Shift+M` → Maximize
- `Cmd+Shift+C` → Center

#### Productivity Shortcuts (6 shortcuts)
- `Cmd+Option+Z` → Undo Last Action
- `Cmd+Option+Shift+Z` → Redo Last Action
- `Ctrl+Option+Cmd+Right` → Move to Next Display
- `Ctrl+Option+Cmd+Left` → Move to Previous Display
- `Ctrl+Option+Shift+Right` → Make Window Larger
- `Ctrl+Option+Shift+Left` → Make Window Smaller

#### Advanced Features (2 shortcuts)
- `Ctrl+Option+Cmd+Space` → Window Throw (interactive positioning)
- `Cmd+Shift+V` → Clipboard History (paste)

**Total: 22 configurable shortcuts**

### Current Implementation Gaps
1. All shortcuts are hardcoded in `ShortcutManager` and `AppDelegate`
2. No UI for viewing or modifying shortcuts
3. No persistence of user-customized shortcuts
4. No conflict detection between shortcuts
5. `PreferencesWindow` only shows static list of shortcuts

## Architecture Design

### 1. Data Models

#### ShortcutAction Enum
```swift
enum ShortcutAction: String, Codable, CaseIterable {
    // Window Positioning
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case leftThird
    case rightThird
    case leftTwoThirds
    case rightTwoThirds
    case maximize
    case center
    
    // Productivity
    case undo
    case redo
    case nextDisplay
    case previousDisplay
    case makeLarger
    case makeSmaller
    
    // Advanced Features
    case windowThrow
    case clipboardHistory
    
    var displayName: String { /* ... */ }
    var category: ShortcutCategory { /* ... */ }
    var defaultShortcut: String { /* ... */ }
}
```

#### ShortcutCategory Enum
```swift
enum ShortcutCategory: String, CaseIterable {
    case windowPositioning = "Window Positioning"
    case productivity = "Productivity"
    case advanced = "Advanced Features"
}
```

#### ConfigurableShortcut Model
```swift
struct ConfigurableShortcut: Codable, Equatable {
    let action: ShortcutAction
    var shortcutString: String  // e.g., "cmd+shift+left"
    var isEnabled: Bool
    
    var displayShortcut: String { /* Convert to symbol format */ }
}
```

### 2. Persistence Layer

#### PreferencesManager Extensions
```swift
extension PreferencesManager {
    // Save/load shortcut configurations
    func getShortcutConfiguration() -> [ShortcutAction: ConfigurableShortcut]
    func saveShortcutConfiguration(_ config: [ShortcutAction: ConfigurableShortcut])
    func resetShortcutsToDefaults()
    
    // Individual shortcut management
    func getShortcut(for action: ShortcutAction) -> ConfigurableShortcut?
    func setShortcut(_ shortcut: ConfigurableShortcut, for action: ShortcutAction)
    func disableShortcut(for action: ShortcutAction)
}
```

**Storage Format:**
- UserDefaults key: `"ShortcutConfiguration"`
- Format: JSON dictionary mapping `ShortcutAction.rawValue` to `ConfigurableShortcut`

### 3. Shortcut Management

#### ShortcutManager Enhancements
```swift
extension ShortcutManager {
    // Dynamic registration based on configuration
    func registerShortcutsFromConfiguration(_ config: [ShortcutAction: ConfigurableShortcut])
    func reloadShortcuts() // Unregister all, reload from prefs, re-register
    
    // Validation
    func validateShortcut(_ shortcutString: String) -> Bool
    func findConflicts(for shortcutString: String, excluding action: ShortcutAction?) -> [ShortcutAction]
}
```

#### Shortcut Action Execution
```swift
extension ShortcutManager {
    func executeAction(_ action: ShortcutAction) {
        // Dispatch to appropriate handler based on action type
    }
}
```

### 4. User Interface

#### ShortcutRecorderControl
Custom `NSView` subclass for capturing keyboard shortcuts:
- Click to activate recording mode
- Display current shortcut or "Click to record..."
- Capture key events (Cmd, Option, Shift, Ctrl + any key)
- Show visual feedback during recording
- Clear button to remove shortcut
- Validation and conflict warnings

**Features:**
- Real-time conflict detection
- Invalid shortcut prevention (e.g., single modifier key)
- Escape key cancels recording
- Delete/Backspace clears shortcut

#### ShortcutsConfigurationWindow
New window accessible from Preferences:
- **Layout:** Grouped by category (Window Positioning, Productivity, Advanced)
- **Table View:** Action name | Current shortcut | Edit button
- **Actions:**
  - Double-click or click edit to record new shortcut
  - Disable checkbox to turn off individual shortcuts
  - Reset button to restore defaults for selected item
  - Reset All button to restore all defaults
  - Search/filter bar to find specific shortcuts
- **Conflict Resolution:**
  - Red warning icon if conflict detected
  - Tooltip showing which action has the conflicting shortcut
  - Option to reassign conflicting shortcut

**Window Specifications:**
- Size: 700x600px
- Resizable: Yes
- Title: "Configure Keyboard Shortcuts"
- Tabs or sections for each category
- Apply/Cancel buttons with live preview option

### 5. Integration Points

#### AppDelegate Changes
```swift
private func setupDefaultShortcuts() {
    guard let shortcutManager = shortcutManager else { return }
    
    // Load configuration from preferences
    let config = PreferencesManager.shared.getShortcutConfiguration()
    
    // Register shortcuts based on configuration
    shortcutManager.registerShortcutsFromConfiguration(config)
}
```

#### PreferencesWindow Updates
- Add "Configure Shortcuts..." button in Shortcuts tab
- Opens `ShortcutsConfigurationWindow`
- Remove static shortcut list (replaced by configuration window)

#### StatusBarController Updates
- Update menu items to show current (possibly customized) shortcuts
- Dynamically generate menu based on current configuration

## Implementation Phases

### Phase 1: Foundation (Models & Persistence)
**Files to create/modify:**
- Create `WindowSnap/Models/ShortcutAction.swift`
- Create `WindowSnap/Models/ConfigurableShortcut.swift`
- Modify `WindowSnap/Core/PreferencesManager.swift`

**Deliverables:**
- Shortcut action definitions
- Configuration data model
- Persistence methods

### Phase 2: Shortcut Manager Refactor
**Files to modify:**
- Modify `WindowSnap/Core/ShortcutManager.swift`

**Deliverables:**
- Dynamic shortcut registration
- Action execution dispatcher
- Conflict detection logic
- Validation methods

### Phase 3: UI Components
**Files to create:**
- Create `WindowSnap/UI/ShortcutRecorderControl.swift`
- Create `WindowSnap/UI/ShortcutsConfigurationWindow.swift`

**Deliverables:**
- Keyboard shortcut recorder widget
- Configuration window with full functionality
- Conflict resolution UI

### Phase 4: Integration
**Files to modify:**
- Modify `WindowSnap/App/AppDelegate.swift`
- Modify `WindowSnap/UI/PreferencesWindow.swift`
- Modify `WindowSnap/UI/StatusBarController.swift`

**Deliverables:**
- Load custom shortcuts on app launch
- Link configuration window from preferences
- Update status bar menu with custom shortcuts
- Health check integration for custom shortcuts

### Phase 5: Testing & Polish
**Tasks:**
- Test all 22 shortcuts can be customized
- Test persistence across app restarts
- Test conflict detection and resolution
- Test sleep/wake recovery with custom shortcuts
- Test reset to defaults functionality
- Test edge cases (invalid shortcuts, all disabled, etc.)

## Technical Considerations

### Shortcut String Format
- Storage: `"modifier+modifier+key"` (lowercase, alphabetical modifiers)
- Modifiers: `cmd`, `option`, `shift`, `ctrl`
- Example: `"cmd+shift+left"`

### Display Format
- Show with symbols: `⌘⇧←`
- Modifier order: `⌃⌥⇧⌘` (Ctrl, Option, Shift, Cmd)

### Validation Rules
1. Must have at least one modifier key
2. Must have exactly one non-modifier key
3. Cannot conflict with system shortcuts (warn user)
4. Cannot have duplicates within app

### Migration Strategy
For existing users upgrading to this version:
1. On first launch, detect no saved configuration
2. Initialize with default shortcuts
3. Save to preferences
4. User can then customize

### Default Shortcut Conflicts
System may reserve some shortcuts - handle gracefully:
- Show warning in UI
- Allow user to attempt anyway
- Log registration failures
- Provide alternative suggestions

## User Experience Flow

### First-Time User
1. Installs WindowSnap
2. Default shortcuts are automatically configured
3. Can open Preferences → Shortcuts → Configure to customize

### Customizing a Shortcut
1. Open Preferences → Shortcuts
2. Click "Configure Shortcuts..."
3. Find desired action in list
4. Double-click or click Edit
5. Press desired key combination
6. If conflict, see warning and resolve
7. Changes apply immediately (shortcuts re-registered)
8. Close window

### Resolving Conflicts
1. Record shortcut that conflicts
2. Warning appears: "⚠️ Conflict with [Action Name]"
3. Options:
   - Reassign both (swap)
   - Disable conflicting action
   - Choose different shortcut

### Reset to Defaults
1. Select action(s) to reset
2. Click "Reset Selected"
3. Or click "Reset All to Defaults"
4. Confirmation dialog
5. Shortcuts restored to defaults

## Success Metrics

### Functionality Checklist
- [ ] All 22 shortcuts are configurable
- [ ] Shortcuts persist across app restarts
- [ ] Shortcuts work after sleep/wake
- [ ] No memory leaks in shortcut registration/unregistration
- [ ] Conflict detection works reliably
- [ ] UI is intuitive and responsive
- [ ] Search/filter works in configuration window
- [ ] Reset functionality works correctly
- [ ] Disabled shortcuts are not registered
- [ ] Custom shortcuts appear in status bar menu

### User Experience Goals
- Configuration window opens in < 200ms
- Shortcut recording feels instant (< 100ms)
- Conflict detection is real-time
- No app restart required for changes
- Clear visual feedback for all actions

## Future Enhancements (Out of Scope)

### v2.0 Features
1. **Import/Export Shortcuts**
   - Save configuration to JSON file
   - Share with other users

2. **Shortcut Profiles**
   - Create multiple named profiles
   - Quick-switch between profiles (e.g., "Work", "Home", "Coding")

3. **Advanced Shortcut Types**
   - Sequences (press A then B)
   - Chorded shortcuts (press A while holding B)
   - Mouse button shortcuts

4. **Smart Suggestions**
   - AI-powered conflict resolution
   - Suggest alternatives based on common patterns
   - Warn about hard-to-reach combinations

5. **Shortcut Usage Analytics**
   - Track which shortcuts are used most
   - Suggest disabling unused shortcuts
   - Optimization recommendations

6. **Global Shortcut Search**
   - Search all registered shortcuts system-wide
   - Detect conflicts with other apps
   - System shortcut awareness

## Development Timeline

### Estimated Effort
- **Phase 1:** 4-6 hours
- **Phase 2:** 6-8 hours
- **Phase 3:** 10-12 hours (UI is most complex)
- **Phase 4:** 3-4 hours
- **Phase 5:** 6-8 hours

**Total: 29-38 hours** (approximately 1 week of focused development)

## Dependencies

### Frameworks
- `AppKit` - UI components
- `Carbon` - Keyboard event handling (already used)
- `Foundation` - Data persistence

### Existing Code
- `ShortcutManager` - Core shortcut registration
- `PreferencesManager` - Settings persistence
- `PreferencesWindow` - Entry point to configuration
- `AppDelegate` - Shortcut initialization

### No External Dependencies
All functionality can be implemented using existing frameworks.

## Risk Assessment

### Potential Issues

1. **System Shortcut Conflicts**
   - **Risk:** User tries to assign shortcut owned by macOS
   - **Mitigation:** Show warning but allow attempt; log failures

2. **Performance**
   - **Risk:** Re-registering 22 shortcuts on every change
   - **Mitigation:** Only re-register changed shortcuts; optimize with diffing

3. **Data Corruption**
   - **Risk:** Invalid JSON in UserDefaults crashes app
   - **Mitigation:** Robust error handling; fall back to defaults

4. **UI Complexity**
   - **Risk:** Configuration window becomes overwhelming
   - **Mitigation:** Clear categorization; search/filter; progressive disclosure

5. **Accessibility**
   - **Risk:** Custom controls not accessible
   - **Mitigation:** Use native AppKit controls; test with VoiceOver

## Testing Strategy

### Unit Tests
- Shortcut string parsing and validation
- Conflict detection algorithm
- Persistence save/load
- Default configuration generation

### Integration Tests
- Shortcut registration with ShortcutManager
- Configuration changes applied immediately
- Persistence across app lifecycle

### Manual Testing
- All 22 shortcuts configurable
- UI responsiveness
- Edge cases (no shortcuts, all disabled, many conflicts)
- Sleep/wake with custom shortcuts
- Multi-monitor with custom shortcuts

### User Acceptance Testing
- Recruit 3-5 beta testers
- Gather feedback on UI intuitiveness
- Identify pain points
- Iterate based on feedback

## Documentation Updates

### User Documentation
- Update README with shortcut customization instructions
- Add screenshots of configuration window
- Create troubleshooting guide for conflicts

### Developer Documentation
- Document ShortcutAction enum
- Document ConfigurableShortcut model
- Add code comments for complex logic
- Update architecture diagrams

## Conclusion

This feature will significantly enhance WindowSnap by giving users full control over keyboard shortcuts, addressing a common user request and differentiating from competitors that have rigid shortcut schemes. The phased implementation approach allows for incremental delivery and testing, reducing risk while maintaining momentum.

The design prioritizes:
1. **User Control:** All shortcuts customizable
2. **Safety:** Conflict detection prevents issues
3. **Flexibility:** Enable/disable individual shortcuts
4. **Reliability:** Robust persistence and recovery
5. **Usability:** Intuitive UI with clear feedback

Implementation should begin with Phase 1 to establish the data foundation, followed by Phase 2 to refactor the shortcut system, then Phase 3 for the user-facing UI, and finally Phases 4 and 5 for integration and polish.
