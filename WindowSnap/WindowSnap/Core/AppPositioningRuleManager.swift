import Foundation
import AppKit

/// Manages app-specific positioning rules and automatically applies them
class AppPositioningRuleManager {
    static let shared = AppPositioningRuleManager()

    private let userDefaults = UserDefaults.standard
    private let storageKey = "WindowSnap_AppPositioningRules"
    private var rules: [AppPositioningRule] = []
    private var trackedWindows: Set<String> = [] // Track windows we've already positioned
    private var isMonitoring = false

    // Configuration
    private let positioningDelay: TimeInterval = 0.5 // Wait for window to fully appear

    private init() {
        loadRules()
    }

    // MARK: - Storage Operations

    /// Load rules from UserDefaults
    private func loadRules() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            rules = []
            print("📏 No saved app positioning rules found")
            return
        }

        do {
            rules = try JSONDecoder().decode([AppPositioningRule].self, from: data)
            print("📏 Loaded \(rules.count) app positioning rules")
        } catch {
            print("❌ Failed to load app positioning rules: \(error)")
            rules = []
        }
    }

    /// Save rules to UserDefaults
    private func saveRules() {
        do {
            let data = try JSONEncoder().encode(rules)
            userDefaults.set(data, forKey: storageKey)
            print("💾 Saved \(rules.count) app positioning rules")
        } catch {
            print("❌ Failed to save app positioning rules: \(error)")
        }
    }

    // MARK: - Rule Management (CRUD)

    /// Add a new positioning rule
    func addRule(_ rule: AppPositioningRule) {
        // Check for duplicate bundle identifier
        if rules.contains(where: { $0.bundleIdentifier == rule.bundleIdentifier && $0.windowFilter == rule.windowFilter }) {
            print("⚠️ Rule for \(rule.appName) with filter '\(rule.windowFilter.displayName)' already exists")
            return
        }

        rules.append(rule)
        saveRules()
        print("✅ Added positioning rule: \(rule.displayDescription)")
    }

    /// Remove a positioning rule
    func removeRule(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            print("❌ Rule with ID \(id) not found")
            return
        }

        let rule = rules[index]
        rules.remove(at: index)
        saveRules()
        print("🗑️ Removed positioning rule: \(rule.displayDescription)")
    }

    /// Update an existing positioning rule
    func updateRule(_ updatedRule: AppPositioningRule) {
        guard let index = rules.firstIndex(where: { $0.id == updatedRule.id }) else {
            print("❌ Rule with ID \(updatedRule.id) not found")
            return
        }

        rules[index] = updatedRule
        saveRules()
        print("📝 Updated positioning rule: \(updatedRule.displayDescription)")
    }

    /// Get all positioning rules
    func getAllRules() -> [AppPositioningRule] {
        return rules.sorted { $0.appName < $1.appName }
    }

    /// Get a positioning rule by ID
    func getRule(id: UUID) -> AppPositioningRule? {
        return rules.first { $0.id == id }
    }

    /// Get rules for a specific bundle identifier
    func getRules(forBundleId bundleId: String) -> [AppPositioningRule] {
        return rules.filter { $0.bundleIdentifier == bundleId && $0.isEnabled }
    }

    /// Toggle rule enabled/disabled state
    func toggleRule(id: UUID) {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            return
        }

        let rule = rules[index]
        rules[index] = rule.isEnabled ? rule.disabled() : rule.enabled()
        saveRules()
        print("🔄 Toggled rule: \(rules[index].displayDescription)")
    }

    /// Remove all rules
    func clearAllRules() {
        rules.removeAll()
        saveRules()
        print("🗑️ Cleared all app positioning rules")
    }

    // MARK: - Monitoring & Auto-Positioning

    /// Start monitoring for app launches and window creation
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ App positioning monitoring already active")
            return
        }

        // Listen for workspace notifications
        let workspace = NSWorkspace.shared.notificationCenter

        workspace.addObserver(
            self,
            selector: #selector(applicationDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        workspace.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        isMonitoring = true
        print("👁️ App positioning monitoring started")
    }

    /// Stop monitoring for app launches
    func stopMonitoring() {
        guard isMonitoring else { return }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.removeObserver(self)

        isMonitoring = false
        trackedWindows.removeAll()
        print("👁️ App positioning monitoring stopped")
    }

    @objc private func applicationDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        let matchingRules = getRules(forBundleId: bundleId)
        guard !matchingRules.isEmpty else { return }

        print("🚀 App launched: \(app.localizedName ?? bundleId)")

        // Wait for windows to appear before positioning
        DispatchQueue.main.asyncAfter(deadline: .now() + positioningDelay) {
            self.applyRules(for: bundleId, appName: app.localizedName ?? bundleId)
        }
    }

    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        let matchingRules = getRules(forBundleId: bundleId)
        guard !matchingRules.isEmpty else { return }

        // Check for new windows
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.checkForNewWindows(bundleId: bundleId, appName: app.localizedName ?? bundleId)
        }
    }

    /// Apply positioning rules for a specific app
    private func applyRules(for bundleId: String, appName: String) {
        let matchingRules = getRules(forBundleId: bundleId)
        guard !matchingRules.isEmpty else { return }

        let allWindows = WindowManager.shared.getAllWindows()
        let appWindows = allWindows.filter { window in
            // Match by app name since we might not have bundle ID in WindowInfo
            window.applicationName == appName
        }.sorted { $0.windowTitle < $1.windowTitle } // Consistent ordering

        guard !appWindows.isEmpty else {
            print("⚠️ No windows found for \(appName)")
            return
        }

        print("📏 Applying \(matchingRules.count) rule(s) to \(appWindows.count) window(s) for \(appName)")

        for (index, window) in appWindows.enumerated() {
            let windowId = getWindowIdentifier(window)

            // Skip if we've already positioned this window
            if trackedWindows.contains(windowId) {
                continue
            }

            // Apply matching rules
            for rule in matchingRules {
                let isFirstWindow = (index == 0)

                if rule.shouldApply(to: window, isFirstWindow: isFirstWindow) {
                    applyRule(rule, to: window)
                    trackedWindows.insert(windowId)

                    // Mark rule as used
                    if var updatedRule = getRule(id: rule.id) {
                        updatedRule.markAsUsed()
                        updateRule(updatedRule)
                    }
                }
            }
        }
    }

    /// Check for new windows that haven't been positioned yet
    private func checkForNewWindows(bundleId: String, appName: String) {
        let matchingRules = getRules(forBundleId: bundleId)
        guard !matchingRules.isEmpty else { return }

        let allWindows = WindowManager.shared.getAllWindows()
        let appWindows = allWindows.filter { $0.applicationName == appName }

        for window in appWindows {
            let windowId = getWindowIdentifier(window)

            // Only process windows we haven't seen before
            if !trackedWindows.contains(windowId) {
                for rule in matchingRules {
                    // For new windows, consider them as "first" if this is the only untracked window
                    let untrackedCount = appWindows.filter { !trackedWindows.contains(getWindowIdentifier($0)) }.count
                    let isFirstWindow = (untrackedCount == 1)

                    if rule.shouldApply(to: window, isFirstWindow: isFirstWindow) {
                        applyRule(rule, to: window)
                        trackedWindows.insert(windowId)

                        if var updatedRule = getRule(id: rule.id) {
                            updatedRule.markAsUsed()
                            updateRule(updatedRule)
                        }
                    }
                }
            }
        }
    }

    /// Apply a specific rule to a window
    private func applyRule(_ rule: AppPositioningRule, to window: WindowInfo) {
        guard let targetScreen = rule.getTargetScreen() else {
            print("❌ Could not get target screen for rule")
            return
        }

        print("📏 Applying rule to '\(window.windowTitle)': \(rule.positionType.displayName)")

        // Calculate target frame based on position type
        let targetFrame: CGRect

        switch rule.positionType {
        case .gridPosition(let gridPos):
            targetFrame = GridCalculator.shared.calculateFrame(for: gridPos, on: targetScreen)

        case .customPosition(let customPosId):
            // Look up custom position
            if let customPos = getCustomPosition(id: customPosId) {
                targetFrame = customPos.calculateFrame(for: targetScreen)
            } else {
                print("⚠️ Custom position \(customPosId) not found, centering instead")
                targetFrame = GridCalculator.shared.calculateFrame(for: .center, on: targetScreen)
            }

        case .maximize:
            targetFrame = targetScreen.visibleFrame

        case .center:
            targetFrame = GridCalculator.shared.calculateFrame(for: .center, on: targetScreen)
        }

        // Apply the position
        WindowManager.shared.moveAndResizeWindow(window, to: targetFrame)

        print("✅ Positioned '\(window.windowTitle)' to \(rule.positionType.displayName)")
    }

    /// Get window identifier for tracking
    private func getWindowIdentifier(_ window: WindowInfo) -> String {
        return "\(window.applicationName)_\(window.windowTitle)_\(window.processID)"
    }

    /// Get custom position by ID (placeholder - will integrate with CustomPosition manager)
    private func getCustomPosition(id: UUID) -> CustomPosition? {
        // TODO: Integrate with CustomPositionManager when available
        // For now, return nil
        return nil
    }

    // MARK: - Manual Application

    /// Manually apply rules to currently running apps
    func applyRulesToRunningApps() {
        print("📏 Manually applying rules to all running apps...")

        let runningApps = NSWorkspace.shared.runningApplications
        var appliedCount = 0

        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  let appName = app.localizedName else {
                continue
            }

            let matchingRules = getRules(forBundleId: bundleId)
            if !matchingRules.isEmpty {
                applyRules(for: bundleId, appName: appName)
                appliedCount += 1
            }
        }

        print("✅ Applied rules to \(appliedCount) running apps")
    }

    /// Clear tracked windows (useful for re-applying rules)
    func resetTracking() {
        trackedWindows.removeAll()
        print("🔄 Cleared window tracking - rules will re-apply on next activation")
    }

    // MARK: - Preset Management

    /// Import common presets
    func importCommonPresets() {
        for preset in AppPositioningRule.commonPresets {
            // Only add if not already present
            if !rules.contains(where: { $0.bundleIdentifier == preset.bundleIdentifier }) {
                addRule(preset)
            }
        }
        print("✅ Imported common presets")
    }

    /// Export rules to JSON string
    func exportRules() -> String? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(rules)
            return String(data: data, encoding: .utf8)
        } catch {
            print("❌ Failed to export rules: \(error)")
            return nil
        }
    }

    /// Import rules from JSON string
    func importRules(from jsonString: String, merge: Bool = true) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            print("❌ Invalid JSON string")
            return false
        }

        do {
            let importedRules = try JSONDecoder().decode([AppPositioningRule].self, from: data)

            if merge {
                // Merge with existing rules (avoid duplicates)
                for rule in importedRules {
                    if !rules.contains(where: { $0.bundleIdentifier == rule.bundleIdentifier }) {
                        rules.append(rule)
                    }
                }
            } else {
                // Replace all rules
                rules = importedRules
            }

            saveRules()
            print("✅ Imported \(importedRules.count) rules")
            return true
        } catch {
            print("❌ Failed to import rules: \(error)")
            return false
        }
    }

    // MARK: - Statistics

    /// Get statistics about rule usage
    func getStatistics() -> RuleStatistics {
        let totalRules = rules.count
        let enabledRules = rules.filter { $0.isEnabled }.count
        let disabledRules = totalRules - enabledRules
        let rulesWithUsage = rules.filter { $0.lastUsed != nil }.count

        let appCounts = Dictionary(grouping: rules, by: { $0.bundleIdentifier })
            .mapValues { $0.count }

        return RuleStatistics(
            totalRules: totalRules,
            enabledRules: enabledRules,
            disabledRules: disabledRules,
            rulesWithUsage: rulesWithUsage,
            uniqueApps: appCounts.count,
            mostRuledApp: appCounts.max(by: { $0.value < $1.value })?.key
        )
    }

    struct RuleStatistics {
        let totalRules: Int
        let enabledRules: Int
        let disabledRules: Int
        let rulesWithUsage: Int
        let uniqueApps: Int
        let mostRuledApp: String?

        var description: String {
            var desc = "📊 Rule Statistics:\n"
            desc += "  Total Rules: \(totalRules)\n"
            desc += "  Enabled: \(enabledRules)\n"
            desc += "  Disabled: \(disabledRules)\n"
            desc += "  Used: \(rulesWithUsage)\n"
            desc += "  Unique Apps: \(uniqueApps)"
            if let app = mostRuledApp {
                desc += "\n  Most Rules: \(app)"
            }
            return desc
        }
    }
}
