import AppKit
import Foundation

/// Point-in-time copy of pasteboard items, grouped per pasteboard item.
struct PasteboardSnapshot: Equatable {
    struct Item: Equatable {
        struct Entry: Equatable {
            let typeIdentifier: String
            let data: Data
        }

        var entries: [Entry]
    }

    var items: [Item]

    static func capture(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        guard let pasteboardItems = pasteboard.pasteboardItems else {
            return PasteboardSnapshot(items: [])
        }

        let items = pasteboardItems.compactMap { pasteboardItem -> Item? in
            let entries = pasteboardItem.types.compactMap { type -> Item.Entry? in
                guard let data = pasteboardItem.data(forType: type) else { return nil }
                return Item.Entry(typeIdentifier: type.rawValue, data: data)
            }
            return entries.isEmpty ? nil : Item(entries: entries)
        }
        return PasteboardSnapshot(items: items)
    }

    /// Restores captured items when the pasteboard `changeCount` still matches
    /// the value recorded after the expansion write. Returns whether restore ran.
    @discardableResult
    func restore(to pasteboard: NSPasteboard, ifChangeCountIs expected: Int) -> Bool {
        guard pasteboard.changeCount == expected else { return false }

        pasteboard.clearContents()
        let objects: [NSPasteboardItem] = items.map { item in
            let pasteboardItem = NSPasteboardItem()
            for entry in item.entries {
                pasteboardItem.setData(entry.data, forType: NSPasteboard.PasteboardType(entry.typeIdentifier))
            }
            return pasteboardItem
        }
        if !objects.isEmpty {
            pasteboard.writeObjects(objects)
        }
        return true
    }
}
