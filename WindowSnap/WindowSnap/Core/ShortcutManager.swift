import Foundation
import Carbon
import AppKit

enum ShortcutRegistrationResult: Equatable {
    case registered
    case invalid
    case alreadyRegistered
    case takenByAnotherApp
    case systemRejected(OSStatus)

    var failureMessage: String? {
        switch self {
        case .registered:
            return nil
        case .invalid:
            return "Enter a shortcut such as cmd+option+1."
        case .alreadyRegistered:
            return "That shortcut is already assigned to another action."
        case .takenByAnotherApp:
            return "This shortcut is already in use by macOS or another app."
        case .systemRejected:
            return "macOS could not register that shortcut. It may be used by another app."
        }
    }
}

enum BuiltInShortcutAction: String, CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, rightThird, leftTwoThirds, rightTwoThirds
    case maximize, center
    case undo, redo, nextDisplay, previousDisplay, makeLarger, makeSmaller

    var title: String {
        if let position = gridPosition { return position.displayName }
        switch self {
        case .undo: return "Undo Window Action"
        case .redo: return "Redo Window Action"
        case .nextDisplay: return "Move to Next Display"
        case .previousDisplay: return "Move to Previous Display"
        case .makeLarger: return "Make Window Larger"
        case .makeSmaller: return "Make Window Smaller"
        default: preconditionFailure("Grid action has no title")
        }
    }

    var gridPosition: GridPosition? {
        GridPosition(rawValue: rawValue)
    }
}

struct ShortcutDefaultsMigration {
    static let legacy: [String: String] = [
        "leftHalf": "cmd+shift+left", "rightHalf": "cmd+shift+right",
        "topHalf": "cmd+shift+up", "bottomHalf": "cmd+shift+down",
        "topLeft": "cmd+option+1", "topRight": "cmd+option+2",
        "bottomLeft": "cmd+option+3", "bottomRight": "cmd+option+4",
        "leftThird": "cmd+option+left", "rightThird": "cmd+option+right",
        "leftTwoThirds": "cmd+option+up", "rightTwoThirds": "cmd+option+down",
        "maximize": "cmd+shift+m", "center": "cmd+shift+c"
    ]

    static let rectangleStyle: [String: String] = [
        "leftHalf": "ctrl+option+left", "rightHalf": "ctrl+option+right",
        "topHalf": "ctrl+option+up", "bottomHalf": "ctrl+option+down",
        "topLeft": "ctrl+option+u", "topRight": "ctrl+option+i",
        "bottomLeft": "ctrl+option+j", "bottomRight": "ctrl+option+k",
        "leftThird": "ctrl+option+d", "rightThird": "ctrl+option+g",
        "leftTwoThirds": "ctrl+option+e", "rightTwoThirds": "ctrl+option+t",
        "maximize": "ctrl+option+return", "center": "ctrl+option+c"
    ]

    static func migrate(_ stored: [String: String]?, explicitlyKeptLegacy: Bool = false) -> [String: String] {
        guard !explicitlyKeptLegacy else { return stored ?? legacy }
        guard let stored else { return rectangleStyle }
        return stored == legacy ? rectangleStyle : stored
    }
}

class ShortcutManager {
    static weak var active: ShortcutManager?

    private var registeredShortcuts: [KeyboardShortcut: EventHotKeyRef] = [:]
    private var shortcutToHotKeyID: [KeyboardShortcut: UInt32] = [:]
    private var hotKeyIDToAction: [UInt32: () -> Void] = [:]
    private var shortcutToAction: [KeyboardShortcut: () -> Void] = [:]
    private(set) var registrationResults: [KeyboardShortcut: ShortcutRegistrationResult] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextHotKeyID: UInt32 = 1
    
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
        
        hotKeyIDToAction[hotKeyID.id]?()
        
        return noErr
    }
    
    func registerGlobalShortcut(_ shortcutString: String, action: @escaping () -> Void) -> Bool {
        registerGlobalShortcutDetailed(shortcutString, action: action) == .registered
    }

    func registerGlobalShortcutDetailed(_ shortcutString: String, action: @escaping () -> Void) -> ShortcutRegistrationResult {
        guard let shortcut = try? KeyboardShortcut.parse(shortcutString) else {
            AppLog.shortcuts.error("Failed to parse shortcut: \(shortcutString, privacy: .public)")
            return .invalid
        }

        if registeredShortcuts[shortcut] != nil {
            AppLog.shortcuts.notice("Shortcut already registered: \(shortcutString, privacy: .public)")
            registrationResults[shortcut] = .alreadyRegistered
            return .alreadyRegistered
        }
        
        let signature = OSType("WSAP".fourCharCodeValue)
        let keyID = nextHotKeyID
        nextHotKeyID += 1
        let hotKeyID = EventHotKeyID(signature: signature, id: keyID)
        
        var hotKeyRef: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifierFlags, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        guard result == noErr, let hotKey = hotKeyRef else {
            AppLog.shortcuts.error("Failed to register hotkey: \(shortcutString, privacy: .public)")
            let registrationResult: ShortcutRegistrationResult = result == eventHotKeyExistsErr
                ? .takenByAnotherApp
                : .systemRejected(result)
            registrationResults[shortcut] = registrationResult
            return registrationResult
        }
        
        registeredShortcuts[shortcut] = hotKey
        shortcutToHotKeyID[shortcut] = keyID
        hotKeyIDToAction[keyID] = action
        shortcutToAction[shortcut] = action
        registrationResults[shortcut] = .registered
        
        AppLog.shortcuts.debug("Registered shortcut: \(shortcutString, privacy: .public)")
        return .registered
    }

    func isValidShortcutSyntax(_ shortcutString: String) -> Bool {
        (try? KeyboardShortcut.parse(shortcutString)) != nil
    }

    func registrationResult(for shortcutString: String) -> ShortcutRegistrationResult? {
        guard let shortcut = try? KeyboardShortcut.parse(shortcutString) else { return .invalid }
        return registrationResults[shortcut]
    }
    
    func unregisterShortcut(_ shortcutString: String) {
        guard let shortcut = try? KeyboardShortcut.parse(shortcutString),
              let hotKeyRef = registeredShortcuts[shortcut],
              let keyID = shortcutToHotKeyID[shortcut] else { return }
        
        UnregisterEventHotKey(hotKeyRef)
        registeredShortcuts.removeValue(forKey: shortcut)
        shortcutToHotKeyID.removeValue(forKey: shortcut)
        hotKeyIDToAction.removeValue(forKey: keyID)
        shortcutToAction.removeValue(forKey: shortcut)
        registrationResults.removeValue(forKey: shortcut)
        
        AppLog.shortcuts.debug("Unregistered shortcut: \(shortcutString, privacy: .public)")
    }
    
    func unregisterAllShortcuts() {
        for (shortcut, hotKeyRef) in registeredShortcuts {
            UnregisterEventHotKey(hotKeyRef)
            AppLog.shortcuts.debug("Unregistered shortcut: \(shortcut.displayString, privacy: .public)")
        }
        registeredShortcuts.removeAll()
        shortcutToHotKeyID.removeAll()
        hotKeyIDToAction.removeAll()
        shortcutToAction.removeAll()
        registrationResults.removeAll()
    }
    
    func getDefaultShortcuts() -> [String: GridPosition] {
        BuiltInShortcutAction.allCases.reduce(into: [:]) { shortcuts, action in
            guard let position = action.gridPosition else { return }
            shortcuts[shortcutString(for: action)] = position
        }
    }

    func shortcutString(for action: BuiltInShortcutAction) -> String {
        PreferencesManager.shared.builtInShortcuts[action.rawValue]
            ?? ShortcutDefaultsMigration.rectangleStyle[action.rawValue]
            ?? Self.nonGridDefaults[action]!
    }

    static let nonGridDefaults: [BuiltInShortcutAction: String] = [
        .undo: "cmd+option+z", .redo: "cmd+option+shift+z",
        .nextDisplay: "ctrl+option+cmd+right", .previousDisplay: "ctrl+option+cmd+left",
        .makeLarger: "ctrl+option+shift+right", .makeSmaller: "ctrl+option+shift+left"
    ]
    
    // SPECTACLE PRODUCTIVITY: Get undo/redo shortcuts
    func getUndoRedoShortcuts() -> [String: () -> Void] {
        var shortcuts: [String: () -> Void] = [:]
        shortcuts[shortcutString(for: .undo)] = {
            let windowManager = WindowManager.shared
            if windowManager.undoLastAction() {
                AppLog.shortcuts.debug("Undo shortcut completed")
            } else {
                AppLog.shortcuts.debug("Undo shortcut had no available action")
            }
        }
        shortcuts[shortcutString(for: .redo)] = {
            let windowManager = WindowManager.shared
            if windowManager.redoLastAction() {
                AppLog.shortcuts.debug("Redo shortcut completed")
            } else {
                AppLog.shortcuts.debug("Redo shortcut had no available action")
            }
        }
        return shortcuts
    }
    
    // SPECTACLE PRODUCTIVITY: Get display switching shortcuts
    func getDisplaySwitchingShortcuts() -> [String: () -> Void] {
        var shortcuts: [String: () -> Void] = [:]
        shortcuts[shortcutString(for: .nextDisplay)] = {
            let windowManager = WindowManager.shared
            guard let focusedWindow = windowManager.getFocusedWindow() else {
                AppLog.shortcuts.notice("No active window to move")
                return
            }
            if windowManager.moveToNextDisplay(focusedWindow) {
                AppLog.shortcuts.debug("Moved window to next display")
            } else {
                AppLog.shortcuts.error("Failed to move window to next display")
            }
        }
        shortcuts[shortcutString(for: .previousDisplay)] = {
            let windowManager = WindowManager.shared
            guard let focusedWindow = windowManager.getFocusedWindow() else {
                AppLog.shortcuts.notice("No active window to move")
                return
            }
            if windowManager.moveToPreviousDisplay(focusedWindow) {
                AppLog.shortcuts.debug("Moved window to previous display")
            } else {
                AppLog.shortcuts.error("Failed to move window to previous display")
            }
        }
        return shortcuts
    }
    
    // SPECTACLE PRODUCTIVITY: Get incremental resizing shortcuts
    func getIncrementalResizingShortcuts() -> [String: () -> Void] {
        var shortcuts: [String: () -> Void] = [:]
        shortcuts[shortcutString(for: .makeLarger)] = {
            let windowManager = WindowManager.shared
            guard let focusedWindow = windowManager.getFocusedWindow() else {
                AppLog.shortcuts.notice("No active window to resize")
                return
            }
            if windowManager.makeWindowLarger(focusedWindow) {
                AppLog.shortcuts.debug("Made window larger")
            } else {
                AppLog.shortcuts.error("Failed to make window larger")
            }
        }
        shortcuts[shortcutString(for: .makeSmaller)] = {
            let windowManager = WindowManager.shared
            guard let focusedWindow = windowManager.getFocusedWindow() else {
                AppLog.shortcuts.notice("No active window to resize")
                return
            }
            if windowManager.makeWindowSmaller(focusedWindow) {
                AppLog.shortcuts.debug("Made window smaller")
            } else {
                AppLog.shortcuts.error("Failed to make window smaller")
            }
        }
        return shortcuts
    }
    
    // MARK: - Wake/Sleep Handling
    func reinitializeAfterWake() {
        AppLog.shortcuts.info("Reinitializing after wake")
        
        let savedActions = shortcutToAction
        
        for (shortcut, hotKeyRef) in registeredShortcuts {
            UnregisterEventHotKey(hotKeyRef)
            AppLog.shortcuts.debug("Unregistered for wake recovery: \(shortcut.displayString, privacy: .public)")
        }
        
        registeredShortcuts.removeAll()
        shortcutToHotKeyID.removeAll()
        hotKeyIDToAction.removeAll()
        shortcutToAction.removeAll()
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        setupEventHandler()
        
        var successCount = 0
        var failureCount = 0
        
        for (shortcut, action) in savedActions {
            if registerGlobalShortcut(shortcut.displayString, action: action) {
                successCount += 1
            } else {
                failureCount += 1
                AppLog.shortcuts.error("Failed to re-register after wake: \(shortcut.displayString, privacy: .public)")
            }
        }
        
        AppLog.shortcuts.info("Reinitialization complete: \(successCount) succeeded, \(failureCount) failed")
    }
    
    func isHealthy() -> Bool {
        return !registeredShortcuts.isEmpty && eventHandler != nil
    }
    
    func getRegisteredShortcutStrings() -> [String] {
        return shortcutToAction.keys.map(\.displayString)
    }
}
