import Foundation
import AppKit

class ClipboardManager: NSObject {
    static let shared = ClipboardManager()
    
    private let pasteboard = NSPasteboard.general
    private var history: [ClipboardHistoryItem] = []
    private var lastChangeCount: Int = 0
    private var monitoringTimer: Timer?
    
    // Configuration
    private let maxHistoryItems = 50
    private let monitoringInterval: TimeInterval = 0.5
    private let preferencesKey = "ClipboardHistory"
    
    override init() {
        super.init()
        lastChangeCount = pasteboard.changeCount
        loadHistoryFromDisk()
    }
    
    // MARK: - Public Interface
    
    func startMonitoring() {
        guard monitoringTimer == nil else { return }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: monitoringInterval, repeats: true) { [weak self] _ in
            self?.checkForClipboardChanges()
        }
        
        print("📋 Clipboard monitoring started")
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        print("📋 Clipboard monitoring stopped")
    }
    
    func getHistory() -> [ClipboardHistoryItem] {
        return history
    }
    
    func clearHistory() {
        history.removeAll()
        saveHistoryToDisk()
        print("📋 Clipboard history cleared")
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
    
    // MARK: - Private Methods
    
    private func checkForClipboardChanges() {
        let currentChangeCount = pasteboard.changeCount
        
        guard currentChangeCount != lastChangeCount else { return }
        
        lastChangeCount = currentChangeCount
        processClipboardContent()
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
           let imageData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: imageData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            let base64String = pngData.base64EncodedString()
            let item = ClipboardHistoryItem(content: base64String, type: .image)
            addToHistory(item)
            return
        }
        
        // 3. Check for rich text
        if let rtfData = pasteboard.data(forType: .rtf),
           let rtfString = String(data: rtfData, encoding: .utf8) {
            let item = ClipboardHistoryItem(content: rtfString, type: .richText)
            addToHistory(item)
            return
        }
        
        // 4. Check for plain text (most common)
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
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
        
        // Remove any existing identical items to avoid duplicates
        history.removeAll { $0.content == newItem.content }
        
        // Add to the beginning of the history
        history.insert(newItem, at: 0)
        
        // Limit history size
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        saveHistoryToDisk()
        
        print("📋 Added to clipboard history: \(newItem.type.displayName) - \(newItem.preview)")
    }
    
    private func isValidURL(_ string: String) -> Bool {
        if let url = URL(string: string) {
            return url.scheme != nil && (url.scheme == "http" || url.scheme == "https" || url.scheme == "ftp")
        }
        return false
    }
    
    // MARK: - Persistence
    
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
                    preview: item.preview
                )
            })
            
            UserDefaults.standard.set(historyData, forKey: preferencesKey)
        } catch {
            print("❌ Failed to save clipboard history: \(error)")
        }
    }
    
    private func loadHistoryFromDisk() {
        guard let historyData = UserDefaults.standard.data(forKey: preferencesKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let historyItemData = try decoder.decode([HistoryItemData].self, from: historyData)
            
            history = historyItemData.compactMap { data in
                guard let uuid = UUID(uuidString: data.id),
                      let type = ClipboardItemType(rawValue: data.type) else { return nil }
                
                return ClipboardHistoryItem(
                    id: uuid,
                    content: data.content,
                    type: type,
                    timestamp: data.timestamp,
                    preview: data.preview
                )
            }
            
            print("📋 Loaded \(history.count) items from clipboard history")
        } catch {
            print("❌ Failed to load clipboard history: \(error)")
            history = []
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
}

// MARK: - ClipboardHistoryItem Extension for Persistence

extension ClipboardHistoryItem {
    init(id: UUID, content: String, type: ClipboardItemType, timestamp: Date, preview: String) {
        self.id = id
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.preview = preview
    }
}
