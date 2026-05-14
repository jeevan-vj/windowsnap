import Foundation

/// Manages storage and operations for text expansion snippets
class TextExpanderManager {
    static let shared = TextExpanderManager()
    
    private let userDefaults = UserDefaults.standard
    private let snippetsStorageKey = "WindowSnap_TextExpanderSnippets"
    private let settingsStorageKey = "WindowSnap_TextExpanderSettings"
    private let hasPopulatedDefaultsKey = "WindowSnap_TextExpanderHasPopulatedDefaults"
    
    private var snippets: [TextExpansionSnippet] = []
    private(set) var settings: TextExpanderSettings = .default
    
    private init() {
        loadSnippets()
        loadSettings()
        populateDefaultSnippetsIfNeeded()
    }
    
    // MARK: - Storage Operations
    
    private func loadSnippets() {
        guard let data = userDefaults.data(forKey: snippetsStorageKey) else {
            snippets = []
            return
        }
        
        do {
            snippets = try JSONDecoder().decode([TextExpansionSnippet].self, from: data)
            print("📝 Loaded \(snippets.count) text expansion snippets")
        } catch {
            print("❌ Failed to load text expansion snippets: \(error)")
            snippets = []
        }
    }
    
    private func saveSnippets() {
        do {
            let data = try JSONEncoder().encode(snippets)
            userDefaults.set(data, forKey: snippetsStorageKey)
            print("💾 Saved \(snippets.count) text expansion snippets")
        } catch {
            print("❌ Failed to save text expansion snippets: \(error)")
        }
    }
    
    private func loadSettings() {
        guard let data = userDefaults.data(forKey: settingsStorageKey) else {
            settings = .default
            return
        }
        
        do {
            settings = try JSONDecoder().decode(TextExpanderSettings.self, from: data)
            print("📝 Loaded text expander settings")
        } catch {
            print("❌ Failed to load text expander settings: \(error)")
            settings = .default
        }
    }
    
    private func saveSettings() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: settingsStorageKey)
            print("💾 Saved text expander settings")
        } catch {
            print("❌ Failed to save text expander settings: \(error)")
        }
    }
    
    // MARK: - Settings Management
    
    var isEnabled: Bool {
        get { settings.isEnabled }
        set {
            settings.isEnabled = newValue
            saveSettings()
        }
    }
    
    func updateSettings(_ newSettings: TextExpanderSettings) {
        settings = newSettings
        saveSettings()
    }
    
    // MARK: - Snippet Management
    
    func addSnippet(_ snippet: TextExpansionSnippet) -> Bool {
        guard validateTrigger(snippet.trigger) else {
            print("⚠️ Invalid trigger: '\(snippet.trigger)'")
            return false
        }
        
        if snippets.contains(where: { $0.trigger == snippet.trigger }) {
            print("⚠️ Snippet with trigger '\(snippet.trigger)' already exists")
            return false
        }
        
        snippets.append(snippet)
        saveSnippets()
        print("✅ Added text expansion snippet: '\(snippet.trigger)'")
        return true
    }
    
    func removeSnippet(id: UUID) -> Bool {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            print("❌ Snippet with ID \(id) not found")
            return false
        }
        
        let snippet = snippets[index]
        snippets.remove(at: index)
        saveSnippets()
        print("🗑️ Removed text expansion snippet: '\(snippet.trigger)'")
        return true
    }
    
    func updateSnippet(_ updatedSnippet: TextExpansionSnippet) -> Bool {
        guard let index = snippets.firstIndex(where: { $0.id == updatedSnippet.id }) else {
            print("❌ Snippet with ID \(updatedSnippet.id) not found")
            return false
        }
        
        if updatedSnippet.trigger != snippets[index].trigger {
            guard validateTrigger(updatedSnippet.trigger) else {
                print("⚠️ Invalid trigger: '\(updatedSnippet.trigger)'")
                return false
            }
            
            if snippets.contains(where: { $0.trigger == updatedSnippet.trigger && $0.id != updatedSnippet.id }) {
                print("⚠️ Snippet with trigger '\(updatedSnippet.trigger)' already exists")
                return false
            }
        }
        
        snippets[index] = updatedSnippet
        saveSnippets()
        print("📝 Updated text expansion snippet: '\(updatedSnippet.trigger)'")
        return true
    }
    
    func toggleSnippetEnabled(id: UUID) -> Bool {
        guard let index = snippets.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        snippets[index].update(isEnabled: !snippets[index].isEnabled)
        saveSnippets()
        return true
    }
    
    func getAllSnippets() -> [TextExpansionSnippet] {
        return snippets.sorted { $0.trigger < $1.trigger }
    }
    
    func getEnabledSnippets() -> [TextExpansionSnippet] {
        return snippets.filter { $0.isEnabled }.sorted { $0.trigger < $1.trigger }
    }
    
    func getSnippet(id: UUID) -> TextExpansionSnippet? {
        return snippets.first { $0.id == id }
    }
    
    func getSnippet(trigger: String) -> TextExpansionSnippet? {
        let searchTrigger = settings.caseSensitive ? trigger : trigger.lowercased()
        return snippets.first { snippet in
            let snippetTrigger = settings.caseSensitive ? snippet.trigger : snippet.trigger.lowercased()
            return snippetTrigger == searchTrigger && snippet.isEnabled
        }
    }
    
    // MARK: - Trigger Matching
    
    func findMatchingSnippet(for buffer: String) -> TextExpansionSnippet? {
        guard settings.isEnabled else { return nil }
        
        let enabledSnippets = getEnabledSnippets()
        guard !enabledSnippets.isEmpty else { return nil }
        
        let sortedByLength = enabledSnippets.sorted { $0.trigger.count > $1.trigger.count }
        
        for snippet in sortedByLength {
            let trigger = settings.caseSensitive ? snippet.trigger : snippet.trigger.lowercased()
            let searchBuffer = settings.caseSensitive ? buffer : buffer.lowercased()
            
            if searchBuffer.hasSuffix(trigger) {
                if settings.requireWordBoundary {
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
        do {
            return try JSONEncoder().encode(snippets)
        } catch {
            print("❌ Failed to export snippets: \(error)")
            return nil
        }
    }
    
    func importSnippets(from data: Data, merge: Bool = true) -> Int {
        do {
            let importedSnippets = try JSONDecoder().decode([TextExpansionSnippet].self, from: data)
            var addedCount = 0
            
            if merge {
                for snippet in importedSnippets {
                    if !snippets.contains(where: { $0.trigger == snippet.trigger }) {
                        snippets.append(snippet)
                        addedCount += 1
                    }
                }
            } else {
                snippets = importedSnippets
                addedCount = importedSnippets.count
            }
            
            saveSnippets()
            print("📥 Imported \(addedCount) snippets")
            return addedCount
        } catch {
            print("❌ Failed to import snippets: \(error)")
            return 0
        }
    }
    
    // MARK: - Default Snippets
    
    private func populateDefaultSnippetsIfNeeded() {
        guard !userDefaults.bool(forKey: hasPopulatedDefaultsKey) else { return }
        
        if snippets.isEmpty {
            addDefaultSnippets()
            userDefaults.set(true, forKey: hasPopulatedDefaultsKey)
            print("📝 Populated default text expansion snippets")
        }
    }
    
    private func addDefaultSnippets() {
        let defaults = getDefaultSnippetsList()
        for snippet in defaults {
            snippets.append(snippet)
        }
        saveSnippets()
    }
    
    func resetToDefaultSnippets() {
        snippets = []
        addDefaultSnippets()
    }
    
    func mergeDefaultSnippets() -> Int {
        let defaults = getDefaultSnippetsList()
        var addedCount = 0
        
        for snippet in defaults {
            if !snippets.contains(where: { $0.trigger == snippet.trigger }) {
                snippets.append(snippet)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            saveSnippets()
        }
        return addedCount
    }
    
    private func getDefaultSnippetsList() -> [TextExpansionSnippet] {
        return [
            // === DATE/TIME ===
            TextExpansionSnippet(trigger: ":date", replacement: "{date}"),
            TextExpansionSnippet(trigger: ":time", replacement: "{time}"),
            TextExpansionSnippet(trigger: ":now", replacement: "{date} {time}"),
            TextExpansionSnippet(trigger: ":isodate", replacement: "{isodate}"),
            
            // === CONTACT (customize these) ===
            TextExpansionSnippet(trigger: ":email", replacement: "your.email@example.com"),
            TextExpansionSnippet(trigger: ":phone", replacement: "+1 (555) 123-4567"),
            TextExpansionSnippet(trigger: ":addr", replacement: "123 Main Street\nCity, State 12345"),
            
            // === COMMON PHRASES ===
            TextExpansionSnippet(trigger: ":ty", replacement: "Thank you"),
            TextExpansionSnippet(trigger: ":tyvm", replacement: "Thank you very much!"),
            TextExpansionSnippet(trigger: ":br", replacement: "Best regards,"),
            TextExpansionSnippet(trigger: ":kr", replacement: "Kind regards,"),
            TextExpansionSnippet(trigger: ":lmk", replacement: "Let me know if you have any questions."),
            TextExpansionSnippet(trigger: ":pfa", replacement: "Please find attached"),
            TextExpansionSnippet(trigger: ":fyi", replacement: "For your information"),
            TextExpansionSnippet(trigger: ":sig", replacement: "Best regards,\n\nYour Name\nyour.email@example.com"),
            TextExpansionSnippet(trigger: ":oof", replacement: "I'm currently out of the office with limited access to email. I will respond to your message when I return."),
            
            // === CODE COMMENTS ===
            TextExpansionSnippet(trigger: ":todo", replacement: "// TODO: "),
            TextExpansionSnippet(trigger: ":fixme", replacement: "// FIXME: "),
            TextExpansionSnippet(trigger: ":hack", replacement: "// HACK: "),
            TextExpansionSnippet(trigger: ":note", replacement: "// NOTE: "),
            TextExpansionSnippet(trigger: ":bug", replacement: "// BUG: "),
            TextExpansionSnippet(trigger: ":warn", replacement: "// WARNING: "),
            
            // === DEBUGGING ===
            TextExpansionSnippet(trigger: ":clog", replacement: "console.log()"),
            TextExpansionSnippet(trigger: ":cerr", replacement: "console.error()"),
            TextExpansionSnippet(trigger: ":cdir", replacement: "console.dir()"),
            TextExpansionSnippet(trigger: ":pprint", replacement: "print()"),
            TextExpansionSnippet(trigger: ":dbg", replacement: "debugger;"),
            
            // === GIT COMMANDS ===
            TextExpansionSnippet(trigger: ":gaa", replacement: "git add -A"),
            TextExpansionSnippet(trigger: ":gcm", replacement: "git commit -m \"\""),
            TextExpansionSnippet(trigger: ":gp", replacement: "git push"),
            TextExpansionSnippet(trigger: ":gpl", replacement: "git pull"),
            TextExpansionSnippet(trigger: ":gco", replacement: "git checkout "),
            TextExpansionSnippet(trigger: ":gst", replacement: "git status"),
            TextExpansionSnippet(trigger: ":gbr", replacement: "git branch"),
            TextExpansionSnippet(trigger: ":glog", replacement: "git log --oneline -10"),
            TextExpansionSnippet(trigger: ":gdf", replacement: "git diff"),
            TextExpansionSnippet(trigger: ":grh", replacement: "git reset --hard HEAD"),
            
            // === CODE BLOCKS ===
            TextExpansionSnippet(trigger: ":try", replacement: "try {\n    \n} catch (error) {\n    console.error(error);\n}"),
            TextExpansionSnippet(trigger: ":ife", replacement: "if () {\n    \n} else {\n    \n}"),
            TextExpansionSnippet(trigger: ":afn", replacement: "() => {\n    \n}"),
            TextExpansionSnippet(trigger: ":fn", replacement: "function () {\n    \n}"),
            TextExpansionSnippet(trigger: ":fore", replacement: ".forEach((item) => {\n    \n})"),
            TextExpansionSnippet(trigger: ":map", replacement: ".map((item) => {\n    \n})"),
            TextExpansionSnippet(trigger: ":filt", replacement: ".filter((item) => {\n    \n})"),
            
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
