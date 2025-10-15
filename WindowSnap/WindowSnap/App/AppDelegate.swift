import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var windowManager: WindowManager?
    private var shortcutManager: ShortcutManager?
    private var throwController: WindowThrowController?
    private var workspaceManager: WorkspaceManager?
    private var clipboardManager: ClipboardManager?
    private var clipboardHistoryWindow: ClipboardHistoryWindow?
    private var healthCheckTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarApp()
        requestAccessibilityPermissions()
        initializeManagers()
        setupSleepWakeNotifications()
        startHealthCheck()
        
        // Initialize launch at login state
        initializeLaunchAtLogin()
        
        // Show launch at login prompt if needed (first run)
        showLaunchAtLoginPromptIfNeeded()
        
        // Set up notification observers
        setupNotificationObservers()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.unregisterAllShortcuts()
        clipboardManager?.stopMonitoring()
        removeSleepWakeNotifications()
        stopHealthCheck()
    }
    
    private func setupMenuBarApp() {
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func requestAccessibilityPermissions() {
        // Check and prompt for permissions if needed
        if !AccessibilityPermissions.hasPermissions() {
            print("⚠️ WindowSnap requires accessibility permissions to function properly.")
            print("   Prompting for permissions...")
            
            // This will show the system permission dialog
            AccessibilityPermissions.requestPermissions()
            
            // Give user time to grant permissions, then check again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !AccessibilityPermissions.hasPermissions() {
                    print("   You can also grant permissions manually via System Preferences -> Security & Privacy -> Privacy -> Accessibility")
                }
            }
        }
    }
    
    private func initializeManagers() {
        windowManager = WindowManager.shared
        shortcutManager = ShortcutManager()
        statusBarController = StatusBarController()
        throwController = WindowThrowController.shared
        workspaceManager = WorkspaceManager.shared
        clipboardManager = ClipboardManager.shared
        
        setupDefaultShortcuts()
    }
    
    private func setupDefaultShortcuts() {
        guard let shortcutManager = shortcutManager else { return }
        
        // Register window positioning shortcuts
        let defaultShortcuts = shortcutManager.getDefaultShortcuts()
        
        for (shortcut, position) in defaultShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut) { [weak self] in
                self?.handleWindowSnap(to: position)
            }
            if !success {
                print("Failed to register shortcut: \(shortcut)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register undo/redo shortcuts
        let undoRedoShortcuts = shortcutManager.getUndoRedoShortcuts()
        
        for (shortcut, action) in undoRedoShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                print("Failed to register undo/redo shortcut: \(shortcut)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register display switching shortcuts
        let displayShortcuts = shortcutManager.getDisplaySwitchingShortcuts()
        
        for (shortcut, action) in displayShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                print("Failed to register display switching shortcut: \(shortcut)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register incremental resizing shortcuts
        let resizingShortcuts = shortcutManager.getIncrementalResizingShortcuts()
        
        for (shortcut, action) in resizingShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                print("Failed to register incremental resizing shortcut: \(shortcut)")
            }
        }
        
        // RECTANGLE PRO FEATURE: Register window throw shortcut
        throwController?.registerThrowShortcut(with: shortcutManager)
        
        // CLIPBOARD HISTORY FEATURE: Register clipboard history shortcut
        let success = shortcutManager.registerGlobalShortcut("cmd+shift+v") { [weak self] in
            self?.showClipboardHistory()
        }
        if !success {
            print("Failed to register clipboard history shortcut: cmd+shift+v")
        }
        
        // Start clipboard monitoring
        clipboardManager?.startMonitoring()
        
        print("🎯 PRODUCTIVITY SHORTCUTS REGISTERED:")
        print("   ⏪ Undo: ⌘⌥Z")
        print("   ⏩ Redo: ⌘⌥⇧Z")
        print("   🖥️ Next Display: ⌃⌥⌘→")  
        print("   🖥️ Previous Display: ⌃⌥⌘←")
        print("   📏 Make Larger: ⌃⌥⇧→")
        print("   📏 Make Smaller: ⌃⌥⇧←")
        print("   🎯 Window Throw: ⌃⌥⌘Space")
        print("   📋 Clipboard History: ⌘⇧V")
    }
    
    private func handleWindowSnap(to position: GridPosition) {
        guard let windowManager = windowManager,
              let focusedWindow = windowManager.getFocusedWindow() else {
            return
        }
        
        windowManager.snapWindow(focusedWindow, to: position)
    }
    
    private func showClipboardHistory() {
        // Ensure we have a window instance and it's retained
        if clipboardHistoryWindow == nil {
            clipboardHistoryWindow = ClipboardHistoryWindow()
        }
        clipboardHistoryWindow?.showWindow()
    }
    
    // MARK: - Sleep/Wake Handling
    private func setupSleepWakeNotifications() {
        // Register for sleep notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        // Register for wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Register for screen wake notifications (additional safety)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        print("🛌 Sleep/Wake notifications registered")
    }
    
    private func removeSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc private func systemWillSleep() {
        print("💤 System going to sleep - preparing WindowSnap...")
        // Optionally pause operations or clean up resources
    }
    
    @objc private func systemDidWake() {
        print("☀️ System woke up - reinitializing WindowSnap...")
        
        // Small delay to allow system to fully wake up
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.reinitializeAfterWake()
        }
    }
    
    @objc private func screensDidWake() {
        print("🖥️ Screens woke up - checking WindowSnap status...")
        
        // Additional delay for screen wake events
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.reinitializeAfterWake()
        }
    }
    
    private func reinitializeAfterWake() {
        print("🔄 Reinitializing WindowSnap after wake...")
        
        // Check if accessibility permissions are still valid
        if !AccessibilityPermissions.hasPermissions() {
            print("⚠️ Accessibility permissions lost after wake - requesting again")
            requestAccessibilityPermissions()
            return
        }
        
        // Test if WindowManager accessibility is working
        if let windowManager = windowManager, !windowManager.testAccessibility() {
            print("🔧 WindowManager accessibility lost after wake - resetting...")
            windowManager.resetAfterWake()
        }
        
        // Check if shortcut manager is healthy, if not reinitialize it
        if let shortcutManager = shortcutManager, !shortcutManager.isHealthy() {
            print("🔧 ShortcutManager unhealthy after wake - reinitializing...")
            shortcutManager.reinitializeAfterWake()
        } else {
            // Re-register shortcuts (they may have been lost)
            print("🔧 Re-registering shortcuts after wake...")
            setupDefaultShortcuts()
        }
        
        // Reset window manager state
        windowManager = WindowManager.shared
        
        print("✅ WindowSnap reinitialized successfully after wake")
    }
    
    // MARK: - Health Check
    private func startHealthCheck() {
        // Check app health every 30 seconds
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        print("💊 Health check timer started")
    }
    
    private func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    @objc private func performHealthCheck() {
        guard let shortcutManager = shortcutManager,
              let windowManager = windowManager else { return }
        
        // Check if shortcuts are still working
        if !shortcutManager.isHealthy() {
            print("⚠️ Health check failed - ShortcutManager unhealthy - reinitializing...")
            reinitializeAfterWake()
            return
        }
        
        // Check if window manager accessibility is still working
        if !windowManager.testAccessibility() {
            print("⚠️ Health check failed - WindowManager accessibility lost - reinitializing...")
            reinitializeAfterWake()
            return
        }
        
        // Check if accessibility permissions are still valid
        if !AccessibilityPermissions.hasPermissions() {
            print("⚠️ Health check: Accessibility permissions lost")
            // Don't auto-reinitialize here as it might be annoying, just log
        }
    }
    
    // MARK: - Launch at Login
    private func initializeLaunchAtLogin() {
        // Sync the actual system state with our preferences
        let systemIsEnabled = LaunchAtLoginManager.shared.isEnabled
        let preferencesState = PreferencesManager.shared.launchAtLogin
        
        // If there's a mismatch, use the system state as the source of truth
        if systemIsEnabled != preferencesState {
            PreferencesManager.shared.launchAtLogin = systemIsEnabled
            print("🔄 Synced launch at login preference with system state: \(systemIsEnabled)")
        }
    }
    
    private func showLaunchAtLoginPromptIfNeeded() {
        // Only show on first run or if the user hasn't been prompted yet
        LaunchAtLoginPrompt.shared.showPromptIfNeeded()
        
        // Mark first run as complete
        if PreferencesManager.shared.isFirstRun {
            PreferencesManager.shared.markFirstRunComplete()
        }
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPreferencesRequested),
            name: .openPreferences,
            object: nil
        )
    }
    
    @objc private func openPreferencesRequested() {
        // Tell the status bar controller to open preferences
        statusBarController?.showPreferences()
    }
}