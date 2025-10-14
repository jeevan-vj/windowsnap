import Foundation
import AppKit

/// Represents a position option in the window throw interface
struct ThrowPosition {
    let gridPosition: GridPosition
    let frame: CGRect
    let keyIndex: Int
    let displayName: String
    let shortDisplayName: String
    
    init(gridPosition: GridPosition, frame: CGRect, keyIndex: Int) {
        self.gridPosition = gridPosition
        self.frame = frame
        self.keyIndex = keyIndex
        self.displayName = gridPosition.displayName
        
        // Create short names for overlay display
        switch gridPosition {
        case .leftHalf: self.shortDisplayName = "Left ½"
        case .rightHalf: self.shortDisplayName = "Right ½"
        case .topHalf: self.shortDisplayName = "Top ½"
        case .bottomHalf: self.shortDisplayName = "Bottom ½"
        case .topLeft: self.shortDisplayName = "Top L"
        case .topRight: self.shortDisplayName = "Top R"
        case .bottomLeft: self.shortDisplayName = "Bottom L"
        case .bottomRight: self.shortDisplayName = "Bottom R"
        case .leftThird: self.shortDisplayName = "Left ⅓"
        case .centerThird: self.shortDisplayName = "Center ⅓"
        case .rightThird: self.shortDisplayName = "Right ⅓"
        case .leftTwoThirds: self.shortDisplayName = "Left ⅔"
        case .rightTwoThirds: self.shortDisplayName = "Right ⅔"
        case .maximize: self.shortDisplayName = "Max"
        case .center: self.shortDisplayName = "Center"
        }
    }
}

/// Calculates all possible throw positions for a given screen
class ThrowPositionCalculator {
    
    /// Generate all throw positions for the given screen
    func calculateThrowPositions(for screen: NSScreen) -> [ThrowPosition] {
        let screenFrame = screen.visibleFrame
        let gridCalculator = GridCalculator()
        
        var positions: [ThrowPosition] = []
        var keyIndex = 1
        
        // Define the order of positions (most commonly used first)
        let positionOrder: [GridPosition] = [
            .leftHalf, .rightHalf, .topHalf, .bottomHalf,        // 1-4: Halves
            .topLeft, .topRight, .bottomLeft, .bottomRight,      // 5-8: Quarters  
            .leftThird, .centerThird, .rightThird,               // 9-11: Thirds
            .leftTwoThirds, .rightTwoThirds,                     // 12-13: Two thirds
            .maximize, .center                                    // 14-15: Special
        ]
        
        for gridPosition in positionOrder {
            guard let frame = gridCalculator.calculateFrame(for: gridPosition, on: screenFrame) else {
                continue
            }
            
            let throwPosition = ThrowPosition(
                gridPosition: gridPosition,
                frame: frame,
                keyIndex: keyIndex
            )
            
            positions.append(throwPosition)
            keyIndex += 1
            
            // Limit to 15 positions (1-9, 0, A-F gives us 16 total, but 0 can be escape)
            if keyIndex > 15 {
                break
            }
        }
        
        return positions
    }
    
    /// Get the key character for a given index (1-9, 0, A-F)
    func getKeyCharacter(for index: Int) -> String {
        switch index {
        case 1...9:
            return String(index)
        case 10:
            return "0"
        case 11:
            return "A"
        case 12:
            return "B"
        case 13:
            return "C"
        case 14:
            return "D"
        case 15:
            return "E"
        case 16:
            return "F"
        default:
            return "?"
        }
    }
    
    /// Parse key character back to index
    func getIndexForKey(_ key: String) -> Int? {
        switch key.uppercased() {
        case "1"..."9":
            return Int(key)
        case "0":
            return 10
        case "A":
            return 11
        case "B":
            return 12
        case "C":
            return 13
        case "D":
            return 14
        case "E":
            return 15
        case "F":
            return 16
        default:
            return nil
        }
    }
}
