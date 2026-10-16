import Carbon
import Foundation

enum KeyboardShortcutParseError: Error, Equatable {
    case empty
    case missingModifier
    case duplicateModifier(String)
    case multipleKeys
    case unknownKey(String)
}

/// A normalized global keyboard shortcut suitable for persistence and Carbon registration.
struct KeyboardShortcut: Codable, Hashable {
    let keyCode: UInt32
    let modifierFlags: UInt32

    init(keyCode: UInt32, modifierFlags: UInt32) throws {
        let supportedModifiers = UInt32(cmdKey | optionKey | shiftKey | controlKey)
        guard modifierFlags & ~supportedModifiers == 0 else {
            throw KeyboardShortcutParseError.unknownKey("modifier")
        }
        guard modifierFlags & UInt32(cmdKey | optionKey | controlKey) != 0 else {
            throw KeyboardShortcutParseError.missingModifier
        }
        guard Self.keyName(for: keyCode) != nil else {
            throw KeyboardShortcutParseError.unknownKey(String(keyCode))
        }
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    private enum CodingKeys: String, CodingKey {
        case keyCode, modifierFlags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            keyCode: container.decode(UInt32.self, forKey: .keyCode),
            modifierFlags: container.decode(UInt32.self, forKey: .modifierFlags)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifierFlags, forKey: .modifierFlags)
    }

    static func parse(_ value: String) throws -> KeyboardShortcut {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KeyboardShortcutParseError.empty
        }

        let components = value.lowercased().split(separator: "+", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard components.allSatisfy({ !$0.isEmpty }) else {
            throw KeyboardShortcutParseError.unknownKey("")
        }

        var modifiers: UInt32 = 0
        var seenModifiers: Set<String> = []
        var keyCode: UInt32?

        for component in components {
            let modifier: (name: String, flag: UInt32)?
            switch component {
            case "cmd", "command": modifier = ("command", UInt32(cmdKey))
            case "option", "alt": modifier = ("option", UInt32(optionKey))
            case "shift": modifier = ("shift", UInt32(shiftKey))
            case "ctrl", "control": modifier = ("control", UInt32(controlKey))
            default: modifier = nil
            }

            if let modifier {
                guard seenModifiers.insert(modifier.name).inserted else {
                    throw KeyboardShortcutParseError.duplicateModifier(modifier.name)
                }
                modifiers |= modifier.flag
                continue
            }

            guard keyCode == nil else { throw KeyboardShortcutParseError.multipleKeys }
            guard let parsedKey = Self.keyCode(for: component) else {
                throw KeyboardShortcutParseError.unknownKey(component)
            }
            keyCode = parsedKey
        }

        guard let keyCode else { throw KeyboardShortcutParseError.unknownKey("") }
        return try KeyboardShortcut(keyCode: keyCode, modifierFlags: modifiers)
    }

    var displayString: String {
        var components: [String] = []
        if modifierFlags & UInt32(controlKey) != 0 { components.append("ctrl") }
        if modifierFlags & UInt32(optionKey) != 0 { components.append("option") }
        if modifierFlags & UInt32(shiftKey) != 0 { components.append("shift") }
        if modifierFlags & UInt32(cmdKey) != 0 { components.append("cmd") }
        components.append(Self.keyName(for: keyCode)!)
        return components.joined(separator: "+")
    }

    var glyphString: String {
        var result = ""
        if modifierFlags & UInt32(controlKey) != 0 { result += "⌃" }
        if modifierFlags & UInt32(optionKey) != 0 { result += "⌥" }
        if modifierFlags & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifierFlags & UInt32(cmdKey) != 0 { result += "⌘" }
        switch Self.keyName(for: keyCode)! {
        case "left": result += "←"
        case "right": result += "→"
        case "up": result += "↑"
        case "down": result += "↓"
        case "return": result += "↩"
        case "space": result += "Space"
        default: result += Self.keyName(for: keyCode)!.uppercased()
        }
        return result
    }

    static func conflicts(in shortcutsByAction: [String: KeyboardShortcut]) -> [KeyboardShortcut: Set<String>] {
        let grouped = Dictionary(grouping: shortcutsByAction.keys) { shortcutsByAction[$0]! }
        return grouped.reduce(into: [:]) { conflicts, entry in
            if entry.value.count > 1 { conflicts[entry.key] = Set(entry.value) }
        }
    }

    private static func keyCode(for name: String) -> UInt32? {
        keyCodes[name == "enter" ? "return" : name == "backspace" ? "delete" : name == "semicolon" ? ";" : name]
    }

    private static func keyName(for code: UInt32) -> String? {
        keyCodes.first(where: { $0.value == code })?.key
    }

    private static let keyCodes: [String: UInt32] = [
        "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
        "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
        "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "1": 0x12,
        "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19,
        "7": 0x1A, "8": 0x1C, "0": 0x1D, "o": 0x1F, "u": 0x20, "i": 0x22,
        "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28, ";": 0x29, "n": 0x2D,
        "m": 0x2E, "tab": 0x30, "space": 0x31, "delete": 0x33, "escape": 0x35,
        "return": 0x24, "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E
    ]
}
