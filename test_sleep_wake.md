# Sleep/Wake Testing Guide for WindowSnap

## What Was Fixed

The issue where WindowSnap stops working after the Mac wakes up from sleep has been addressed with the following improvements:

### 1. Sleep/Wake Notification Handling
- Added `NSWorkspace.willSleepNotification` and `NSWorkspace.didWakeNotification` listeners
- Added `NSWorkspace.screensDidWakeNotification` for additional safety
- Proper cleanup of notification observers on app termination

### 2. Automatic Reinitialization
- **Accessibility Permissions Check**: Verifies and prompts if permissions are lost
- **Shortcut Re-registration**: Rebuilds global shortcuts that may have been lost
- **WindowManager Reset**: Refreshes window management connections
- **Event Handler Rebuild**: Recreates Carbon event handlers for shortcuts

### 3. Health Check System
- **Periodic Health Checks**: Every 30 seconds, the app checks if shortcuts and accessibility are working
- **Proactive Detection**: Automatically detects and fixes issues before users notice
- **Smart Recovery**: Only reinitializes what's actually broken

### 4. Enhanced ShortcutManager
- **State Validation**: `isHealthy()` method to check if shortcuts are still registered
- **Smart Reinitialization**: `reinitializeAfterWake()` preserves current shortcuts and re-registers them
- **Robust Event Handling**: Rebuilds Carbon event handlers after wake

### 5. Enhanced WindowManager  
- **Accessibility Testing**: `testAccessibility()` method to verify window control still works
- **Connection Validation**: Checks if AX API connections are still valid
- **State Recovery**: `resetAfterWake()` method for future enhancements

## How to Test

### Test Case 1: Basic Sleep/Wake Recovery
1. Launch WindowSnap and ensure shortcuts work (e.g., Cmd+Shift+Left to snap window left)
2. Put your Mac to sleep (Apple menu > Sleep or close laptop lid)
3. Wait at least 30 seconds
4. Wake up your Mac
5. Wait 2-3 seconds for reinitialization (check Console app for WindowSnap logs)
6. Test shortcuts again - they should work immediately

### Test Case 2: Extended Sleep Test
1. Ensure WindowSnap is working
2. Put Mac to sleep for several hours (overnight test)
3. Wake up Mac
4. Test shortcuts - should recover automatically

### Test Case 3: Screen Sleep vs System Sleep
1. Test with just screen sleep (System Preferences > Energy Saver > Display sleep)
2. Test with full system sleep
3. Both should trigger recovery mechanisms

### Expected Log Messages

When working correctly, you should see these messages in Console.app (filter by "WindowSnap"):

**On App Launch:**
```
🛌 Sleep/Wake notifications registered
💊 Health check timer started
🎯 PRODUCTIVITY SHORTCUTS REGISTERED
```

**On Sleep:**
```
💤 System going to sleep - preparing WindowSnap...
```

**On Wake:**
```
☀️ System woke up - reinitializing WindowSnap...
🔄 Reinitializing WindowSnap after wake...
🔧 Re-registering shortcuts after wake...
✅ WindowSnap reinitialized successfully after wake
```

**During Health Checks (every 30 seconds):**
```
⚠️ Health check failed - reinitializing WindowSnap... (only if problems detected)
```

## Monitoring Health

To monitor WindowSnap's health:

1. **Console App**: 
   - Open Console.app
   - Search for "WindowSnap" 
   - Watch for reinitialization messages

2. **Activity Monitor**:
   - Check that WindowSnap process is still running
   - Should have minimal CPU usage except during wake events

3. **Manual Testing**:
   - Try window snapping shortcuts periodically
   - Check if menu bar icon is still responsive

## Troubleshooting

If WindowSnap still doesn't work after wake:

1. **Check Accessibility Permissions**:
   - System Preferences > Security & Privacy > Privacy > Accessibility
   - Ensure WindowSnap is checked and enabled

2. **Manual Restart**:
   - Quit WindowSnap (right-click menu bar icon > Quit)
   - Relaunch from Applications folder

3. **Check Logs**:
   - Look for error messages in Console.app
   - Watch for permission or registration failures

## Technical Details

The solution implements a multi-layered approach:

1. **Immediate Response**: Sleep/wake notifications trigger immediate reinitialization
2. **Delayed Recovery**: Additional delays account for system stabilization after wake
3. **Health Monitoring**: Continuous monitoring catches edge cases
4. **Granular Recovery**: Only fixes what's actually broken, avoiding unnecessary restarts

This should completely resolve the sleep/wake issue while maintaining excellent performance and user experience.
