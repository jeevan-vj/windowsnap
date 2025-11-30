import Foundation

class PreferencesManager {
    static let shared = PreferencesManager()
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        setupDefaultPreferences()
    }
    
    private func setupDefaultPreferences() {
        let defaults: [String: Any] = [
            "ShowNotifications": true,
            "LaunchAtLogin": false,
            "EnableAnimations": true,
            "AnimationDuration": 0.3,
            "DefaultMargin": 10.0,
            "HasShownLaunchAtLoginPrompt": false,
            "IsFirstRun": true,
            "EnableHapticFeedback": true,
            "PlaySoundOnSnap": false,
            "WindowPadding": 0.0,
            "ScreenEdgePadding": 0.0
        ]
        
        userDefaults.register(defaults: defaults)
    }
    
    // MARK: - Notification Settings
    var showNotifications: Bool {
        get { userDefaults.bool(forKey: "ShowNotifications") }
        set { userDefaults.set(newValue, forKey: "ShowNotifications") }
    }
    
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
    
    var windowPadding: CGFloat {
        get { CGFloat(userDefaults.double(forKey: "WindowPadding")) }
        set { userDefaults.set(Double(newValue), forKey: "WindowPadding") }
    }
    
    var screenEdgePadding: CGFloat {
        get { CGFloat(userDefaults.double(forKey: "ScreenEdgePadding")) }
        set { userDefaults.set(Double(newValue), forKey: "ScreenEdgePadding") }
    }
    
    // MARK: - Feedback Settings
    var enableHapticFeedback: Bool {
        get { userDefaults.bool(forKey: "EnableHapticFeedback") }
        set { userDefaults.set(newValue, forKey: "EnableHapticFeedback") }
    }
    
    var playSoundOnSnap: Bool {
        get { userDefaults.bool(forKey: "PlaySoundOnSnap") }
        set { userDefaults.set(newValue, forKey: "PlaySoundOnSnap") }
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
    
    var hasShownLaunchAtLoginPrompt: Bool {
        get { userDefaults.bool(forKey: "HasShownLaunchAtLoginPrompt") }
        set { userDefaults.set(newValue, forKey: "HasShownLaunchAtLoginPrompt") }
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