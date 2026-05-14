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
    private var textExpanderManager: TextExpanderManager?
    private var textExpansionEngine: TextExpansionEngine?
    private var healthCheckTimer: Timer?
    private var pendingWakeRecovery: DispatchWorkItem?
    private var isRecoveringFromWake = false
    @available(macOS 12.3, *)
    private var regionShareController: RegionShareController? {
        get { _regionShareController as? RegionShareController }
        set { _regionShareController = newValue }
    }
    private var _regionShareController: AnyObject?
    
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
        
        // Check screen recording permission status
        checkScreenRecordingPermissionOnLaunch()
    }
    
    private func checkScreenRecordingPermissionOnLaunch() {
        if #available(macOS 12.3, *) {
            ScreenRecordingPermissions.checkPermissionStatusOnLaunch()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.unregisterAllShortcuts()
        clipboardManager?.stopMonitoring()
        textExpansionEngine?.stop()
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
        textExpanderManager = TextExpanderManager.shared
        textExpansionEngine = TextExpansionEngine.shared
        
        setupDefaultShortcuts()
        setupTextExpander()
    }
    
    private func setupTextExpander() {
        guard let textExpanderManager = textExpanderManager else { return }
        
        if textExpanderManager.isEnabled {
            if InputMonitoringPermissions.hasPermissions() {
                textExpansionEngine?.start()
                print("📝 Text Expander initialized and running")
            } else {
                print("⚠️ Text Expander disabled - Input Monitoring permission required")
            }
        } else {
            print("📝 Text Expander is disabled in settings")
        }
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
        
        // REGION SHARE FEATURE: Register region share shortcut
        if #available(macOS 12.3, *) {
            regionShareController = RegionShareController.shared
            regionShareController?.registerShortcut(with: shortcutManager)
        }
        
        print("🎯 PRODUCTIVITY SHORTCUTS REGISTERED:")
        print("   ⏪ Undo: ⌘⌥Z")
        print("   ⏩ Redo: ⌘⌥⇧Z")
        print("   🖥️ Next Display: ⌃⌥⌘→")  
        print("   🖥️ Previous Display: ⌃⌥⌘←")
        print("   📏 Make Larger: ⌃⌥⇧→")
        print("   📏 Make Smaller: ⌃⌥⇧←")
        print("   🎯 Window Throw: ⌃⌥⌘Space")
        print("   📋 Clipboard History: ⌘⇧V")
        print("   📺 Region Share: ⌃⌘R")
        print("   📝 Text Expander: Type trigger + Tab")
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
        pendingWakeRecovery?.cancel()
        pendingWakeRecovery = nil
    }
    
    @objc private func systemDidWake() {
        print("☀️ System woke up - scheduling WindowSnap recovery...")
        scheduleWakeRecovery(delay: 1.0)
    }
    
    @objc private func screensDidWake() {
        print("🖥️ Screens woke up - scheduling WindowSnap recovery...")
        scheduleWakeRecovery(delay: 1.5)
    }
    
    private func scheduleWakeRecovery(delay: TimeInterval) {
        pendingWakeRecovery?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.reinitializeAfterWake()
        }
        pendingWakeRecovery = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    private func reinitializeAfterWake() {
        guard !isRecoveringFromWake else {
            print("⏳ Wake recovery already in progress, skipping...")
            return
        }
        
        isRecoveringFromWake = true
        defer { isRecoveringFromWake = false }
        
        print("🔄 Reinitializing WindowSnap after wake...")
        
        if !AccessibilityPermissions.hasPermissions() {
            print("⚠️ Accessibility permissions lost after wake - requesting again")
            requestAccessibilityPermissions()
        }
        
        if let windowManager = windowManager, !windowManager.testAccessibility() {
            print("🔧 WindowManager accessibility lost after wake - resetting...")
            windowManager.resetAfterWake()
        }
        
        if let shortcutManager = shortcutManager {
            print("🔧 Reinitializing shortcuts after wake...")
            shortcutManager.reinitializeAfterWake()
        }
        
        if textExpanderManager?.isEnabled == true {
            print("🔧 Reinitializing text expander after wake...")
            textExpansionEngine?.restart()
        }
        
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
        guard !isRecoveringFromWake else { return }
        
        guard let shortcutManager = shortcutManager,
              let windowManager = windowManager else { return }
        
        if !shortcutManager.isHealthy() {
            print("⚠️ Health check failed - ShortcutManager unhealthy - reinitializing...")
            scheduleWakeRecovery(delay: 0.5)
            return
        }
        
        if !windowManager.testAccessibility() {
            print("⚠️ Health check failed - WindowManager accessibility lost - reinitializing...")
            scheduleWakeRecovery(delay: 0.5)
            return
        }
        
        if !AccessibilityPermissions.hasPermissions() {
            print("⚠️ Health check: Accessibility permissions lost")
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