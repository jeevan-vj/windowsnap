import Foundation

/// Manages storage and operations for text expansion snippets
final class TextExpanderManager {
    static let shared = TextExpanderManager()

    private let snippetsStorageKey = "WindowSnap_TextExpanderSnippets"
    private let settingsStorageKey = "WindowSnap_TextExpanderSettings"
    private let hasPopulatedDefaultsKey = "WindowSnap_TextExpanderHasPopulatedDefaults"
    private let usageStatsStorageKey = "WindowSnap_TextExpanderUsageStats"

    private let lock = NSLock()
    private var snippets: [TextExpansionSnippet] = []
    private(set) var settings: TextExpanderSettings = .default
    private(set) var usageStats: UsageStats = UsageStats()
    private var matchingCache: [TextExpansionSnippet]?
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadSnippets()
        loadSettings()
        loadUsageStats()
        populateDefaultSnippetsIfNeeded()
    }

    private func invalidateMatchingCache() {
        matchingCache = nil
    }

    private func rebuildMatchingCacheLocked() -> [TextExpansionSnippet] {
        if let matchingCache {
            return matchingCache
        }
        let cache = snippets
            .filter(\.isEnabled)
            .sorted { $0.trigger.count > $1.trigger.count }
        matchingCache = cache
        return cache
    }

    private func loadSnippets() {
        guard let data = userDefaults.data(forKey: snippetsStorageKey) else {
            snippets = []
            return
        }

        do {
            snippets = try JSONDecoder().decode([TextExpansionSnippet].self, from: data)
            AppLog.textExpansion.info("Loaded \(self.snippets.count, privacy: .public) text expansion snippets")
        } catch {
            AppLog.textExpansion.error("Failed to load text expansion snippets: \(error.localizedDescription, privacy: .public)")
            snippets = []
        }
    }

    private func saveSnippets() {
        do {
            let data = try JSONEncoder().encode(snippets)
            userDefaults.set(data, forKey: snippetsStorageKey)
            AppLog.textExpansion.info("Saved \(self.snippets.count, privacy: .public) text expansion snippets")
        } catch {
            AppLog.textExpansion.error("Failed to save text expansion snippets: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadSettings() {
        guard let data = userDefaults.data(forKey: settingsStorageKey) else {
            settings = .default
            return
        }

        do {
            settings = try JSONDecoder().decode(TextExpanderSettings.self, from: data)
            AppLog.textExpansion.debug("Loaded text expander settings")
        } catch {
            AppLog.textExpansion.error("Failed to load text expander settings: \(error.localizedDescription, privacy: .public)")
            settings = .default
        }
    }

    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsStorageKey)
            invalidateMatchingCache()
            AppLog.textExpansion.debug("Saved text expander settings")
        } catch {
            AppLog.textExpansion.error("Failed to save text expander settings: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadUsageStats() {
        guard let data = userDefaults.data(forKey: usageStatsStorageKey) else {
            usageStats = UsageStats()
            return
        }

        do {
            usageStats = try JSONDecoder().decode(UsageStats.self, from: data)
        } catch {
            AppLog.textExpansion.error("Failed to load usage stats: \(error.localizedDescription, privacy: .public)")
            usageStats = UsageStats()
        }
    }

    private func saveUsageStats() {
        do {
            let data = try JSONEncoder().encode(usageStats)
            userDefaults.set(data, forKey: usageStatsStorageKey)
        } catch {
            AppLog.textExpansion.error("Failed to save usage stats: \(error.localizedDescription, privacy: .public)")
        }
    }

    func recordExpansion(trigger: String, replacement: String) {
        lock.lock()
        usageStats = usageStats.recording(trigger: trigger, replacement: replacement)
        lock.unlock()
        saveUsageStats()
    }

    func getUsageStats() -> UsageStats {
        lock.lock()
        defer { lock.unlock() }
        return usageStats
    }

    // MARK: - Settings Management

    var isEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return settings.isEnabled
        }
        set {
            lock.lock()
            settings.isEnabled = newValue
            lock.unlock()
            saveSettings()
        }
    }

    func updateSettings(_ newSettings: TextExpanderSettings) {
        lock.lock()
        settings = newSettings
        lock.unlock()
        saveSettings()
    }

    // MARK: - Snippet Management

    func addSnippet(_ snippet: TextExpansionSnippet) -> Bool {
        guard validateTrigger(snippet.trigger) else {
            AppLog.textExpansion.warning("Invalid trigger rejected")
            return false
        }

        lock.lock()
        if snippets.contains(where: { $0.trigger == snippet.trigger }) {
            lock.unlock()
            AppLog.textExpansion.warning("Duplicate trigger rejected")
            return false
        }

        snippets.append(snippet)
        invalidateMatchingCache()
        lock.unlock()
        saveSnippets()
        AppLog.textExpansion.info("Added text expansion snippet")
        return true
    }

    func removeSnippet(id: UUID) -> Bool {
        lock.lock()
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            AppLog.textExpansion.error("Snippet not found for removal")
            return false
        }

        snippets.remove(at: index)
        invalidateMatchingCache()
        lock.unlock()
        saveSnippets()
        AppLog.textExpansion.info("Removed text expansion snippet")
        return true
    }

    func updateSnippet(_ updatedSnippet: TextExpansionSnippet) -> Bool {
        lock.lock()
        guard let index = snippets.firstIndex(where: { $0.id == updatedSnippet.id }) else {
            lock.unlock()
            AppLog.textExpansion.error("Snippet not found for update")
            return false
        }

        if updatedSnippet.trigger != snippets[index].trigger {
            guard validateTrigger(updatedSnippet.trigger) else {
                lock.unlock()
                AppLog.textExpansion.warning("Invalid trigger rejected on update")
                return false
            }

            if snippets.contains(where: { $0.trigger == updatedSnippet.trigger && $0.id != updatedSnippet.id }) {
                lock.unlock()
                AppLog.textExpansion.warning("Duplicate trigger rejected on update")
                return false
            }
        }

        snippets[index] = updatedSnippet
        invalidateMatchingCache()
        lock.unlock()
        saveSnippets()
        AppLog.textExpansion.info("Updated text expansion snippet")
        return true
    }

    func toggleSnippetEnabled(id: UUID) -> Bool {
        lock.lock()
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return false
        }

        snippets[index].update(isEnabled: !snippets[index].isEnabled)
        invalidateMatchingCache()
        lock.unlock()
        saveSnippets()
        return true
    }

    func getAllSnippets() -> [TextExpansionSnippet] {
        lock.lock()
        defer { lock.unlock() }
        return snippets.sorted { $0.trigger < $1.trigger }
    }

    func getEnabledSnippets() -> [TextExpansionSnippet] {
        lock.lock()
        defer { lock.unlock() }
        return snippets.filter { $0.isEnabled }.sorted { $0.trigger < $1.trigger }
    }

    func getSnippet(id: UUID) -> TextExpansionSnippet? {
        lock.lock()
        defer { lock.unlock() }
        return snippets.first { $0.id == id }
    }

    func getSnippet(trigger: String) -> TextExpansionSnippet? {
        lock.lock()
        defer { lock.unlock() }
        let searchTrigger = settings.caseSensitive ? trigger : trigger.lowercased()
        return snippets.first { snippet in
            let snippetTrigger = settings.caseSensitive ? snippet.trigger : snippet.trigger.lowercased()
            return snippetTrigger == searchTrigger && snippet.isEnabled
        }
    }

    // MARK: - Trigger Matching

    func findMatchingSnippet(for buffer: String) -> TextExpansionSnippet? {
        lock.lock()
        guard settings.isEnabled else {
            lock.unlock()
            return nil
        }

        let currentSettings = settings
        let sortedByLength = rebuildMatchingCacheLocked()
        lock.unlock()

        guard !sortedByLength.isEmpty else { return nil }

        for snippet in sortedByLength {
            let trigger = currentSettings.caseSensitive ? snippet.trigger : snippet.trigger.lowercased()
            let searchBuffer = currentSettings.caseSensitive ? buffer : buffer.lowercased()

            if searchBuffer.hasSuffix(trigger) {
                if currentSettings.requireWordBoundary {
                    let prefixLength = buffer.count - trigger.count
                    if prefixLength > 0 {
                        let prefixIndex = buffer.index(buffer.startIndex, offsetBy: prefixLength - 1)
                        let charBefore = buffer[prefixIndex]
                        if charBefore.isLetter || charBefore.isNumber {
                            continue
                        }
                    }
                }
                return snippet
            }
        }

        return nil
    }

    // MARK: - Validation

    func validateTrigger(_ trigger: String) -> Bool {
        guard !trigger.isEmpty else { return false }
        guard trigger.count >= 2 else { return false }
        guard !trigger.contains("\n") && !trigger.contains("\t") else { return false }
        return true
    }

    func validateReplacement(_ replacement: String) -> Bool {
        return !replacement.isEmpty
    }

    // MARK: - Import/Export

    func exportSnippets() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        do {
            return try JSONEncoder().encode(snippets)
        } catch {
            AppLog.textExpansion.error("Failed to export snippets: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func importSnippets(from data: Data, merge: Bool = true) -> Int {
        do {
            let importedSnippets = try JSONDecoder().decode([TextExpansionSnippet].self, from: data)
            var validSnippets: [TextExpansionSnippet] = []
            var seenTriggers = Set<String>()

            for snippet in importedSnippets {
                guard validateTrigger(snippet.trigger), validateReplacement(snippet.replacement) else { continue }
                guard !seenTriggers.contains(snippet.trigger) else { continue }
                seenTriggers.insert(snippet.trigger)
                validSnippets.append(snippet)
            }

            lock.lock()
            var addedCount = 0

            if merge {
                for snippet in validSnippets where !snippets.contains(where: { $0.trigger == snippet.trigger }) {
                    snippets.append(snippet)
                    addedCount += 1
                }
            } else {
                snippets = validSnippets
                addedCount = validSnippets.count
            }

            invalidateMatchingCache()
            lock.unlock()
            saveSnippets()
            AppLog.textExpansion.info("Imported \(addedCount, privacy: .public) snippets")
            return addedCount
        } catch {
            AppLog.textExpansion.error("Failed to import snippets: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    // MARK: - Default Snippets

    private func populateDefaultSnippetsIfNeeded() {
        guard !userDefaults.bool(forKey: hasPopulatedDefaultsKey) else { return }

        lock.lock()
        let isEmpty = snippets.isEmpty
        lock.unlock()

        if isEmpty {
            addDefaultSnippets()
            userDefaults.set(true, forKey: hasPopulatedDefaultsKey)
            AppLog.textExpansion.info("Populated default text expansion snippets")
        }
    }

    private func addDefaultSnippets() {
        let defaults = getDefaultSnippetsList()
        lock.lock()
        for snippet in defaults {
            snippets.append(snippet)
        }
        invalidateMatchingCache()
        lock.unlock()
        saveSnippets()
    }

    func resetToDefaultSnippets() {
        lock.lock()
        snippets = []
        invalidateMatchingCache()
        lock.unlock()
        addDefaultSnippets()
    }

    func mergeDefaultSnippets() -> Int {
        let defaults = getDefaultSnippetsList()
        lock.lock()
        var addedCount = 0

        for snippet in defaults where !snippets.contains(where: { $0.trigger == snippet.trigger }) {
            snippets.append(snippet)
            addedCount += 1
        }

        if addedCount > 0 {
            invalidateMatchingCache()
        }
        lock.unlock()

        if addedCount > 0 {
            saveSnippets()
        }
        return addedCount
    }

    private func getDefaultSnippetsList() -> [TextExpansionSnippet] {
        return [
            // === DATE/TIME ===
            TextExpansionSnippet(trigger: ":date", replacement: "{date}", groupName: "Date & Time"),
            TextExpansionSnippet(trigger: ":time", replacement: "{time}", groupName: "Date & Time"),
            TextExpansionSnippet(trigger: ":now", replacement: "{date} {time}", groupName: "Date & Time"),
            TextExpansionSnippet(trigger: ":isodate", replacement: "{isodate}", groupName: "Date & Time"),
            TextExpansionSnippet(trigger: ":tomorrow", replacement: "{date:+1d:yyyy-MM-dd}", groupName: "Date & Time"),
            TextExpansionSnippet(trigger: ":nextweek", replacement: "{date:+1w:EEEE, MMM d}", groupName: "Date & Time"),

            // === TEMPLATE SNIPPETS (fill-in fields, popups, macros) ===
            TextExpansionSnippet(
                trigger: ":hello",
                replacement: "Hi {field:Name:there},\n\n{cursor}\n\nBest,\nYour Name",
                groupName: "Templates"
            ),
            TextExpansionSnippet(
                trigger: ":reply",
                replacement: "Hi {field:Name},\n\nThanks for reaching out about {field:Topic}. {cursor}\n\nLet me know if you have any questions.\n\nBest regards,\nYour Name",
                groupName: "Templates"
            ),
            TextExpansionSnippet(
                trigger: ":meet",
                replacement: "Hi {field:Name},\n\nI'd like to schedule a {popup:Duration:15|30|45|60}-minute meeting on {date:+3d:EEEE, MMM d}. {cursor}\n\nDoes that work for you?\n\nThanks,\nYour Name",
                groupName: "Templates"
            ),
            TextExpansionSnippet(
                trigger: ":ticket",
                replacement: "Ticket: {field:Title}\nPriority: {popup:Priority:Low|Medium|High|Urgent}\nDate: {date:yyyy-MM-dd}\n\nDescription:\n{area:Details:Describe the issue here.}\n\n{cursor}",
                groupName: "Templates"
            ),
            TextExpansionSnippet(
                trigger: ":status",
                replacement: "Status update ({date:yyyy-MM-dd}):\n\nDone:\n{area:Done:- }\n\nNext:\n{area:Next:- }\n\nBlockers:\n{area:Blockers:None}\n\n{cursor}",
                groupName: "Templates"
            ),
            TextExpansionSnippet(
                trigger: ":intro",
                replacement: "Hi {field:Name},\n\n{popup:Tone:I hope this message finds you well.|Hope you're doing well.|Quick note for you.} {cursor}\n\nThanks,\nYour Name",
                groupName: "Templates"
            ),
            TextExpansionSnippet(
                trigger: ":paste",
                replacement: "{clipboard}{cursor}",
                groupName: "Templates"
            ),
            TextExpansionSnippet(
                trigger: ":id",
                replacement: "ref-{uuid}{cursor}",
                groupName: "Templates"
            ),
            TextExpansionSnippet(
                trigger: ":pr",
                replacement: "## Summary\n{area:Summary:What changed and why.}\n\n## Test plan\n{area:TestPlan:- [ ] }\n\n{cursor}",
                groupName: "Templates"
            ),

            // === CONTACT (customize these) ===
            TextExpansionSnippet(trigger: ":email", replacement: "your.email@example.com", groupName: "Contact"),
            TextExpansionSnippet(trigger: ":phone", replacement: "+1 (555) 123-4567", groupName: "Contact"),
            TextExpansionSnippet(trigger: ":addr", replacement: "123 Main Street\nCity, State 12345", groupName: "Contact"),

            // === COMMON PHRASES ===
            TextExpansionSnippet(trigger: ":ty", replacement: "Thank you", groupName: "Phrases"),
            TextExpansionSnippet(trigger: ":tyvm", replacement: "Thank you very much!", groupName: "Phrases"),
            TextExpansionSnippet(trigger: ":br", replacement: "Best regards,", groupName: "Phrases"),
            TextExpansionSnippet(trigger: ":kr", replacement: "Kind regards,", groupName: "Phrases"),
            TextExpansionSnippet(trigger: ":lmk", replacement: "Let me know if you have any questions.", groupName: "Phrases"),
            TextExpansionSnippet(trigger: ":pfa", replacement: "Please find attached", groupName: "Phrases"),
            TextExpansionSnippet(trigger: ":fyi", replacement: "For your information", groupName: "Phrases"),
            TextExpansionSnippet(trigger: ":sig", replacement: "Best regards,\n\nYour Name\nyour.email@example.com", groupName: "Phrases"),
            TextExpansionSnippet(trigger: ":oof", replacement: "I'm currently out of the office with limited access to email. I will respond to your message when I return.", groupName: "Phrases"),

            // === CODE COMMENTS ===
            TextExpansionSnippet(trigger: ":todo", replacement: "// TODO: {cursor}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":fixme", replacement: "// FIXME: {cursor}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":hack", replacement: "// HACK: {cursor}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":note", replacement: "// NOTE: {cursor}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":bug", replacement: "// BUG: {cursor}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":warn", replacement: "// WARNING: {cursor}", groupName: "Code"),

            // === DEBUGGING ===
            TextExpansionSnippet(trigger: ":clog", replacement: "console.log({cursor})", groupName: "Code"),
            TextExpansionSnippet(trigger: ":cerr", replacement: "console.error({cursor})", groupName: "Code"),
            TextExpansionSnippet(trigger: ":cdir", replacement: "console.dir({cursor})", groupName: "Code"),
            TextExpansionSnippet(trigger: ":pprint", replacement: "print({cursor})", groupName: "Code"),
            TextExpansionSnippet(trigger: ":dbg", replacement: "debugger;", groupName: "Code"),

            // === GIT COMMANDS ===
            TextExpansionSnippet(trigger: ":gaa", replacement: "git add -A", groupName: "Git"),
            TextExpansionSnippet(trigger: ":gcm", replacement: "git commit -m \"{cursor}\"", groupName: "Git"),
            TextExpansionSnippet(trigger: ":gp", replacement: "git push", groupName: "Git"),
            TextExpansionSnippet(trigger: ":gpl", replacement: "git pull", groupName: "Git"),
            TextExpansionSnippet(trigger: ":gco", replacement: "git checkout {cursor}", groupName: "Git"),
            TextExpansionSnippet(trigger: ":gst", replacement: "git status", groupName: "Git"),
            TextExpansionSnippet(trigger: ":gbr", replacement: "git branch", groupName: "Git"),
            TextExpansionSnippet(trigger: ":glog", replacement: "git log --oneline -10", groupName: "Git"),
            TextExpansionSnippet(trigger: ":gdf", replacement: "git diff", groupName: "Git"),
            TextExpansionSnippet(trigger: ":grh", replacement: "git reset --hard HEAD", groupName: "Git"),

            // === CODE BLOCKS ===
            TextExpansionSnippet(trigger: ":try", replacement: "try {\n    {cursor}\n} catch (error) {\n    console.error(error);\n}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":ife", replacement: "if ({cursor}) {\n    \n} else {\n    \n}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":afn", replacement: "() => {\n    {cursor}\n}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":fn", replacement: "function () {\n    {cursor}\n}", groupName: "Code"),
            TextExpansionSnippet(trigger: ":fore", replacement: ".forEach((item) => {\n    {cursor}\n})", groupName: "Code"),
            TextExpansionSnippet(trigger: ":map", replacement: ".map((item) => {\n    {cursor}\n})", groupName: "Code"),
            TextExpansionSnippet(trigger: ":filt", replacement: ".filter((item) => {\n    {cursor}\n})", groupName: "Code"),

            // === PLACEHOLDER TEXT ===
            TextExpansionSnippet(trigger: ":lorem", replacement: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."),
            TextExpansionSnippet(trigger: ":lorem1", replacement: "Lorem ipsum dolor sit amet."),
            TextExpansionSnippet(trigger: ":lorem3", replacement: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur."),

            // === SYMBOLS & SPECIAL ===
            TextExpansionSnippet(trigger: ":shrug", replacement: "¯\\_(ツ)_/¯"),
            TextExpansionSnippet(trigger: ":arr", replacement: "→"),
            TextExpansionSnippet(trigger: ":darr", replacement: "⇒"),
            TextExpansionSnippet(trigger: ":check", replacement: "✓"),
            TextExpansionSnippet(trigger: ":x", replacement: "✗"),
            TextExpansionSnippet(trigger: ":star", replacement: "★"),
            TextExpansionSnippet(trigger: ":bullet", replacement: "•"),

            // === COMMON VALUES ===
            TextExpansionSnippet(trigger: ":null", replacement: "null"),
            TextExpansionSnippet(trigger: ":undef", replacement: "undefined"),
            TextExpansionSnippet(trigger: ":true", replacement: "true"),
            TextExpansionSnippet(trigger: ":false", replacement: "false"),
        ]
    }
}
