# Launch at Login Feature

## Overview
WindowSnap now supports automatic startup when your Mac boots up or when you log in. This feature includes a user-friendly first-run prompt that asks users if they want to enable auto-start, making the feature discoverable while respecting user choice.

## User Experience

### First-Run Prompt
When users launch WindowSnap for the first time, they'll see a friendly dialog asking if they want to enable auto-start:

- **Timing**: Appears 1.5 seconds after app startup (allows full initialization)
- **Options**: 
  - "Yes, Start Automatically" - Enables launch at login immediately
  - "No, Don't Auto-Start" - Respects user choice, shows confirmation
  - "Decide Later" - Provides information on how to access preferences later
- **One-time**: Prompt only shows once and remembers the user's interaction

### Manual Configuration
Users can always change the setting later through:
1. Menu bar icon → Preferences
2. General tab → "Launch WindowSnap at login" checkbox

## Implementation Details

### Architecture
The launch at login functionality is implemented using Apple's recommended approaches:

1. **Modern Approach (macOS 13+)**: Uses the new `SMAppService` framework
2. **Legacy Approach (macOS 12 and earlier)**: Uses the deprecated but still functional `SMLoginItemSetEnabled` API

### Key Components

#### 1. LaunchAtLoginManager
- **File**: `WindowSnap/Utils/LaunchAtLoginManager.swift`
- **Purpose**: Manages the system-level launch at login registration
- **Features**:
  - Automatic macOS version detection
  - Error handling for failed operations
  - Preference synchronization
  - Cross-version compatibility

#### 2. LaunchAtLoginPrompt (NEW)
- **File**: `WindowSnap/Utils/LaunchAtLoginPrompt.swift`
- **Purpose**: Handles first-run user prompting for auto-start feature
- **Features**:
  - Smart first-run detection
  - User-friendly dialog with clear options
  - Error handling and feedback
  - Integration with preferences system
  - Direct access to preferences when needed

#### 3. Enhanced PreferencesManager
- **File**: `WindowSnap/Core/PreferencesManager.swift`
- **Changes**:
  - Added first-run tracking (`isFirstRun`)
  - Added prompt tracking (`hasShownLaunchAtLoginPrompt`)
  - Methods to manage onboarding state

#### 4. Updated Preferences UI
- **File**: `WindowSnap/UI/PreferencesWindow.swift`
- **Changes**:
  - Uses `LaunchAtLoginManager` instead of just storing preferences
  - Provides user feedback for errors
  - Reverts checkbox state if operation fails

#### 5. Enhanced App Initialization
- **File**: `WindowSnap/App/AppDelegate.swift`
- **Changes**:
  - Shows first-run prompt when appropriate
  - Initializes launch at login state on app start
  - Syncs system state with preferences
  - Sets up notification observers for preferences access
  - Ensures consistency between system and app preferences

#### 6. Updated StatusBarController
- **File**: `WindowSnap/App/AppDelegate.swift`
- **Changes**:
  - Initializes launch at login state on app start
  - Syncs system state with preferences
  - Ensures consistency between system and app preferences

#### 6. Updated StatusBarController
- **File**: `WindowSnap/UI/StatusBarController.swift`
- **Changes**:
  - Made `showPreferences()` method accessible for programmatic access
  - Allows the prompt system to open preferences when requested

#### 7. Info.plist Configuration
- **File**: `WindowSnap/App/Info.plist`
- **Changes**:
  - Added `SMLoginItemSetEnabled` key for legacy support

## How to Use

### For Users
1. Launch WindowSnap
2. Click the WindowSnap icon in the menu bar
3. Select "Preferences"
4. In the General tab, check "Launch WindowSnap at login"
5. The setting is applied immediately

### Testing the First-Run Prompt

1. **Reset app state to simulate first run:**
   ```bash
   defaults delete com.windowsnap.app
   ```

2. **Launch the app:**
   ```bash
   cd WindowSnap && swift run
   ```

3. **Observe the prompt:**
   - Appears approximately 1.5 seconds after startup
   - Shows clear options for the user
   - Handles each choice appropriately

4. **Verify the choice:**
   - Check System Preferences → General → Login Items
   - Verify the setting persists across app restarts

### Manual Configuration Testing
1. Enable launch at login in preferences
2. Quit WindowSnap completely
3. Log out and log back in (or restart your Mac)
4. WindowSnap should start automatically

## Technical Notes

### macOS Version Support
- **macOS 13.0+**: Uses `SMAppService.mainApp.register()`/`unregister()`
- **macOS 12.0 and earlier**: Uses `SMLoginItemSetEnabled()`

### Error Handling
- If enabling/disabling launch at login fails, an alert is shown to the user
- The checkbox state is reverted if the operation fails
- Errors are logged to the console for debugging

### Preference Synchronization
- On app startup, the system state is checked against stored preferences
- If there's a mismatch, the system state takes precedence
- This ensures consistency if the user manually changes login items in System Preferences

## Security Considerations
- The app requests appropriate permissions through the ServiceManagement framework
- No additional entitlements are required beyond what's already in the app
- The feature respects user privacy and system security boundaries

## Troubleshooting

### Common Issues
1. **Setting doesn't persist**: Check that the app has proper permissions
2. **App doesn't start on login**: Verify in System Preferences > General > Login Items
3. **Error when toggling setting**: Check console logs for detailed error messages

### Manual Verification
You can manually check if launch at login is enabled:
1. Open System Preferences/Settings
2. Go to General > Login Items (or Users & Groups > Login Items on older macOS)
3. Look for "WindowSnap" in the list

## Future Enhancements
- Add option to start minimized/hidden when launched at login
- Support for delayed startup to avoid overwhelming system resources
- Integration with Focus modes to conditionally enable/disable startup
