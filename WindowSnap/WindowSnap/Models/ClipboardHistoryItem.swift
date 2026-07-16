import Foundation
import AppKit

struct ClipboardHistoryItem: Codable {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    let preview: String
    let thumbnail: String? // Base64 encoded thumbnail for images
    /// Pixel dimensions of the source image when captured (optional for legacy items).
    let imageWidth: Int?
    let imageHeight: Int?
    let isPinned: Bool

    init(
        content: String,
        type: ClipboardItemType,
        thumbnail: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        isPinned: Bool = false
    ) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.preview = Self.generatePreview(from: content, type: type)
        self.thumbnail = thumbnail
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(ClipboardItemType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        preview = try container.decode(String.self, forKey: .preview)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, type, timestamp, preview, thumbnail, imageWidth, imageHeight, isPinned
    }

    init(
        id: UUID,
        content: String,
        type: ClipboardItemType,
        timestamp: Date,
        preview: String,
        thumbnail: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.preview = preview
        self.thumbnail = thumbnail
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.isPinned = isPinned
    }
    
    static func makePreview(from content: String, type: ClipboardItemType) -> String {
        generatePreview(from: content, type: type)
    }

    private static func generatePreview(from content: String, type: ClipboardItemType) -> String {
        switch type {
        case .text:
            // Limit preview to first 100 characters and replace newlines with spaces
            let cleaned = content.replacingOccurrences(of: "\n", with: " ")
                                .replacingOccurrences(of: "\t", with: " ")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleaned.count > 100 {
                return String(cleaned.prefix(100)) + "..."
            }
            return cleaned
            
        case .url:
            return content
            
        case .richText:
            // For rich text, try to extract plain text for preview
            let stripped = content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            return generatePreview(from: stripped, type: .text)
            
        case .image:
            return "[Image]"
            
        case .file:
            return "[File: \(URL(string: content)?.lastPathComponent ?? content)]"
        }
    }
}

enum ClipboardItemType: String, CaseIterable, Codable {
    case text = "text"
    case url = "url"
    case richText = "richText"
    case image = "image"
    case file = "file"
    
    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .url:
            return "URL"
        case .richText:
            return "Rich Text"
        case .image:
            return "Image"
        case .file:
            return "File"
        }
    }
    
    var icon: String {
        switch self {
        case .text:
            return "doc.text"
        case .url:
            return "link"
        case .richText:
            return "doc.richtext"
        case .image:
            return "photo"
        case .file:
            return "doc"
        }
    }
}
