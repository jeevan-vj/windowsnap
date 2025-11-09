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
    
    private let pasteboard = NSPasteboard.general
    private var history: [ClipboardHistoryItem] = []
    private var lastChangeCount: Int = 0
    private var monitoringTimer: DispatchSourceTimer?

    // Background processing queue
    private let processingQueue = DispatchQueue(label: "com.windowsnap.clipboard", qos: .userInitiated)
    private let monitoringQueue = DispatchQueue(label: "com.windowsnap.clipboard.monitor", qos: .utility)

    // Debouncing for persistence
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 2.0 // Wait 2 seconds before saving
    
    // Configuration
    private let maxHistoryItems = 50
    private let monitoringInterval: TimeInterval = 0.5
    private let preferencesKey = "ClipboardHistory"

    // Size limits (in bytes)
    private let maxTextSize = 1_000_000 // 1MB for text
    private let maxImageSize = 5_000_000 // 5MB for images (after compression)
    private let maxImageDimension: CGFloat = 1920 // Max width/height for images

    // Privacy settings
    var filterSensitiveData: Bool = true
    
    override init() {
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
        guard monitoringTimer == nil else { return }

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
        // Sort with pinned items first, then unpinned items
        // Within each group, sort by timestamp (newest first)
        let pinned = history.filter { $0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        let unpinned = history.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
        return pinned + unpinned
    }
    
    func clearHistory() {
        processingQueue.async { [weak self] in
            self?.history.removeAll()
            self?.saveHistoryToDisk()
            print("📋 Clipboard history cleared")
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
        
        print("📋 Copied item to clipboard: \(item.preview)")
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
                isPinned: true
            )
            history[index] = updatedItem
            debouncedSaveHistoryToDisk()
            print("📌 Pinned item: \(item.preview)")
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
                isPinned: false
            )
            history[index] = updatedItem
            debouncedSaveHistoryToDisk()
            print("📌 Unpinned item: \(item.preview)")
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
                isPinned: newPinState
            )
            history[index] = updatedItem
            debouncedSaveHistoryToDisk()
            print("📌 \(newPinState ? "Pinned" : "Unpinned") item: \(item.preview)")
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

            let item = ClipboardHistoryItem(content: base64String, type: .image, thumbnail: thumbnail)
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
            if containsSensitiveData(newItem.content) {
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

        print("📋 Added to clipboard history: \(itemToAdd.type.displayName) - \(itemToAdd.preview)")
    }
    
    private func isValidURL(_ string: String) -> Bool {
        if let url = URL(string: string) {
            return url.scheme != nil && (url.scheme == "http" || url.scheme == "https" || url.scheme == "ftp")
        }
        return false
    }

    // MARK: - Privacy & Security

    private func containsSensitiveData(_ content: String) -> Bool {
        guard filterSensitiveData else { return false }

        // Check for various sensitive data patterns
        let sensitivePatterns: [(pattern: String, description: String)] = [
            // API Keys (various formats)
            ("(?i)(api[_-]?key|apikey|access[_-]?key)[\\s:=\"']+([a-zA-Z0-9_\\-]{20,})", "API Key"),
            ("(?i)(secret[_-]?key|secretkey)[\\s:=\"']+([a-zA-Z0-9_\\-]{20,})", "Secret Key"),

            // AWS Keys
            ("(?i)(AKIA[0-9A-Z]{16})", "AWS Access Key"),
            ("(?i)([a-zA-Z0-9+/]{40})", "AWS Secret Key"),

            // JWT Tokens
            ("eyJ[a-zA-Z0-9_\\-]+\\.eyJ[a-zA-Z0-9_\\-]+\\.[a-zA-Z0-9_\\-]+", "JWT Token"),

            // GitHub Tokens
            ("ghp_[a-zA-Z0-9]{36}", "GitHub Personal Access Token"),
            ("gho_[a-zA-Z0-9]{36}", "GitHub OAuth Token"),
            ("ghs_[a-zA-Z0-9]{36}", "GitHub Secret Token"),

            // Private Keys
            ("-----BEGIN (RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY-----", "Private Key"),

            // Credit Card Numbers (basic pattern)
            ("\\b(?:\\d[ -]*?){13,19}\\b", "Credit Card"),

            // OAuth tokens
            ("(?i)(bearer|oauth)[\\s:]+([a-zA-Z0-9_\\-\\.]{20,})", "OAuth Token"),

            // Generic token patterns
            ("(?i)(token|auth)[\\s:=\"']+([a-zA-Z0-9_\\-\\.]{32,})", "Authentication Token"),

            // Connection strings
            ("(?i)(password|pwd)[\\s:=\"']+([^\\s\"';,]{6,})", "Password"),
            ("(?i)(mongodb|mysql|postgres|postgresql)://[^\\s\"']+:[^\\s\"']+@", "Database Connection String")
        ]

        for (pattern, description) in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, options: [], range: range) != nil {
                    print("⚠️ Blocked sensitive data from clipboard history: \(description)")
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Image Processing

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
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            let historyData = try encoder.encode(history.map { item in
                HistoryItemData(
                    id: item.id.uuidString,
                    content: item.content,
                    type: item.type.rawValue,
                    timestamp: item.timestamp,
                    preview: item.preview,
                    thumbnail: item.thumbnail,
                    isPinned: item.isPinned
                )
            })

            // Verify the data size before saving
            let dataSizeInMB = Double(historyData.count) / 1_000_000.0
            if historyData.count > 10_000_000 { // 10MB limit for UserDefaults
                print("⚠️ Clipboard history too large (\(String(format: "%.2f", dataSizeInMB)) MB), trimming oldest items")
                // Trim history and retry
                let trimCount = history.count / 4 // Remove 25%
                history = Array(history.prefix(history.count - trimCount))
                saveHistoryToDisk() // Retry with smaller history
                return
            }

            UserDefaults.standard.set(historyData, forKey: preferencesKey)
        } catch {
            let clipboardError = ClipboardError.persistenceFailed(underlying: error)
            print("❌ \(clipboardError.localizedDescription)")
        }
    }
    
    private func loadHistoryFromDisk() {
        guard let historyData = UserDefaults.standard.data(forKey: preferencesKey) else {
            print("📋 No saved clipboard history found")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let historyItemData = try decoder.decode([HistoryItemData].self, from: historyData)

            // Validate and convert to ClipboardHistoryItem
            var validItems: [ClipboardHistoryItem] = []
            var corruptedCount = 0

            for data in historyItemData {
                guard let uuid = UUID(uuidString: data.id),
                      let type = ClipboardItemType(rawValue: data.type) else {
                    corruptedCount += 1
                    continue
                }

                // Additional validation: check content size
                if data.content.utf8.count > maxTextSize * 2 { // Allow larger for base64 images
                    corruptedCount += 1
                    print("⚠️ Skipping oversized item from history")
                    continue
                }

                validItems.append(ClipboardHistoryItem(
                    id: uuid,
                    content: data.content,
                    type: type,
                    timestamp: data.timestamp,
                    preview: data.preview,
                    thumbnail: data.thumbnail,
                    isPinned: data.isPinned
                ))
            }

            history = validItems

            if corruptedCount > 0 {
                print("⚠️ Skipped \(corruptedCount) corrupted items from clipboard history")
            }

            print("📋 Loaded \(history.count) items from clipboard history")

            // If we found corrupted data, save the cleaned version
            if corruptedCount > 0 {
                saveHistoryToDisk()
            }

        } catch {
            let clipboardError = ClipboardError.corruptedData(description: error.localizedDescription)
            print("❌ \(clipboardError.localizedDescription)")
            print("📋 Starting with empty clipboard history")
            history = []

            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: preferencesKey)
        }
    }
}

// MARK: - Helper Structures

private struct HistoryItemData: Codable {
    let id: String
    let content: String
    let type: String
    let timestamp: Date
    let preview: String
    let thumbnail: String? // Optional thumbnail for images
    let isPinned: Bool
    
    // Memberwise initializer for encoding
    init(id: String, content: String, type: String, timestamp: Date, preview: String, thumbnail: String?, isPinned: Bool) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.preview = preview
        self.thumbnail = thumbnail
        self.isPinned = isPinned
    }
    
    // Custom decoder to handle backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(String.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        preview = try container.decode(String.self, forKey: .preview)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(preview, forKey: .preview)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        try container.encode(isPinned, forKey: .isPinned)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, content, type, timestamp, preview, thumbnail, isPinned
    }
}

// MARK: - ClipboardHistoryItem Extension for Persistence

extension ClipboardHistoryItem {
    init(id: UUID, content: String, type: ClipboardItemType, timestamp: Date, preview: String, thumbnail: String? = nil, isPinned: Bool = false) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.preview = preview
        self.thumbnail = thumbnail
        self.isPinned = isPinned
    }
}
