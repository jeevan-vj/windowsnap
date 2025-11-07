import Foundation
import AppKit

struct ClipboardHistoryItem {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    let preview: String
    let thumbnail: String? // Base64 encoded thumbnail for images

    init(content: String, type: ClipboardItemType, thumbnail: String? = nil) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.preview = Self.generatePreview(from: content, type: type)
        self.thumbnail = thumbnail
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

enum ClipboardItemType: String, CaseIterable {
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

