import Foundation

enum SnippetContentType: String, Codable, Equatable {
    case plainText
    case richText
    case image
}

/// Represents a text expansion snippet that maps a trigger to replacement text
struct TextExpansionSnippet: Codable, Identifiable, Equatable {
    let id: UUID
    var trigger: String
    var replacement: String
    var isEnabled: Bool
    var groupName: String?
    var contentType: SnippetContentType
    var richData: Data?
    let createdAt: Date
    var updatedAt: Date

    init(
        trigger: String,
        replacement: String,
        isEnabled: Bool = true,
        groupName: String? = nil,
        contentType: SnippetContentType = .plainText,
        richData: Data? = nil
    ) {
        self.id = UUID()
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
        self.groupName = groupName
        self.contentType = contentType
        self.richData = richData
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    private init(
        id: UUID,
        trigger: String,
        replacement: String,
        isEnabled: Bool,
        groupName: String?,
        contentType: SnippetContentType,
        richData: Data?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.isEnabled = isEnabled
        self.groupName = groupName
        self.contentType = contentType
        self.richData = richData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, trigger, replacement, isEnabled, groupName, contentType, richData, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        trigger = try container.decode(String.self, forKey: .trigger)
        replacement = try container.decode(String.self, forKey: .replacement)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        contentType = try container.decodeIfPresent(SnippetContentType.self, forKey: .contentType) ?? .plainText
        richData = try container.decodeIfPresent(Data.self, forKey: .richData)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    mutating func update(
        trigger: String? = nil,
        replacement: String? = nil,
        isEnabled: Bool? = nil,
        groupName: String?? = nil,
        contentType: SnippetContentType? = nil,
        richData: Data?? = nil
    ) {
        if let trigger { self.trigger = trigger }
        if let replacement { self.replacement = replacement }
        if let isEnabled { self.isEnabled = isEnabled }
        if let groupName { self.groupName = groupName }
        if let contentType { self.contentType = contentType }
        if let richData { self.richData = richData }
        self.updatedAt = Date()
    }

    func withUpdate(
        trigger: String? = nil,
        replacement: String? = nil,
        isEnabled: Bool? = nil,
        groupName: String?? = nil,
        contentType: SnippetContentType? = nil,
        richData: Data?? = nil
    ) -> TextExpansionSnippet {
        TextExpansionSnippet(
            id: id,
            trigger: trigger ?? self.trigger,
            replacement: replacement ?? self.replacement,
            isEnabled: isEnabled ?? self.isEnabled,
            groupName: groupName ?? self.groupName,
            contentType: contentType ?? self.contentType,
            richData: richData ?? self.richData,
            createdAt: createdAt,
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
