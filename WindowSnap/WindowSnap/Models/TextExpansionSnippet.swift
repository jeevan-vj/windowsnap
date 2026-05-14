import Foundation

/// Represents a text expansion snippet that maps a trigger to replacement text
struct TextExpansionSnippet: Codable, Identifiable, Equatable {
    let id: UUID
    var trigger: String
    var replacement: String
    var isEnabled: Bool
    let createdAt: Date
    var updatedAt: Date
    
    init(trigger: String, replacement: String, isEnabled: Bool = true) {
        self.id = UUID()
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    private init(id: UUID, trigger: String, replacement: String, isEnabled: Bool, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    mutating func update(trigger: String? = nil, replacement: String? = nil, isEnabled: Bool? = nil) {
        if let trigger = trigger { self.trigger = trigger }
        if let replacement = replacement { self.replacement = replacement }
        if let isEnabled = isEnabled { self.isEnabled = isEnabled }
        self.updatedAt = Date()
    }
    
    func withUpdate(trigger: String? = nil, replacement: String? = nil, isEnabled: Bool? = nil) -> TextExpansionSnippet {
        TextExpansionSnippet(
            id: self.id,
            trigger: trigger ?? self.trigger,
            replacement: replacement ?? self.replacement,
            isEnabled: isEnabled ?? self.isEnabled,
            createdAt: self.createdAt,
            updatedAt: Date()
        )
    }
    
    var displayDescription: String {
        let truncatedReplacement = replacement.count > 30 
            ? String(replacement.prefix(30)) + "..." 
            : replacement
        return "\(trigger) → \(truncatedReplacement)"
    }
}

/// Global settings for the text expander feature
struct TextExpanderSettings: Codable {
    var isEnabled: Bool
    var caseSensitive: Bool
    var requireWordBoundary: Bool
    
    init(isEnabled: Bool = true, caseSensitive: Bool = true, requireWordBoundary: Bool = false) {
        self.isEnabled = isEnabled
        self.caseSensitive = caseSensitive
        self.requireWordBoundary = requireWordBoundary
    }
    
    static let `default` = TextExpanderSettings()
}
