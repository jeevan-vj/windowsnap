import Foundation

class PreferencesManager: AccessibilityOnboardingStoring {
    static let shared = PreferencesManager()
    
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        setupDefaultPreferences()
    }
    
    private func setupDefaultPreferences() {
        let defaults: [String: Any] = [
            "LaunchAtLogin": false,
            "EnableAnimations": true,
            "AnimationDuration": 0.3,
            "DefaultMargin": 10.0,
            "HasCompletedAccessibilityOnboarding": false,
            "HasRequestedScreenRecordingPermission": false,
            "IsFirstRun": true,
            ClipboardManager.retentionDefaultsKey: ClipboardHistoryRetention.sevenDays.rawValue,
            ClipboardManager.pausedDefaultsKey: false,
            ClipboardManager.explicitRetentionChoiceDefaultsKey: false,
            ClipboardManager.migratedHistoryProtectionDefaultsKey: false
        ]
        
        userDefaults.register(defaults: defaults)
    }
    
    // MARK: - Notification Settings
    // MARK: - Launch Settings
    var launchAtLogin: Bool {
        get { userDefaults.bool(forKey: "LaunchAtLogin") }
        set { userDefaults.set(newValue, forKey: "LaunchAtLogin") }
    }
    
    // MARK: - Animation Settings
    var enableAnimations: Bool {
        get { userDefaults.bool(forKey: "EnableAnimations") }
        set { userDefaults.set(newValue, forKey: "EnableAnimations") }
    }
    
    var animationDuration: Double {
        get { userDefaults.double(forKey: "AnimationDuration") }
        set { userDefaults.set(newValue, forKey: "AnimationDuration") }
    }
    
    // MARK: - Window Settings
    var defaultMargin: CGFloat {
        get { CGFloat(userDefaults.double(forKey: "DefaultMargin")) }
        set { userDefaults.set(Double(newValue), forKey: "DefaultMargin") }
    }
    
    // MARK: - Shortcut Settings
    func getCustomShortcuts() -> [String: String] {
        return userDefaults.object(forKey: "CustomShortcuts") as? [String: String] ?? [:]
    }
    
    func setCustomShortcuts(_ shortcuts: [String: String]) {
        userDefaults.set(shortcuts, forKey: "CustomShortcuts")
    }
    
    // MARK: - First Run and Onboarding
    var isFirstRun: Bool {
        get { userDefaults.bool(forKey: "IsFirstRun") }
        set { userDefaults.set(newValue, forKey: "IsFirstRun") }
    }
    
    var accessibilityOnboardingState: AccessibilityOnboardingState {
        get {
            if let rawValue = userDefaults.string(forKey: "AccessibilityOnboardingState"),
               let state = AccessibilityOnboardingState(rawValue: rawValue) {
                return state
            }

            let migratedState: AccessibilityOnboardingState
            if userDefaults.bool(forKey: "HasCompletedAccessibilityOnboarding") {
                migratedState = .completed
            } else if !isFirstRun {
                migratedState = .presented
            } else {
                migratedState = .notPresented
            }
            userDefaults.set(migratedState.rawValue, forKey: "AccessibilityOnboardingState")
            return migratedState
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: "AccessibilityOnboardingState")
            if newValue == .completed {
                userDefaults.set(true, forKey: "HasCompletedAccessibilityOnboarding")
            }
        }
    }

    var hasRequestedScreenRecordingPermission: Bool {
        get { userDefaults.bool(forKey: "HasRequestedScreenRecordingPermission") }
        set { userDefaults.set(newValue, forKey: "HasRequestedScreenRecordingPermission") }
    }
    
    func markFirstRunComplete() {
        isFirstRun = false
    }
    
    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        setupDefaultPreferences()
    }
}
