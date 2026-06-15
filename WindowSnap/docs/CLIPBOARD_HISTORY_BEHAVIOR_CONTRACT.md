# Clipboard History Behavior Contract

This document locks expected behavior before and during UI refactors. Any change must preserve these contracts unless explicitly versioned.

## Data Flow

```
ClipboardManager.getHistory()
  -> history (pinned first, then unpinned; newest first within each group)
  -> applySearchFilter(searchText, typeFilters)
  -> filteredHistory
  -> buildDisplayItems()
  -> displayItems ([header | item]*)
  -> tableView + selectedIndex
```

## Search

- Placeholder: "Search Clipboard..."
- Debounce: 250ms after typing
- Matches (case-insensitive): `preview`, `content`, `type.displayName`
- When search is non-empty: filtered results re-sort pinned/unpinned by timestamp (newest first)
- Escape while search focused and non-empty: clears search and re-filters; does not close window
- Escape when search empty or not editing: closes window
- Cmd+F: focus search field

## Type Filters

- Chips: Text, URL, Rich Text, Image, File (multi-select)
- Combined with search via AND semantics
- Active chips use accent styling; inactive use secondary styling

## Selection

- Header rows ("Pinned", "Recent") are not selectable
- `selectedIndex` tracks selected row; synced with `tableView.selectedRow`
- After filter changes: selection resets to first selectable item row
- Arrow Up/Down skip header rows
- Pin toggle preserves selection on same item id after reorder

## Keyboard Actions

| Input | Action |
|-------|--------|
| Enter / Return | Copy selected item to clipboard, simulate Cmd+V in previous app, close window |
| Cmd+C | Copy selected item without paste |
| Cmd+P | Toggle pin on selected item |
| Cmd+Backspace | Delete selected item |
| Cmd+Shift+Backspace | Clear all history (with confirmation) |
| Space | Toggle Quick Look popover for selected item |
| Tab | Toggle focus between search field and table |
| Double-click row | Same as Enter (paste flow) |

## Paste Flow

1. Store `previousApp` when window opens
2. Copy item via `ClipboardManager.copyToClipboard`
3. Verify pasteboard `changeCount` (up to 3 attempts, 50ms apart)
4. Hide window, activate previous app, simulate Cmd+V (150ms delay after activate)

## Periodic Refresh

- Interval: 500ms while window visible
- Only reloads when search field is empty and history count changed

## Footer

- Hints: Paste, Delete, Pin, Copy, Close (static)
- Count: `"N items"` or `"N of M"` when filtering; includes filter names when type chips active

## Clear History

- Trash button shows confirmation alert before clearing
- Disabled when history is empty

## Accessibility

- Search field, clear button, filter chips, table, and row action buttons must retain accessibility labels
