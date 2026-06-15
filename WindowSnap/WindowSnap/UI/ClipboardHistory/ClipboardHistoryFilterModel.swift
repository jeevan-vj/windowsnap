import Foundation

enum ClipboardHistorySectionItem {
    case header(String)
    case item(ClipboardHistoryItem)

    var isSelectable: Bool {
        if case .item = self { return true }
        return false
    }
}

struct ClipboardHistoryFilterModel {
    static func filter(
        history: [ClipboardHistoryItem],
        searchText: String,
        activeTypeFilters: Set<ClipboardItemType>
    ) -> [ClipboardHistoryItem] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result: [ClipboardHistoryItem]

        if trimmedSearch.isEmpty {
            result = history
        } else {
            let query = trimmedSearch.lowercased()
            let matched = history.filter { item in
                item.preview.lowercased().contains(query) ||
                item.content.lowercased().contains(query) ||
                item.type.displayName.lowercased().contains(query)
            }
            result = sortPinnedFirst(matched)
        }

        if !activeTypeFilters.isEmpty {
            result = result.filter { activeTypeFilters.contains($0.type) }
        }

        return result
    }

    static func sortPinnedFirst(_ items: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        let pinned = items.filter(\.isPinned).sorted { $0.timestamp > $1.timestamp }
        let unpinned = items.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        return pinned + unpinned
    }

    static func buildDisplayItems(from filteredHistory: [ClipboardHistoryItem]) -> [ClipboardHistorySectionItem] {
        let pinned = filteredHistory.filter(\.isPinned)
        let unpinned = filteredHistory.filter { !$0.isPinned }
        var items: [ClipboardHistorySectionItem] = []

        if !pinned.isEmpty {
            items.append(.header("Pinned"))
            items.append(contentsOf: pinned.map { .item($0) })
        }
        if !unpinned.isEmpty {
            items.append(.header("Recent"))
            items.append(contentsOf: unpinned.map { .item($0) })
        }

        return items
    }

    static func firstSelectableRow(in displayItems: [ClipboardHistorySectionItem]) -> Int {
        for (index, item) in displayItems.enumerated() where item.isSelectable {
            return index
        }
        return 0
    }

    static func nextSelectableRow(
        after row: Int,
        direction: Int,
        in displayItems: [ClipboardHistorySectionItem]
    ) -> Int? {
        var candidate = row + direction
        while candidate >= 0 && candidate < displayItems.count {
            if displayItems[candidate].isSelectable {
                return candidate
            }
            candidate += direction
        }
        return nil
    }

    static func itemCountLabel(
        filteredCount: Int,
        totalCount: Int,
        isSearching: Bool,
        activeFilterNames: [String]
    ) -> String {
        guard isSearching else {
            return "\(totalCount) item\(totalCount == 1 ? "" : "s")"
        }

        let filterNames = activeFilterNames.sorted().joined(separator: ", ")
        if !filterNames.isEmpty {
            return "\(filteredCount) of \(totalCount) \u{2022} \(filterNames)"
        }
        return "\(filteredCount) of \(totalCount)"
    }

    static func isFiltering(searchText: String, activeTypeFilters: Set<ClipboardItemType>) -> Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !activeTypeFilters.isEmpty
    }
}
