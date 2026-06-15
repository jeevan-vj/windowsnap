import Foundation

enum SnippetPickerSectionItem {
    case header(String)
    case item(TextExpansionSnippet)

    var isSelectable: Bool {
        if case .item = self { return true }
        return false
    }
}

struct SnippetPickerFilterModel {
    static func filter(
        snippets: [TextExpansionSnippet],
        searchText: String,
        activeGroup: String?
    ) -> [TextExpansionSnippet] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = snippets.filter(\.isEnabled)

        if let activeGroup, !activeGroup.isEmpty {
            result = result.filter { ($0.groupName ?? "Ungrouped") == activeGroup }
        }

        guard !trimmedSearch.isEmpty else {
            return sortSnippets(result)
        }

        let query = trimmedSearch.lowercased()
        let matched = result.filter { snippet in
            matchScore(query: query, candidate: snippet.trigger) != nil ||
            matchScore(query: query, candidate: snippet.replacement) != nil ||
            matchScore(query: query, candidate: snippet.groupName ?? "") != nil
        }

        return sortSnippets(matched)
    }

    static func sortSnippets(_ snippets: [TextExpansionSnippet]) -> [TextExpansionSnippet] {
        snippets.sorted {
            let leftGroup = $0.groupName ?? "Ungrouped"
            let rightGroup = $1.groupName ?? "Ungrouped"
            if leftGroup != rightGroup {
                return leftGroup.localizedCaseInsensitiveCompare(rightGroup) == .orderedAscending
            }
            return $0.trigger.localizedCaseInsensitiveCompare($1.trigger) == .orderedAscending
        }
    }

    static func buildDisplayItems(from snippets: [TextExpansionSnippet]) -> [SnippetPickerSectionItem] {
        let grouped = Dictionary(grouping: snippets) { $0.groupName ?? "Ungrouped" }
        let sortedGroups = grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        var items: [SnippetPickerSectionItem] = []
        for group in sortedGroups {
            guard let groupSnippets = grouped[group] else { continue }
            items.append(.header(group))
            items.append(contentsOf: groupSnippets.sorted { $0.trigger < $1.trigger }.map { .item($0) })
        }
        return items
    }

    static func firstSelectableRow(in displayItems: [SnippetPickerSectionItem]) -> Int {
        for (index, item) in displayItems.enumerated() where item.isSelectable {
            return index
        }
        return 0
    }

    static func nextSelectableRow(
        after row: Int,
        direction: Int,
        in displayItems: [SnippetPickerSectionItem]
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

    static func matchScore(query: String, candidate: String) -> Int? {
        let loweredCandidate = candidate.lowercased()
        guard !query.isEmpty else { return 0 }
        if loweredCandidate == query { return 100 }
        if loweredCandidate.hasPrefix(query) { return 80 }
        if loweredCandidate.contains(query) { return 50 }
        return nil
    }

    static func itemCountLabel(filteredCount: Int, totalCount: Int, isSearching: Bool) -> String {
        guard isSearching else {
            return "\(totalCount) snippet\(totalCount == 1 ? "" : "s")"
        }
        return "\(filteredCount) of \(totalCount)"
    }
}
