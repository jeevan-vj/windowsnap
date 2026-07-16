import Foundation
import AppKit

// MARK: - Error Types

enum ClipboardError: Error, LocalizedError {
    case persistenceFailed(underlying: Error)
    case corruptedData(description: String)
    case sizeLimitExceeded(size: Int, limit: Int)
    case imageProcessingFailed
    case invalidData(description: String)

    var errorDescription: String? {
        switch self {
        case .persistenceFailed(let error):
            return "Failed to save clipboard history: \(error.localizedDescription)"
        case .corruptedData(let description):
            return "Corrupted clipboard data: \(description)"
        case .sizeLimitExceeded(let size, let limit):
            return "Content size (\(size) bytes) exceeds limit (\(limit) bytes)"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .invalidData(let description):
            return "Invalid data: \(description)"
        }
    }
}

class ClipboardManager: NSObject {
    static let shared = ClipboardManager()

    static let retentionDefaultsKey = "ClipboardHistoryRetention"
    static let pausedDefaultsKey = "ClipboardHistoryPaused"
    
    private let pasteboard = NSPasteboard.general
    private var history: [ClipboardHistoryItem] = []
    private var lastChangeCount: Int = 0
    private var monitoringTimer: DispatchSourceTimer?
    private let store: ClipboardHistoryStore
    private let userDefaults: UserDefaults

    // Background processing queue
    private let processingQueue = DispatchQueue(label: "com.windowsnap.clipboard", qos: .userInitiated)
    private let monitoringQueue = DispatchQueue(label: "com.windowsnap.clipboard.monitor", qos: .utility)

    // Debouncing for persistence
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 2.0 // Wait 2 seconds before saving
    
    // Configuration
    private let maxHistoryItems = 50
    private let monitoringInterval: TimeInterval = 0.5

    // Size limits (in bytes)
    private let maxTextSize = 1_000_000 // 1MB for text
    private let maxImageSize = 5_000_000 // 5MB for images (after compression)
    private let maxImageDimension: CGFloat = 1920 // Max width/height for images

    override convenience init() {
        self.init(store: ClipboardHistoryStore(), userDefaults: .standard)
    }

    init(store: ClipboardHistoryStore, userDefaults: UserDefaults) {
        self.store = store
        self.userDefaults = userDefaults
        super.init()
        lastChangeCount = pasteboard.changeCount
        loadHistoryFromDisk()
    }

    deinit {
        stopMonitoring()
        print("📋 ClipboardManager deallocated")
    }

    // MARK: - Public Interface
    
    func startMonitoring() {
        guard monitoringTimer == nil, !isMonitoringPaused else { return }

        // Create a more efficient dispatch source timer
        let timer = DispatchSource.makeTimerSource(queue: monitoringQueue)
        timer.schedule(deadline: .now(), repeating: monitoringInterval)
        timer.setEventHandler { [weak self] in
            self?.checkForClipboardChanges()
        }
        timer.resume()

        monitoringTimer = timer
        print("📋 Clipboard monitoring started")
    }

    func stopMonitoring() {
        monitoringTimer?.cancel()
        monitoringTimer = nil
        print("📋 Clipboard monitoring stopped")
    }
    
    func getHistory() -> [ClipboardHistoryItem] {
        processingQueue.sync {
            let retained = ClipboardHistoryPrivacyPolicy.retainedItems(history, retention: retention)
            if retained.count != history.count {
                history = retained
                saveHistoryToDisk()
            }
            return Self.sortHistory(history)
        }
    }

    var retention: ClipboardHistoryRetention {
        get {
            guard let rawValue = userDefaults.string(forKey: Self.retentionDefaultsKey),
                  let value = ClipboardHistoryRetention(rawValue: rawValue) else {
                return .sevenDays
            }
            return value
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Self.retentionDefaultsKey)
            processingQueue.async { [weak self] in
                guard let self else { return }
                self.history = ClipboardHistoryPrivacyPolicy.retainedItems(
                    self.history,
                    retention: newValue
                )
                self.saveHistoryToDisk()
            }
        }
    }

    var isMonitoringPaused: Bool {
        userDefaults.bool(forKey: Self.pausedDefaultsKey)
    }

    func pauseMonitoring() {
        userDefaults.set(true, forKey: Self.pausedDefaultsKey)
        stopMonitoring()
    }

    func resumeMonitoring() {
        userDefaults.set(false, forKey: Self.pausedDefaultsKey)
        startMonitoring()
    }

    static func sortHistory(_ items: [ClipboardHistoryItem]) -> [ClipboardHistoryItem] {
        ClipboardHistoryFilterModel.sortPinnedFirst(items)
    }
    
    func clearHistory() {
        processingQueue.sync {
            pendingSaveWorkItem?.cancel()
            pendingSaveWorkItem = nil
            history.removeAll()
            do {
                try store.clear()
            } catch {
                print("Clipboard history could not be cleared: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteItem(id: UUID) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            self.history.removeAll { $0.id == id }
            self.debouncedSaveHistoryToDisk()
            print("📋 Deleted item from clipboard history")
        }
    }
    
    func copyToClipboard(_ item: ClipboardHistoryItem) {
        pasteboard.clearContents()
        
        switch item.type {
        case .text, .url:
            pasteboard.setString(item.content, forType: .string)
            
        case .richText:
            // For rich text, try to set both plain and rich text
            pasteboard.setString(item.content, forType: .string)
            if let rtfData = item.content.data(using: .utf8) {
                pasteboard.setData(rtfData, forType: .rtf)
            }
            
        case .image:
            // For images stored as base64 or file paths
            if let imageData = Data(base64Encoded: item.content),
               let image = NSImage(data: imageData) {
                pasteboard.writeObjects([image])
            } else if let image = NSImage(contentsOfFile: item.content) {
                pasteboard.writeObjects([image])
            }
            
        case .file:
            // For file paths
            if let url = URL(string: item.content) {
                pasteboard.writeObjects([url as NSURL])
            }
        }
        
        // Update our change count to avoid re-adding this item
        lastChangeCount = pasteboard.changeCount
        
        print("📋 Copied \(ClipboardLogMetadata.summary(for: item))")
    }
    
    // MARK: - Pin Management
    
    func pinItem(id: UUID) -> Bool {
        return processingQueue.sync {
            guard let index = history.firstIndex(where: { $0.id == id }) else {
                return false
            }
            
            let item = history[index]
            let updatedItem = ClipboardHistoryItem(
                id: item.id,
                content: item.content,
                type: item.type,
                timestamp: item.timestamp,
                preview: item.preview,
                thumbnail: item.thumbnail,
                imageWidth: item.imageWidth,
                imageHeight: item.imageHeight,
                isPinned: true
            )
            history[index] = updatedItem
            debouncedSaveHistoryToDisk()
            print("📌 Pinned clipboard item")
            return true
        }
    }
    
    func unpinItem(id: UUID) -> Bool {
        return processingQueue.sync {
            guard let index = history.firstIndex(where: { $0.id == id }) else {
                return false
            }
            
            let item = history[index]
            let updatedItem = ClipboardHistoryItem(
                id: item.id,
                content: item.content,
                type: item.type,
                timestamp: item.timestamp,
                preview: item.preview,
                thumbnail: item.thumbnail,
                imageWidth: item.imageWidth,
                imageHeight: item.imageHeight,
                isPinned: false
            )
            history[index] = updatedItem
            debouncedSaveHistoryToDisk()
            print("📌 Unpinned clipboard item")
            return true
        }
    }
    
    func togglePinState(id: UUID) -> Bool {
        return processingQueue.sync {
            guard let index = history.firstIndex(where: { $0.id == id }) else {
                return false
            }
            
            let item = history[index]
            let newPinState = !item.isPinned
            let updatedItem = ClipboardHistoryItem(
                id: item.id,
                content: item.content,
                type: item.type,
                timestamp: item.timestamp,
                preview: item.preview,
                thumbnail: item.thumbnail,
                imageWidth: item.imageWidth,
                imageHeight: item.imageHeight,
                isPinned: newPinState
            )
            history[index] = updatedItem
            debouncedSaveHistoryToDisk()
            print("📌 \(newPinState ? "Pinned" : "Unpinned") clipboard item")
            return newPinState
        }
    }
    
    // MARK: - Private Methods
    
    private func checkForClipboardChanges() {
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }

        lastChangeCount = currentChangeCount

        // Process clipboard content on background queue to avoid blocking UI
        processingQueue.async { [weak self] in
            self?.processClipboardContent()
        }
    }
    
    private func processClipboardContent() {
        guard !isMonitoringPaused,
              ClipboardHistoryPrivacyPolicy.shouldCapture(types: pasteboard.types ?? []) else {
            return
        }

        // Check for different data types in order of priority
        
        // 1. Check for files/URLs first
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [NSURL],
           let url = urls.first {
            let urlString = url.absoluteString ?? ""
            let item: ClipboardHistoryItem
            
            if url.isFileURL {
                item = ClipboardHistoryItem(content: urlString, type: .file)
            } else {
                item = ClipboardHistoryItem(content: urlString, type: .url)
            }
            
            addToHistory(item)
            return
        }
        
        // 2. Check for images
        if let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage],
           let image = images.first,
           let compressedData = compressAndResizeImage(image) {
            let base64String = compressedData.base64EncodedString()

            // Check if base64 string exceeds max size
            if base64String.utf8.count > maxImageSize * 2 { // base64 is ~1.37x larger
                print("⚠️ Image too large after base64 encoding, skipping")
                return
            }

            // Generate thumbnail for display
            let thumbnail = generateThumbnail(from: image)
            let dims = pixelDimensions(of: image)

            let item = ClipboardHistoryItem(
                content: base64String,
                type: .image,
                thumbnail: thumbnail,
                imageWidth: dims?.width,
                imageHeight: dims?.height
            )
            addToHistory(item)
            return
        }
        
        // 3. Check for rich text
        if let rtfData = pasteboard.data(forType: .rtf),
           let rtfString = String(data: rtfData, encoding: .utf8) {
            // Check size limit
            if rtfString.utf8.count > maxTextSize {
                print("⚠️ Rich text content too large (\(rtfString.utf8.count) bytes), skipping")
                return
            }
            let item = ClipboardHistoryItem(content: rtfString, type: .richText)
            addToHistory(item)
            return
        }

        // 4. Check for plain text (most common)
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Check size limit
            if string.utf8.count > maxTextSize {
                print("⚠️ Text content too large (\(string.utf8.count) bytes), skipping")
                return
            }
            // Determine if it's a URL or regular text
            let type: ClipboardItemType = isValidURL(string) ? .url : .text
            let item = ClipboardHistoryItem(content: string, type: type)
            addToHistory(item)
            return
        }
    }
    
    private func addToHistory(_ newItem: ClipboardHistoryItem) {
        // Don't add duplicate consecutive items
        if let lastItem = history.first, lastItem.content == newItem.content {
            return
        }

        // Don't add empty items
        if newItem.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }

        // Filter sensitive data (only check text-based content)
        if newItem.type == .text || newItem.type == .url || newItem.type == .richText {
            if ClipboardHistoryPrivacyPolicy.containsSensitiveData(newItem.content) {
                return
            }
        }

        // Check if there's an existing item with the same content
        // If found, preserve its pin state
        let existingItem = history.first(where: { $0.content == newItem.content })
        let shouldPreservePinState = existingItem?.isPinned ?? false
        
        // Remove any existing identical items to avoid duplicates
        history.removeAll { $0.content == newItem.content }
        
        // Create new item with preserved pin state if it was pinned
        // Use the persistence initializer from the extension
        let itemToAdd: ClipboardHistoryItem
        if shouldPreservePinState {
            // Preserve pin state but update timestamp to now (so it appears at top of pinned items)
            itemToAdd = ClipboardHistoryItem(
                id: newItem.id,
                content: newItem.content,
                type: newItem.type,
                timestamp: Date(), // Update timestamp to now
                preview: newItem.preview,
                thumbnail: newItem.thumbnail,
                imageWidth: newItem.imageWidth,
                imageHeight: newItem.imageHeight,
                isPinned: true
            )
        } else {
            itemToAdd = newItem
        }
        
        // Add to the beginning of the history
        history.insert(itemToAdd, at: 0)
        
        // Limit history size
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }

        // Use debounced save to avoid excessive disk writes
        debouncedSaveHistoryToDisk()

        print("📋 Added \(ClipboardLogMetadata.summary(for: itemToAdd)) to clipboard history")
    }
    
    private func isValidURL(_ string: String) -> Bool {
        if let url = URL(string: string) {
            return url.scheme != nil && (url.scheme == "http" || url.scheme == "https" || url.scheme == "ftp")
        }
        return false
    }

    // MARK: - Image Processing

    private func pixelDimensions(of image: NSImage) -> (width: Int, height: Int)? {
        for rep in image.representations {
            if let bitmap = rep as? NSBitmapImageRep {
                let w = bitmap.pixelsWide
                let h = bitmap.pixelsHigh
                if w > 0, h > 0 {
                    return (w, h)
                }
            }
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let w = max(1, Int(image.size.width * scale))
        let h = max(1, Int(image.size.height * scale))
        return (w, h)
    }

    private func generateThumbnail(from image: NSImage, maxSize: CGFloat = 100) -> String? {
        let originalSize = image.size
        let ratio = min(maxSize / originalSize.width, maxSize / originalSize.height)
        let thumbnailSize = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)

        // Create thumbnail
        let thumbnail = NSImage(size: thumbnailSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                  from: NSRect(origin: .zero, size: originalSize),
                  operation: .copy,
                  fraction: 1.0)
        thumbnail.unlockFocus()

        // Convert to JPEG with high compression for small size
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) else {
            return nil
        }

        return jpegData.base64EncodedString()
    }

    private func compressAndResizeImage(_ image: NSImage) -> Data? {
        // Get the image size
        let originalSize = image.size

        // Calculate new size if needed
        var newSize = originalSize
        if originalSize.width > maxImageDimension || originalSize.height > maxImageDimension {
            let ratio = min(maxImageDimension / originalSize.width, maxImageDimension / originalSize.height)
            newSize = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)
        }

        // Create resized image if needed
        let imageToCompress: NSImage
        if newSize != originalSize {
            let resizedImage = NSImage(size: newSize)
            resizedImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize),
                      from: NSRect(origin: .zero, size: originalSize),
                      operation: .copy,
                      fraction: 1.0)
            resizedImage.unlockFocus()
            imageToCompress = resizedImage
        } else {
            imageToCompress = image
        }

        // Convert to JPEG with compression for better size control
        guard let tiffData = imageToCompress.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        // Try JPEG compression first (better compression)
        if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            if jpegData.count <= maxImageSize {
                return jpegData
            }
            // Try with more compression
            if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.5]) {
                if jpegData.count <= maxImageSize {
                    return jpegData
                }
            }
        }

        // Fall back to PNG if JPEG doesn't work
        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            if pngData.count <= maxImageSize {
                return pngData
            }
        }

        print("⚠️ Image too large even after compression, skipping")
        return nil
    }

    // MARK: - Persistence

    private func debouncedSaveHistoryToDisk() {
        // Cancel any pending save operation
        pendingSaveWorkItem?.cancel()

        // Create a new work item to save after the debounce interval
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveHistoryToDisk()
        }

        pendingSaveWorkItem = workItem

        // Schedule the save operation
        processingQueue.asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }

    private func saveHistoryToDisk() {
        do {
            history = ClipboardHistoryPrivacyPolicy.retainedItems(history, retention: retention)
            if retention.persistsToDisk {
                try store.save(history)
            } else {
                try store.clear()
            }
        } catch {
            let clipboardError = ClipboardError.persistenceFailed(underlying: error)
            print("❌ \(clipboardError.localizedDescription)")
        }
    }
    
    private func loadHistoryFromDisk() {
        guard retention.persistsToDisk else {
            try? store.clear()
            return
        }

        let loaded = store.load()
        history = ClipboardHistoryPrivacyPolicy.retainedItems(loaded, retention: retention)
        if history.count != loaded.count {
            saveHistoryToDisk()
        }
    }
}
