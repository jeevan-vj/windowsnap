import Foundation
import AppKit

/// Engine that performs text expansion by replacing triggers with configured text
class TextExpansionEngine {
    static let shared = TextExpansionEngine()
    
    private var isExpanding = false
    private let expansionQueue = DispatchQueue(label: "com.windowsnap.textexpansion", qos: .userInteractive)
    
    private init() {
        setupTriggerCallback()
    }
    
    private func setupTriggerCallback() {
        GlobalKeyCaptureService.shared.onTriggerMatch = { [weak self] snippet, triggerLength in
            self?.performExpansion(snippet: snippet, triggerLength: triggerLength)
        }
    }
    
    // MARK: - Expansion
    
    func performExpansion(snippet: TextExpansionSnippet, triggerLength: Int) {
        guard !isExpanding else {
            print("⚠️ Expansion already in progress, skipping")
            return
        }
        
        isExpanding = true
        GlobalKeyCaptureService.shared.setExpanding(true)
        
        print("📝 Expanding: '\(snippet.trigger)' → '\(snippet.replacement.prefix(30))...'")
        
        let pasteboard = NSPasteboard.general
        let previousContents = backupClipboard(pasteboard)
        let previousChangeCount = pasteboard.changeCount
        
        let replacementText = processReplacementText(snippet.replacement)
        
        expansionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.deleteCharacters(count: triggerLength)
            
            usleep(30000)
            
            DispatchQueue.main.async {
                pasteboard.clearContents()
                pasteboard.setString(replacementText, forType: .string)
                
                usleep(20000)
                
                self.simulatePaste()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.restoreClipboard(pasteboard, contents: previousContents, previousChangeCount: previousChangeCount)
                    
                    self.isExpanding = false
                    GlobalKeyCaptureService.shared.setExpanding(false)
                    
                    print("✅ Expansion complete")
                }
            }
        }
    }
    
    // MARK: - Clipboard Management
    
    private struct ClipboardContents {
        var items: [(NSPasteboard.PasteboardType, Data)] = []
        var string: String?
    }
    
    private func backupClipboard(_ pasteboard: NSPasteboard) -> ClipboardContents {
        var contents = ClipboardContents()
        
        if let string = pasteboard.string(forType: .string) {
            contents.string = string
        }
        
        if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        contents.items.append((type, data))
                    }
                }
            }
        }
        
        return contents
    }
    
    private func restoreClipboard(_ pasteboard: NSPasteboard, contents: ClipboardContents, previousChangeCount: Int) {
        guard pasteboard.changeCount != previousChangeCount else {
            return
        }
        
        pasteboard.clearContents()
        
        if !contents.items.isEmpty {
            let item = NSPasteboardItem()
            for (type, data) in contents.items {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        } else if let string = contents.string {
            pasteboard.setString(string, forType: .string)
        }
        
        print("📋 Clipboard restored")
    }
    
    // MARK: - Text Processing
    
    private func processReplacementText(_ text: String) -> String {
        var result = text
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: Date()))
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        result = result.replacingOccurrences(of: "{time}", with: timeFormatter.string(from: Date()))
        
        let isoFormatter = ISO8601DateFormatter()
        result = result.replacingOccurrences(of: "{isodate}", with: isoFormatter.string(from: Date()))
        
        return result
    }
    
    // MARK: - Keyboard Simulation
    
    private func deleteCharacters(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        
        for _ in 0..<count {
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
            usleep(5000)
        }
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
        
        print("📋 Simulated paste command")
    }
    
    // MARK: - Public Interface
    
    func start() {
        guard TextExpanderManager.shared.isEnabled else {
            print("📝 Text expander is disabled")
            return
        }
        
        GlobalKeyCaptureService.shared.start()
        print("📝 TextExpansionEngine started")
    }
    
    func stop() {
        GlobalKeyCaptureService.shared.stop()
        isExpanding = false
        print("📝 TextExpansionEngine stopped")
    }
    
    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
        }
    }
}
