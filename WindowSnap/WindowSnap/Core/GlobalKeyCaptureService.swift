import Foundation
import AppKit
import Carbon

/// Service that captures global keyboard events to detect text expansion triggers
class GlobalKeyCaptureService {
    static let shared = GlobalKeyCaptureService()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    
    private var typeBuffer: String = ""
    private let maxBufferLength = 64
    
    private var isExpanding = false
    
    var onTriggerMatch: ((TextExpansionSnippet, Int) -> Void)?
    
    private init() {}
    
    // MARK: - Lifecycle
    
    func start() {
        guard !isRunning else {
            print("⌨️ GlobalKeyCaptureService already running")
            return
        }
        
        guard InputMonitoringPermissions.hasPermissions() else {
            print("⚠️ Input Monitoring permission not granted - text expander disabled")
            return
        }
        
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                
                let service = Unmanaged<GlobalKeyCaptureService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else {
            print("❌ Failed to create event tap - check Input Monitoring permissions")
            return
        }
        
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        guard let runLoopSource = runLoopSource else {
            print("❌ Failed to create run loop source")
            return
        }
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        isRunning = true
        print("⌨️ GlobalKeyCaptureService started")
    }
    
    func stop() {
        guard isRunning else { return }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        typeBuffer = ""
        
        print("⌨️ GlobalKeyCaptureService stopped")
    }
    
    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.start()
        }
    }
    
    // MARK: - Event Handling
    
    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        guard !isExpanding else {
            return Unmanaged.passRetained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        let hasCommand = flags.contains(.maskCommand)
        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)
        
        if hasCommand || hasControl {
            clearBuffer()
            return Unmanaged.passRetained(event)
        }
        
        if keyCode == 48 {
            if let snippet = TextExpanderManager.shared.findMatchingSnippet(for: typeBuffer) {
                let triggerLength = snippet.trigger.count
                
                DispatchQueue.main.async { [weak self] in
                    self?.onTriggerMatch?(snippet, triggerLength)
                }
                
                clearBuffer()
                return nil
            }
            
            return Unmanaged.passRetained(event)
        }
        
        if keyCode == 53 {
            clearBuffer()
            return Unmanaged.passRetained(event)
        }
        
        if keyCode == 51 {
            if !typeBuffer.isEmpty {
                typeBuffer.removeLast()
            }
            return Unmanaged.passRetained(event)
        }
        
        if keyCode == 36 || keyCode == 76 {
            clearBuffer()
            return Unmanaged.passRetained(event)
        }
        
        if let char = characterForKeyCode(keyCode, flags: flags) {
            appendToBuffer(char)
        }
        
        return Unmanaged.passRetained(event)
    }
    
    // MARK: - Buffer Management
    
    private func appendToBuffer(_ char: Character) {
        typeBuffer.append(char)
        
        if typeBuffer.count > maxBufferLength {
            let dropCount = typeBuffer.count - maxBufferLength
            typeBuffer = String(typeBuffer.dropFirst(dropCount))
        }
    }
    
    func clearBuffer() {
        typeBuffer = ""
    }
    
    func setExpanding(_ expanding: Bool) {
        isExpanding = expanding
    }
    
    // MARK: - Key Code Translation
    
    private func characterForKeyCode(_ keyCode: Int64, flags: CGEventFlags) -> Character? {
        let hasShift = flags.contains(.maskShift)
        let hasCapsLock = flags.contains(.maskAlphaShift)
        let effectiveShift = hasShift != hasCapsLock
        
        let keyMap: [Int64: (normal: Character, shifted: Character)] = [
            0: ("a", "A"), 1: ("s", "S"), 2: ("d", "D"), 3: ("f", "F"),
            4: ("h", "H"), 5: ("g", "G"), 6: ("z", "Z"), 7: ("x", "X"),
            8: ("c", "C"), 9: ("v", "V"), 11: ("b", "B"), 12: ("q", "Q"),
            13: ("w", "W"), 14: ("e", "E"), 15: ("r", "R"), 16: ("y", "Y"),
            17: ("t", "T"), 18: ("1", "!"), 19: ("2", "@"), 20: ("3", "#"),
            21: ("4", "$"), 22: ("6", "^"), 23: ("5", "%"), 24: ("=", "+"),
            25: ("9", "("), 26: ("7", "&"), 27: ("-", "_"), 28: ("8", "*"),
            29: ("0", ")"), 30: ("]", "}"), 31: ("o", "O"), 32: ("u", "U"),
            33: ("[", "{"), 34: ("i", "I"), 35: ("p", "P"), 37: ("l", "L"),
            38: ("j", "J"), 39: ("'", "\""), 40: ("k", "K"), 41: (";", ":"),
            42: ("\\", "|"), 43: (",", "<"), 44: ("/", "?"), 45: ("n", "N"),
            46: ("m", "M"), 47: (".", ">"), 50: ("`", "~"),
            49: (" ", " "),
        ]
        
        guard let mapping = keyMap[keyCode] else {
            return nil
        }
        
        return effectiveShift ? mapping.shifted : mapping.normal
    }
}
