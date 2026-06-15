import AppKit
import Foundation

enum SnippetPasteboardWriter {
    struct WriteItem: Equatable {
        let typeIdentifier: String
        let data: Data
    }

    static func writeItems(for snippet: TextExpansionSnippet) -> [WriteItem] {
        switch snippet.contentType {
        case .plainText:
            return [WriteItem(typeIdentifier: NSPasteboard.PasteboardType.string.rawValue, data: Data(snippet.replacement.utf8))]
        case .richText:
            let data = snippet.richData ?? Data(snippet.replacement.utf8)
            return [WriteItem(typeIdentifier: NSPasteboard.PasteboardType.rtf.rawValue, data: data)]
        case .image:
            let data = snippet.richData ?? Data()
            return [
                WriteItem(typeIdentifier: NSPasteboard.PasteboardType.png.rawValue, data: data),
                WriteItem(typeIdentifier: NSPasteboard.PasteboardType.tiff.rawValue, data: data),
            ]
        }
    }
}
