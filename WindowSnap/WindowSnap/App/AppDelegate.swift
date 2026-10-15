import AppKit
import Foundation

extension Notification.Name {
    static let openPreferences = Notification.Name("openPreferences")
    static let builtInShortcutsDidChange = Notification.Name("builtInShortcutsDidChange")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var windowManager: WindowManager?
    private var shortcutManager: ShortcutManager?
    private var throwController: WindowThrowController?
    private var workspaceManager: WorkspaceManager?
    private var clipboardManager: ClipboardManager?
    private var snippetPickerWindow: SnippetPickerWindow?
    private var textExpanderManager: TextExpanderManager?
    private var textExpansionEngine: TextExpansionEngine?
    private var accessibilityOnboardingWindow: AccessibilityOnboardingWindowController?
    private var healthCheckTimer: Timer?
    private var lastAccessibilityReminderDate: Date?
    private var pendingWakeRecovery: DispatchWorkItem?
    private var isRecoveringFromWake = false
    private var regionShareController: RegionShareController?
    private var accessibilityAvailable = false
    private let accessibilityReminderInterval: TimeInterval = 60
    private let healthCheckInterval: TimeInterval = 30
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        ScreenRecordingPermissions.logDiagnostics(reason: "launch")
        setupMenuBarApp()
        configureShortcutDefaults()
        initializeManagers()
        accessibilityAvailable = AccessibilityPermissions.hasPermissions()
        setupSleepWakeNotifications()
        startHealthCheck()
        
        // Initialize launch at login state
        initializeLaunchAtLogin()
        
        // Set up notification observers
        setupNotificationObservers()

        // Explain Accessibility once. Optional permissions remain feature-triggered.
        _ = setupAccessibilityOnboarding()
        if PreferencesManager.shared.isFirstRun {
            PreferencesManager.shared.markFirstRunComplete()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.unregisterAllShortcuts()
        clipboardManager?.stopMonitoring()
        textExpansionEngine?.stop()
        regionShareController?.stopVirtualCameraShare()
        VirtualDisplayController.shared.disconnect()
        removeSleepWakeNotifications()
        NotificationCenter.default.removeObserver(self)
        stopHealthCheck()
    }
    
    private func setupMenuBarApp() {
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func initializeManagers() {
        windowManager = WindowManager.shared
        shortcutManager = ShortcutManager()
        ShortcutManager.active = shortcutManager
        statusBarController = StatusBarController()
        throwController = MainActor.assumeIsolated { WindowThrowController.shared }
        workspaceManager = WorkspaceManager.shared
        clipboardManager = ClipboardManager.shared
        textExpanderManager = TextExpanderManager.shared
        textExpansionEngine = TextExpansionEngine.shared
        
        setupDefaultShortcuts()
        setupTextExpander()
    }

    private func configureShortcutDefaults() {
        let preferences = PreferencesManager.shared
        preferences.prepareBuiltInShortcuts()
        guard !preferences.hasChosenShortcutDefaults else { return }

        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard preferences.isFirstRun, !isRunningTests, !preferences.hasCustomizedBuiltInShortcuts else {
            preferences.markShortcutDefaultsChoiceHandled()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Choose Window Shortcuts"
        alert.informativeText = "Rectangle-style Control–Option shortcuts avoid common text-editing commands."
        alert.addButton(withTitle: "Use Rectangle-style ⌃⌥")
        alert.addButton(withTitle: "Keep Legacy ⌘⇧")
        preferences.chooseShortcutDefaults(keepLegacy: alert.runModal() == .alertSecondButtonReturn)
    }

    @discardableResult
    private func setupAccessibilityOnboarding() -> Bool {
        let model = AccessibilityOnboardingModel(
            permissionProvider: AccessibilityPermissions.shared,
            store: PreferencesManager.shared
        )
        let controller = AccessibilityOnboardingWindowController(model: model)
        accessibilityOnboardingWindow = controller
        statusBarController?.onShowAccessibilitySetup = { [weak self] in
            self?.accessibilityOnboardingWindow?.present()
        }
        statusBarController?.onAccessibilityRequired = { [weak self] in
            self?.showAccessibilityReminderIfAllowed()
        }
        let didPresent = controller.presentIfNeeded()
        if didPresent {
            lastAccessibilityReminderDate = Date()
        }
        return didPresent
    }
    
    private func setupTextExpander() {
        let state = TextExpanderRuntimeController.shared.reconcile()
        AppLog.textExpansion.info("Text Expander runtime state: \(state.statusText, privacy: .public)")
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        accessibilityAvailable = AccessibilityPermissions.hasPermissions()
        TextExpanderRuntimeController.shared.reconcile()
        accessibilityOnboardingWindow?.refreshPermissionStatus()
        statusBarController?.refreshPermissionState()
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
                AppLog.shortcuts.error("Failed to register shortcut: \(shortcut, privacy: .public)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register undo/redo shortcuts
        let undoRedoShortcuts = shortcutManager.getUndoRedoShortcuts()
        
        for (shortcut, action) in undoRedoShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                AppLog.shortcuts.error("Failed to register undo/redo shortcut: \(shortcut, privacy: .public)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register display switching shortcuts
        let displayShortcuts = shortcutManager.getDisplaySwitchingShortcuts()
        
        for (shortcut, action) in displayShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                AppLog.shortcuts.error("Failed to register display switching shortcut: \(shortcut, privacy: .public)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register incremental resizing shortcuts
        let resizingShortcuts = shortcutManager.getIncrementalResizingShortcuts()
        
        for (shortcut, action) in resizingShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                AppLog.shortcuts.error("Failed to register incremental resizing shortcut: \(shortcut, privacy: .public)")
            }
        }
        
        // RECTANGLE PRO FEATURE: Register window throw shortcut
        MainActor.assumeIsolated {
            throwController?.registerThrowShortcut(with: shortcutManager)
        }
        
        // CLIPBOARD HISTORY FEATURE: Register clipboard history shortcut
        let success = shortcutManager.registerGlobalShortcut("cmd+shift+v") {
            ClipboardHistoryPresenter.shared.toggle()
        }
        if !success {
            AppLog.shortcuts.error("Failed to register clipboard history shortcut")
        }

        let snippetPickerSuccess = shortcutManager.registerGlobalShortcut("cmd+shift+;") { [weak self] in
            self?.showSnippetPicker()
        }
        if !snippetPickerSuccess {
            AppLog.shortcuts.error("Failed to register snippet picker shortcut")
        }
        
        // Start clipboard monitoring
        clipboardManager?.startMonitoring()
        
        // REGION SHARE FEATURE: Register region share shortcut
        MainActor.assumeIsolated {
            regionShareController = RegionShareController.shared
            regionShareController?.registerShortcut(with: shortcutManager)
        }

        // User-defined shortcuts register after built-ins so conflicts are reported
        // without displacing the app's documented defaults.
        CustomPositionManager.shared.configure(shortcutManager: shortcutManager)
        workspaceManager?.configure(shortcutManager: shortcutManager)
        
        AppLog.shortcuts.info("Default productivity shortcuts registered")
    }
    
    private func handleWindowSnap(to position: GridPosition) {
        guard AccessibilityPermissions.hasPermissions() else {
            accessibilityAvailable = false
            showAccessibilityReminderIfAllowed()
            return
        }

        guard let windowManager = windowManager,
              let focusedWindow = windowManager.getFocusedWindow() else {
            if !AccessibilityPermissions.hasPermissions() {
                accessibilityAvailable = false
                showAccessibilityReminderIfAllowed()
            }
            return
        }
        
        windowManager.snapWindow(focusedWindow, to: position)
    }

    private func showSnippetPicker() {
        if snippetPickerWindow == nil {
            snippetPickerWindow = SnippetPickerWindow()
            snippetPickerWindow?.onSnippetSelected = { [weak self] snippet, targetApp in
                self?.textExpansionEngine?.performExpansion(snippet: snippet, targetApp: targetApp)
            }
        }

        if snippetPickerWindow?.isVisible == true {
            snippetPickerWindow?.orderOut(nil)
            return
        }

        snippetPickerWindow?.presentNearMouse()
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

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceEnvironmentDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        
        AppLog.app.debug("Workspace notifications registered")
    }
    
    private func removeSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
    
    @objc private func systemWillSleep() {
        AppLog.app.info("System going to sleep")
        pendingWakeRecovery?.cancel()
        pendingWakeRecovery = nil
    }
    
    @objc private func systemDidWake() {
        AppLog.app.info("System woke; scheduling recovery")
        performHealthCheck()
        scheduleWakeRecovery(delay: 1.0)
    }
    
    @objc private func screensDidWake() {
        AppLog.app.info("Screens woke; scheduling recovery")
        performHealthCheck()
        scheduleWakeRecovery(delay: 1.5)
    }

    @objc private func workspaceEnvironmentDidChange() {
        performHealthCheck()
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
            AppLog.app.debug("Wake recovery already in progress")
            return
        }
        
        isRecoveringFromWake = true
        defer { isRecoveringFromWake = false }
        
        AppLog.app.info("Reinitializing after wake")
        
        accessibilityAvailable = AccessibilityPermissions.hasPermissions()
        if !accessibilityAvailable {
            AppLog.accessibility.warning("Accessibility permission unavailable after wake")
        }
        accessibilityOnboardingWindow?.refreshPermissionStatus()
        
        if accessibilityAvailable, let windowManager = windowManager, !windowManager.testAccessibility() {
            AppLog.accessibility.warning("Window manager accessibility unavailable after wake; resetting")
            windowManager.resetAfterWake()
        }
        
        if let shortcutManager = shortcutManager {
            AppLog.shortcuts.info("Reinitializing shortcuts after wake")
            shortcutManager.reinitializeAfterWake()
        }
        
        if TextExpanderRuntimeController.shared.state == .running {
            AppLog.textExpansion.info("Reinitializing text expander after wake")
            textExpansionEngine?.restart()
        }
        
        MainActor.assumeIsolated {
            regionShareController?.recoverVirtualCameraAfterWake()
        }
        VirtualDisplayController.shared.recoverAfterWake()
        windowManager = WindowManager.shared
        
        AppLog.app.info("Wake recovery completed")
    }
    
    // MARK: - Health Check
    private func startHealthCheck() {
        let timer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
        timer.tolerance = healthCheckInterval * 0.15
        healthCheckTimer = timer
        AppLog.app.info("Health check timer started")
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
            AppLog.shortcuts.warning("Health check failed; scheduling shortcut recovery")
            scheduleWakeRecovery(delay: 0.5)
            return
        }
        
        if !AccessibilityPermissions.hasPermissions() {
            accessibilityAvailable = false
            return
        }

        accessibilityAvailable = true

        if !windowManager.testAccessibility() {
            AppLog.accessibility.warning("Health check found accessibility unavailable; scheduling recovery")
            scheduleWakeRecovery(delay: 0.5)
            return
        }
        
    }

    // MARK: - Launch at Login
    private func initializeLaunchAtLogin() {
        // Read-only synchronization: launching WindowSnap never registers a login item.
        let status = LaunchAtLoginManager.shared.refreshStatus()
        AppLog.app.info("Synchronized launch-at-login state: \(String(describing: status), privacy: .public)")
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openPreferencesRequested),
            name: .openPreferences,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(builtInShortcutsChanged),
            name: .builtInShortcutsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersDidChange() {
        performHealthCheck()
    }

    private func showAccessibilityReminderIfAllowed() {
        guard accessibilityOnboardingWindow?.window?.isVisible != true else { return }

        let now = Date()
        if let lastAccessibilityReminderDate,
           now.timeIntervalSince(lastAccessibilityReminderDate) < accessibilityReminderInterval {
            return
        }

        lastAccessibilityReminderDate = now
        accessibilityOnboardingWindow?.present()
    }

    @objc private func builtInShortcutsChanged() {
        shortcutManager?.unregisterAllShortcuts()
        setupDefaultShortcuts()
    }
    
    @objc private func openPreferencesRequested() {
        // Tell the status bar controller to open preferences
        statusBarController?.showPreferences()
    }
}
