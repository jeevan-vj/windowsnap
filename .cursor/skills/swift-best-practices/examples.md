# Swift Best Practices — Examples

Concrete before/after snippets for the rules in `SKILL.md`.

## Naming reads at the call site

```swift
// Bad — repeats type info, ambiguous
func insertElement(_ e: Element, atIndex i: Int)
list.insertElement(item, atIndex: 0)

// Good — reads as a phrase, role-based labels
func insert(_ element: Element, at index: Int)
list.insert(item, at: 0)
```

## Make illegal states unrepresentable

```swift
// Bad — optional soup, conflicting flags possible
struct Download {
    var isLoading: Bool
    var data: Data?
    var error: Error?
}

// Good — one state at a time
enum Download {
    case idle
    case loading
    case finished(Data)
    case failed(Error)
}
```

## Optionals without force-unwrap

```swift
// Bad
let url = URL(string: raw)!
let user = users.first as! Admin

// Good
guard let url = URL(string: raw) else {
    throw RequestError.invalidURL(raw)
}
guard let admin = users.first as? Admin else { return nil }
```

## Typed errors

```swift
enum RegionShareError: Error, LocalizedError {
    case displayUnavailable
    case captureFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .displayUnavailable:
            return "No display is available to share."
        case .captureFailed(let underlying):
            return "Capture failed: \(underlying.localizedDescription)"
        }
    }
}

func startSharing() throws {
    guard let display = activeDisplay else {
        throw RegionShareError.displayUnavailable
    }
    // ...
}
```

## Concurrency: actor + async, UI on MainActor

```swift
actor ClipboardStore {
    private var items: [ClipboardHistoryItem] = []

    func append(_ item: ClipboardHistoryItem) {
        items.append(item)
    }

    func recent(limit: Int) -> [ClipboardHistoryItem] {
        Array(items.suffix(limit))
    }
}

@MainActor
final class ClipboardHistoryViewModel {
    private let store: ClipboardStore
    private(set) var visibleItems: [ClipboardHistoryItem] = []

    init(store: ClipboardStore) { self.store = store }

    func refresh() async {
        visibleItems = await store.recent(limit: 50)
    }
}
```

## Avoid retain cycles

```swift
// Bad — timer strongly retains self, leaks the controller
timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    self.tick()
}

// Good
timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
    self?.tick()
}
```

## SwiftUI: extract subviews, right wrappers, modern @Observable

```swift
@Observable
final class PreferencesModel {
    var launchAtLogin = false
    var gridColumns = 3
}

struct PreferencesView: View {
    @Bindable var model: PreferencesModel

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $model.launchAtLogin)
            GridStepper(columns: $model.gridColumns)   // extracted subview
        }
    }
}

private struct GridStepper: View {
    @Binding var columns: Int
    var body: some View {
        Stepper("Columns: \(columns)", value: $columns, in: 1...6)
    }
}
```

## SwiftUI: lifecycle-bound async work

```swift
struct HistoryList: View {
    @State private var model: ClipboardHistoryViewModel

    var body: some View {
        List(model.visibleItems) { item in
            Text(item.preview)
        }
        .task {                  // auto-cancels when the view disappears
            await model.refresh()
        }
    }
}
```

## Bridging AppKit callbacks to async

```swift
func authorizeScreenRecording() async -> Bool {
    await withCheckedContinuation { continuation in
        requestScreenRecordingAccess { granted in
            continuation.resume(returning: granted)
        }
    }
}
```

## guard for the happy path

```swift
func snap(_ window: WindowInfo, to position: GridPosition) {
    guard window.isResizable else { return }
    guard let screen = window.screen else { return }
    let frame = calculator.frame(for: position, on: screen)
    window.setFrame(frame)
}
```
