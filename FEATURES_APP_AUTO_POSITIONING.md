# App Auto-Positioning Feature

## Overview

The App Auto-Positioning feature allows you to create rules that automatically position windows when applications launch or become active. This is perfect for maintaining a consistent workspace layout and eliminating repetitive window management tasks.

## Key Benefits

- **Productivity**: Automatically arrange your workspace every time you launch apps
- **Consistency**: Maintain the same window layout across sessions
- **Multi-Monitor**: Position apps on specific displays automatically
- **Flexibility**: Create rules for individual apps or apply to all windows
- **Time-Saving**: Eliminate manual window positioning for frequently used apps

## How It Works

### Automatic Mode

When monitoring is enabled, WindowSnap watches for:
- **App Launches**: When an application starts
- **App Activation**: When you switch to an application

WindowSnap then checks if any rules match the application and automatically positions its windows according to the configured rules.

### Manual Mode

You can also manually apply rules:
- **Apply Now**: Instantly position all running apps according to their rules
- **One-Time Setup**: Create rules and apply them whenever you need a workspace reset

## Rule Configuration

### Rule Components

Each rule consists of:

1. **Application**: The target app (e.g., Terminal, Safari, VS Code)
2. **Position Type**: Where to position the window
   - Grid positions (Left Half, Right Half, Top Half, Bottom Half, etc.)
   - Quarters (Top Left, Top Right, Bottom Left, Bottom Right)
   - Thirds (Left Third, Center Third, Right Third)
   - Two-Thirds (Left Two-Thirds, Right Two-Thirds)
   - Special (Maximize, Center)
3. **Target Screen**: Which monitor to use (Main Screen, Screen 2, etc.)
4. **Window Filter**: Which windows to position
   - First Window Only: Only position the first window opened
   - All Windows: Position every window the app opens
5. **Enabled/Disabled**: Toggle rule on/off without deleting

### Creating Rules

#### Method 1: From Current Window

1. Focus the window of the app you want to create a rule for
2. Open **"App Auto-Positioning..."** from the menu bar
3. Click **"Add Current App"**
4. Configure the rule settings
5. Click **"Save"**

#### Method 2: From Running Apps List

1. Open **"App Auto-Positioning..."** from the menu bar
2. Click **"Add Custom"**
3. Select an application from the list
4. Configure the rule settings
5. Click **"Save"**

#### Method 3: Import Presets

Click **"Import Presets"** to add pre-configured rules for common apps:
- **Development**: Terminal, iTerm, VS Code, Xcode
- **Browsers**: Safari, Chrome
- **Communication**: Slack, Mail
- **Media**: Music, Spotify

## Common Workflows

### Development Setup

Create rules for your coding workspace:
- **VS Code**: Left Two-Thirds → Main Screen
- **Terminal**: Bottom Half → Main Screen
- **Browser**: Right Third → Main Screen
- **Slack**: Right Third → Secondary Screen

Every time you launch these apps, they automatically arrange themselves for maximum productivity.

### Multi-Monitor Workflow

Position apps across displays:
- **Main Screen**: Code editor maximized
- **Secondary Screen**: Documentation browser on left half, terminal on right half
- **Tertiary Screen**: Communication apps

### Single-App Multi-Window

For apps that open multiple windows (like browsers):
- **First Window Only**: Main browser window maximized
- **All Windows**: Every new browser window maximizes automatically

## Advanced Features

### Rule Priority

When multiple rules could apply:
1. Rules are applied in the order they appear in the list
2. More specific rules (window title matches) take precedence
3. Disabled rules are skipped

### Window Tracking

WindowSnap tracks which windows it has positioned:
- **Prevents Re-positioning**: Windows won't be repositioned repeatedly
- **Reset Tracking**: Click "Apply Now" to clear tracking and re-apply all rules
- **Smart Detection**: Only positions new windows, not windows you've manually moved

### Statistics

View rule usage:
- **Last Used**: When each rule was last applied
- **Never Used**: Identify rules that may no longer be needed
- **Total Rules**: Overall count of active/inactive rules

## Best Practices

### Start Small

1. Create rules for 2-3 frequently used apps
2. Test them for a few days
3. Refine positions as needed
4. Add more rules gradually

### Use Descriptive Names

When editing rules, the app name is displayed clearly:
- Helps identify rules at a glance
- Makes maintenance easier

### Regular Cleanup

Periodically review your rules:
- Delete rules for apps you no longer use
- Disable rules you want to keep but not use currently
- Update positions if your workflow changes

### Combine with Workspaces

App Auto-Positioning works great with Workspace Arrangements:
- **Auto-Positioning**: Day-to-day automatic positioning
- **Workspaces**: Saved layouts for specific tasks (coding, design, writing)

## Troubleshooting

### Rules Not Applying

**Check Monitoring Status**
- Ensure "Auto-positioning: Enabled" is checked in the rules window
- Monitoring starts automatically when WindowSnap launches

**Verify Rule is Enabled**
- Check the checkbox next to the rule is checked
- Disabled rules won't apply

**Check Accessibility Permissions**
- WindowSnap needs accessibility permissions to move windows
- Grant permissions in System Preferences → Security & Privacy → Accessibility

### Windows Position on Wrong Screen

**Update Screen Index**
- Screens are numbered based on macOS display arrangement
- Main screen is always index 0
- Check your screen arrangement in System Preferences → Displays

**Multi-Monitor Changes**
- If you frequently connect/disconnect displays, you may need to update rules
- Or create different rules for laptop-only vs. docked configurations

### App Not Recognized

**Bundle Identifier Required**
- WindowSnap uses bundle identifiers to match apps
- Some apps may not have standard bundle IDs
- Try the "Add Current App" method while the app is running

### Performance

**Too Many Rules**
- Having 50+ rules shouldn't impact performance
- Rules are stored efficiently and checked quickly
- Consider disabling rules you rarely use instead of deleting

## Technical Details

### Data Storage

- Rules are stored in `UserDefaults` under key `WindowSnap_AppPositioningRules`
- Stored as JSON for easy backup/export
- Automatically persisted when changes are made

### Window Matching

WindowSnap identifies windows by:
1. **Application Name**: Display name of the app
2. **Bundle Identifier**: Unique app identifier (e.g., `com.apple.Safari`)
3. **Window Title**: Optional, for specific window targeting

### Position Calculation

Positions are calculated relative to screen dimensions:
- Works across different monitor sizes
- Adapts to screen resolution changes
- Accounts for menu bar and dock space

### App Launch Detection

WindowSnap uses `NSWorkspace` notifications:
- `didLaunchApplicationNotification`: When app starts
- `didActivateApplicationNotification`: When app becomes active

### Positioning Delay

A small delay (0.5 seconds) ensures windows are fully loaded before positioning.

## Future Enhancements

Potential improvements for future versions:
- **Window Title Matching**: Position specific windows by title (e.g., only Gmail tabs)
- **Time-Based Rules**: Apply different rules based on time of day
- **Conditional Rules**: Different positions based on monitor configuration
- **Rule Templates**: Save and share rule sets
- **Cloud Sync**: Sync rules across multiple Macs

## Feedback

This feature is new! Please report:
- Apps that don't work correctly
- Performance issues
- Feature requests
- User experience improvements

---

**Pro Tip**: Combine App Auto-Positioning with the Window Throw feature (⌃⌥⌘Space) for the ultimate window management workflow. Let auto-positioning handle your startup layout, then use Window Throw for quick adjustments throughout the day.
