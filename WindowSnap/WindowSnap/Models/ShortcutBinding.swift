import Foundation
import Carbon

struct ShortcutBinding {
    let keyCode: UInt32
    let modifierFlags: UInt32
    let identifier: String
    let gridPosition: GridPosition
    
    init(keyCode: UInt32, modifierFlags: UInt32, identifier: String, gridPosition: GridPosition) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
        self.identifier = identifier
        self.gridPosition = gridPosition
    }
    
    var displayString: String {
        var components: [String] = []
        
        if modifierFlags & UInt32(cmdKey) != 0 {
            components.append("⌘")
        }
        if modifierFlags & UInt32(optionKey) != 0 {
            components.append("⌥")
        }
        if modifierFlags & UInt32(shiftKey) != 0 {
            components.append("⇧")
        }
        if modifierFlags & UInt32(controlKey) != 0 {
            components.append("⌃")
        }
        
        components.append(keyCodeToString(keyCode))
        
        return components.joined()
    }
    
    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0x7B: return "←"  // Left Arrow
        case 0x7C: return "→"  // Right Arrow
        case 0x7E: return "↑"  // Up Arrow
        case 0x7D: return "↓"  // Down Arrow
        case 0x12: return "1"  // 1
        case 0x13: return "2"  // 2
        case 0x14: return "3"  // 3
        case 0x15: return "4"  // 4
        default: return String(keyCode)
        }
    }
}

extension ShortcutBinding: Equatable {
    static func == (lhs: ShortcutBinding, rhs: ShortcutBinding) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension ShortcutBinding: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}