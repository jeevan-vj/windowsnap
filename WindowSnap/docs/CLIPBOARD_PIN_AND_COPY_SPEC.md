# Clipboard History Pin and Copy Features - Specification

## 1. Overview

This specification defines the implementation of two features for the clipboard history:
1. **Pin Feature**: Allow users to pin frequently used clipboard items to keep them at the top of the history
2. **Copy Feature**: Add explicit copy buttons to each clipboard item for direct copying without auto-paste

## 2. Requirements

### 2.1 Pin Feature Requirements

#### Functional Requirements
- Users can pin/unpin any clipboard history item
- Pinned items must always appear at the top of the list (before unpinned items)
- Pin state must persist across app restarts
- Pinned items should maintain their pin state even when new items are added
- Search/filter operations must respect pinned item ordering (pinned items appear first in results)
- Multiple items can be pinned simultaneously
- Pinned items should be visually distinct from unpinned items

#### User Interface Requirements
- Each clipboard item cell must display a pin button/icon
- Pin button should show filled icon when pinned, outline icon when unpinned
- Pin button should be positioned on the right side of the cell
- Keyboard shortcut: `Cmd+P` to toggle pin state of selected item
- Visual indicator: Subtle background tint or border for pinned items

#### Data Persistence Requirements
- Pin state must be saved to UserDefaults along with other clipboard history data
- Pin state must be loaded when app starts
- Pin state must survive history clearing operations (user decision needed - for now, clearing clears all including pinned)

### 2.2 Copy Feature Requirements

#### Functional Requirements
- Each clipboard item must have a visible copy button
- Clicking copy button copies the item to system clipboard
- Copy button should NOT auto-paste (unlike Enter/double-click behavior)
- Copy button should provide visual feedback when clicked
- Existing Enter/double-click behavior should remain unchanged (copy + auto-paste)

#### User Interface Requirements
- Copy button should be positioned next to pin button on the right side of cell
- Copy button should use standard copy icon (doc.on.doc or similar)
- Copy button should have hover effects matching design system
- Copy button should show brief visual feedback on click

## 3. Data Model Changes

### 3.1 ClipboardHistoryItem Structure

**Current Structure:**
```swift
struct ClipboardHistoryItem {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    let preview: String
    let thumbnail: String?
}
```

**Updated Structure:**
```swift
struct ClipboardHistoryItem {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    let preview: String
    let thumbnail: String?
    let isPinned: Bool  // NEW
}
```

### 3.2 Initializers

**New Initializer Signature:**
```swift
init(content: String, type: ClipboardItemType, thumbnail: String? = nil, isPinned: Bool = false)
```

**Persistence Initializer:**
```swift
init(id: UUID, content: String, type: ClipboardItemType, timestamp: Date, preview: String, thumbnail: String? = nil, isPinned: Bool = false)
```

### 3.3 HistoryItemData Structure

**Updated Structure:**
```swift
private struct HistoryItemData: Codable {
    let id: String
    let content: String
    let type: String
    let timestamp: Date
    let preview: String
    let thumbnail: String?
    let isPinned: Bool  // NEW
}
```

## 4. API Changes

### 4.1 ClipboardManager Methods

**New Methods:**
```swift
func pinItem(id: UUID) -> Bool
func unpinItem(id: UUID) -> Bool
func togglePinState(id: UUID) -> Bool
```

**Updated Methods:**
```swift
func getHistory() -> [ClipboardHistoryItem]  // Returns sorted with pinned first
```

**Method Specifications:**

1. `pinItem(id: UUID) -> Bool`
   - Finds item with matching ID in history
   - Sets `isPinned = true`
   - Saves to disk
   - Returns `true` if successful, `false` if item not found
   - Thread-safe (uses processingQueue)

2. `unpinItem(id: UUID) -> Bool`
   - Finds item with matching ID in history
   - Sets `isPinned = false`
   - Saves to disk
   - Returns `true` if successful, `false` if item not found
   - Thread-safe (uses processingQueue)

3. `togglePinState(id: UUID) -> Bool`
   - Finds item with matching ID
   - Toggles `isPinned` state
   - Saves to disk
   - Returns new pin state (`true` if pinned, `false` if unpinned)
   - Returns `false` if item not found

4. `getHistory() -> [ClipboardHistoryItem]`
   - Returns history sorted: pinned items first (by timestamp desc), then unpinned items (by timestamp desc)
   - Maintains chronological order within pinned and unpinned groups

### 4.2 ClipboardHistoryWindow Methods

**New Methods:**
```swift
private func copyItemWithoutPasting(_ item: ClipboardHistoryItem)
private func togglePinStateForSelectedItem()
```

**Updated Methods:**
```swift
private func applySearchFilter()  // Must maintain pinned items at top
```

**Method Specifications:**

1. `copyItemWithoutPasting(_ item: ClipboardHistoryItem)`
   - Copies item to clipboard using `ClipboardManager.shared.copyToClipboard(item)`
   - Does NOT close window
   - Does NOT auto-paste
   - Shows brief visual feedback (optional animation)

2. `togglePinStateForSelectedItem()`
   - Gets currently selected item
   - Calls `ClipboardManager.shared.togglePinState(id:)`
   - Reloads history and updates UI
   - Maintains selection on same item after reload

3. `applySearchFilter()`
   - Filters history based on search text
   - Sorts results: pinned items first, then unpinned items
   - Maintains chronological order within each group

## 5. UI/UX Design

### 5.1 Cell Layout

**Current Layout:**
```
[Icon] [Type Label]
       [Preview Label]
       [Timestamp Label]
```

**Updated Layout:**
```
[Icon] [Type Label]                    [Pin] [Copy]
       [Preview Label]
       [Timestamp Label]
```

### 5.2 Button Specifications

#### Pin Button
- **Icon**: `pin.fill` (pinned) or `pin` (unpinned) from SF Symbols
- **Size**: 20x20 points
- **Position**: Right side, top area of cell
- **Spacing**: 12px from right edge, 12px from copy button
- **Visual State**:
  - Normal: Outline icon, secondary color
  - Pinned: Filled icon, accent color
  - Hover: Scale to 1.1x, show tooltip
  - Click: Brief scale animation

#### Copy Button
- **Icon**: `doc.on.doc` from SF Symbols
- **Size**: 20x20 points
- **Position**: Right side, top area of cell, left of pin button
- **Spacing**: 12px from pin button
- **Visual State**:
  - Normal: Outline icon, secondary color
  - Hover: Scale to 1.1x, accent color, show tooltip "Copy"
  - Click: Brief scale animation, checkmark icon flash

### 5.3 Visual Indicators for Pinned Items

- **Background**: Subtle tint (accent color with 0.05 alpha) on pinned items
- **Border**: Optional subtle border (1px, accent color, 0.3 alpha) on pinned items
- **Icon Container**: Slightly enhanced gradient for pinned items

### 5.4 Keyboard Shortcuts

- `Cmd+P`: Toggle pin state of selected item
- `Enter` or `Return`: Copy and auto-paste (existing behavior)
- `Double-click`: Copy and auto-paste (existing behavior)
- `Cmd+C` (when item selected): Copy without auto-paste (new)

## 6. Implementation Details

### 6.1 Sorting Logic

**Sorting Algorithm:**
1. Separate items into pinned and unpinned arrays
2. Sort each array by timestamp (descending - newest first)
3. Concatenate: pinned items first, then unpinned items

**Implementation:**
```swift
func getHistory() -> [ClipboardHistoryItem] {
    let pinned = history.filter { $0.isPinned }.sorted { $0.timestamp > $1.timestamp }
    let unpinned = history.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
    return pinned + unpinned
}
```

### 6.2 Persistence Updates

**Save Operation:**
- Include `isPinned` in `HistoryItemData` encoding
- No migration needed (defaults to `false` for existing items)

**Load Operation:**
- Decode `isPinned` from `HistoryItemData`
- Default to `false` if missing (backward compatibility)

### 6.3 Thread Safety

- All pin/unpin operations must use `processingQueue` in ClipboardManager
- UI updates must be dispatched to main queue
- History access must be thread-safe

## 7. Edge Cases

### 7.1 Pin State Edge Cases
- **Item deleted from history**: Pin state is lost (expected behavior)
- **History cleared**: All items including pinned are cleared (user decision)
- **Multiple items with same content**: Each maintains independent pin state (by ID)
- **Search with pinned items**: Pinned items appear first in search results

### 7.2 Copy Edge Cases
- **Copy button clicked**: Item copied, window stays open, no auto-paste
- **Enter/double-click**: Item copied, window closes, auto-paste (existing behavior)
- **Copy fails**: Show error feedback (optional, can be silent)

## 8. Testing Considerations

### 8.1 Unit Tests (Future)
- Pin/unpin operations
- Sorting logic with pinned items
- Persistence of pin state
- Search filtering with pinned items

### 8.2 Manual Testing Checklist
- [ ] Pin item via button click
- [ ] Unpin item via button click
- [ ] Pin item via Cmd+P keyboard shortcut
- [ ] Pinned items appear at top of list
- [ ] Pin state persists after app restart
- [ ] Search respects pinned item ordering
- [ ] Copy button copies without auto-paste
- [ ] Enter/double-click still auto-pastes
- [ ] Multiple items can be pinned
- [ ] Visual indicators show pin state correctly

## 9. Migration Strategy

### 9.1 Backward Compatibility
- Existing clipboard history items will have `isPinned = false` by default
- No data migration needed
- App will work with existing saved history

### 9.2 Version Handling
- Add `isPinned` field to `HistoryItemData`
- Use `Codable` default value handling (if supported) or manual decoding with fallback

## 10. Performance Considerations

- Sorting operation is O(n log n) but n is limited to 50 items (maxHistoryItems)
- Pin state changes trigger save operation (debounced)
- UI updates are lightweight (button state changes)
- No performance impact expected

## 11. Accessibility

- Pin button: Accessibility label "Pin item" / "Unpin item"
- Copy button: Accessibility label "Copy item"
- Keyboard navigation: Tab to focus buttons
- VoiceOver: Announce pin state changes

## 12. Future Enhancements (Out of Scope)

- Pin groups/categories
- Pin expiration dates
- Pin count limit
- Drag to reorder pinned items
- Pin shortcuts for specific items

