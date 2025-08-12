import Foundation
import Carbon
import AppKit

class ShortcutManager {
    private var registeredShortcuts: [String: EventHotKeyRef] = [:]
    private var shortcutActions: [String: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    
    init() {
        setupEventHandler()
    }
    
    deinit {
        unregisterAllShortcuts()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let shortcutManager = Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            return shortcutManager.handleHotKeyEvent(theEvent)
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }
    
    private func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return noErr }
        
        var hotKeyID = EventHotKeyID()
        let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
        
        guard result == noErr else { return result }
        
        let shortcutKey = "\(hotKeyID.signature)_\(hotKeyID.id)"
        shortcutActions[shortcutKey]?()
        
        return noErr
    }
    
    func registerGlobalShortcut(_ shortcutString: String, action: @escaping () -> Void) -> Bool {
        guard let (keyCode, modifiers) = parseShortcutString(shortcutString) else {
            print("Failed to parse shortcut: \(shortcutString)")
            return false
        }
        
        let signature = OSType("WSAP".fourCharCodeValue)
        let keyID = UInt32(registeredShortcuts.count + 1)
        let hotKeyID = EventHotKeyID(signature: signature, id: keyID)
        
        var hotKeyRef: EventHotKeyRef?
        let result = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        guard result == noErr, let hotKey = hotKeyRef else {
            print("Failed to register hotkey: \(shortcutString)")
            return false
        }
        
        let shortcutKey = "\(signature)_\(keyID)"
        registeredShortcuts[shortcutString] = hotKey
        shortcutActions[shortcutKey] = action
        
        print("Successfully registered shortcut: \(shortcutString)")
        return true
    }
    
    func unregisterShortcut(_ shortcutString: String) {
        guard let hotKeyRef = registeredShortcuts[shortcutString] else { return }
        
        UnregisterEventHotKey(hotKeyRef)
        registeredShortcuts.removeValue(forKey: shortcutString)
        
        // Find the shortcut key in our actions dictionary
        let signature = OSType("WSAP".fourCharCodeValue)
        for (key, _) in shortcutActions {
            if key.hasPrefix("\(signature)_") {
                shortcutActions.removeValue(forKey: key)
                break
            }
        }
        
        print("Unregistered shortcut: \(shortcutString)")
    }
    
    func unregisterAllShortcuts() {
        for (shortcutString, hotKeyRef) in registeredShortcuts {
            UnregisterEventHotKey(hotKeyRef)
            print("Unregistered shortcut: \(shortcutString)")
        }
        registeredShortcuts.removeAll()
        shortcutActions.removeAll()
    }
    
    func getDefaultShortcuts() -> [String: GridPosition] {
        return [
            "cmd+shift+left": .leftHalf,
            "cmd+shift+right": .rightHalf,
            "cmd+shift+up": .topHalf,
            "cmd+shift+down": .bottomHalf,
            "cmd+option+1": .topLeft,
            "cmd+option+2": .topRight,
            "cmd+option+3": .bottomLeft,
            "cmd+option+4": .bottomRight,
            "cmd+option+left": .leftThird,
            "cmd+option+right": .rightThird,
            "cmd+option+up": .leftTwoThirds,
            "cmd+option+down": .rightTwoThirds,
            "cmd+shift+m": .maximize,
            "cmd+shift+c": .center
        ]
    }
    
    // SPECTACLE PRODUCTIVITY: Get undo/redo shortcuts
    func getUndoRedoShortcuts() -> [String: () -> Void] {
        return [
            "cmd+option+z": {
                let windowManager = WindowManager.shared
                if windowManager.undoLastAction() {
                    print("⏪ UNDO: Successfully undid last action")
                } else {
                    print("❌ UNDO: No actions to undo")
                }
            },
            "cmd+option+shift+z": {
                let windowManager = WindowManager.shared
                if windowManager.redoLastAction() {
                    print("⏩ REDO: Successfully redid last action")
                } else {
                    print("❌ REDO: No actions to redo")
                }
            }
        ]
    }
    
    // SPECTACLE PRODUCTIVITY: Get display switching shortcuts
    func getDisplaySwitchingShortcuts() -> [String: () -> Void] {
        return [
            "ctrl+option+cmd+right": {
                let windowManager = WindowManager.shared
                guard let focusedWindow = windowManager.getFocusedWindow() else {
                    print("❌ No active window to move")
                    return
                }
                if windowManager.moveToNextDisplay(focusedWindow) {
                    print("🖥️ Moved window to next display")
                } else {
                    print("❌ Failed to move window to next display")
                }
            },
            "ctrl+option+cmd+left": {
                let windowManager = WindowManager.shared
                guard let focusedWindow = windowManager.getFocusedWindow() else {
                    print("❌ No active window to move")
                    return
                }
                if windowManager.moveToPreviousDisplay(focusedWindow) {
                    print("🖥️ Moved window to previous display")
                } else {
                    print("❌ Failed to move window to previous display")
                }
            }
        ]
    }
    
    // SPECTACLE PRODUCTIVITY: Get incremental resizing shortcuts
    func getIncrementalResizingShortcuts() -> [String: () -> Void] {
        return [
            "ctrl+option+shift+right": {
                let windowManager = WindowManager.shared
                guard let focusedWindow = windowManager.getFocusedWindow() else {
                    print("❌ No active window to resize")
                    return
                }
                if windowManager.makeWindowLarger(focusedWindow) {
                    print("📏 Made window larger")
                } else {
                    print("❌ Failed to make window larger")
                }
            },
            "ctrl+option+shift+left": {
                let windowManager = WindowManager.shared
                guard let focusedWindow = windowManager.getFocusedWindow() else {
                    print("❌ No active window to resize")
                    return
                }
                if windowManager.makeWindowSmaller(focusedWindow) {
                    print("📏 Made window smaller")
                } else {
                    print("❌ Failed to make window smaller")
                }
            }
        ]
    }
    
    private func parseShortcutString(_ shortcut: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        let components = shortcut.lowercased().split(separator: "+").map(String.init)
        
        var modifiers: UInt32 = 0
        var keyString = ""
        
        for component in components {
            switch component {
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            case "option", "alt":
                modifiers |= UInt32(optionKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "ctrl", "control":
                modifiers |= UInt32(controlKey)
            default:
                keyString = component
            }
        }
        
        guard let keyCode = stringToKeyCode(keyString) else {
            return nil
        }
        
        return (keyCode: keyCode, modifiers: modifiers)
    }
    
    private func stringToKeyCode(_ keyString: String) -> UInt32? {
        switch keyString.lowercased() {
        // Arrow keys
        case "left":
            return 0x7B
        case "right":
            return 0x7C
        case "up":
            return 0x7E
        case "down":
            return 0x7D
            
        // Numbers
        case "1":
            return 0x12
        case "2":
            return 0x13
        case "3":
            return 0x14
        case "4":
            return 0x15
        case "5":
            return 0x17
        case "6":
            return 0x16
        case "7":
            return 0x1A
        case "8":
            return 0x1C
        case "9":
            return 0x19
        case "0":
            return 0x1D
            
        // Letters
        case "a":
            return 0x00
        case "b":
            return 0x0B
        case "c":
            return 0x08
        case "d":
            return 0x02
        case "e":
            return 0x0E
        case "f":
            return 0x03
        case "g":
            return 0x05
        case "h":
            return 0x04
        case "i":
            return 0x22
        case "j":
            return 0x26
        case "k":
            return 0x28
        case "l":
            return 0x25
        case "m":
            return 0x2E
        case "n":
            return 0x2D
        case "o":
            return 0x1F
        case "p":
            return 0x23
        case "q":
            return 0x0C
        case "r":
            return 0x0F
        case "s":
            return 0x01
        case "t":
            return 0x11
        case "u":
            return 0x20
        case "v":
            return 0x09
        case "w":
            return 0x0D
        case "x":
            return 0x07
        case "y":
            return 0x10
        case "z":
            return 0x06
            
        // Special keys
        case "space":
            return 0x31
        case "return", "enter":
            return 0x24
        case "tab":
            return 0x30
        case "escape":
            return 0x35
        case "delete":
            return 0x33
        case "backspace":
            return 0x33
            
        default:
            return nil
        }
    }
    
    // MARK: - Wake/Sleep Handling
    func reinitializeAfterWake() {
        print("🔄 Reinitializing ShortcutManager after system wake...")
        
        // Store current shortcuts and actions before clearing
        let currentShortcuts = registeredShortcuts
        let currentActions = shortcutActions
        
        // Clear current state
        registeredShortcuts.removeAll()
        shortcutActions.removeAll()
        
        // Rebuild event handler to ensure it's still working
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        setupEventHandler()
        
        // Re-register all shortcuts
        var successCount = 0
        var failureCount = 0
        
        for (shortcutString, _) in currentShortcuts {
            if let action = currentActions.values.first {
                if registerGlobalShortcut(shortcutString, action: action) {
                    successCount += 1
                } else {
                    failureCount += 1
                    print("❌ Failed to re-register shortcut after wake: \(shortcutString)")
                }
            }
        }
        
        print("✅ Shortcut reinitialization complete: \(successCount) succeeded, \(failureCount) failed")
    }
    
    func isHealthy() -> Bool {
        // Basic health check - verify we have shortcuts registered and event handler is set
        return !registeredShortcuts.isEmpty && eventHandler != nil
    }
}