import Foundation

enum GridPosition: String, CaseIterable {
    case leftHalf = "leftHalf"
    case rightHalf = "rightHalf"
    case topHalf = "topHalf"
    case bottomHalf = "bottomHalf"
    case topLeft = "topLeft"
    case topRight = "topRight"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
    case leftThird = "leftThird"
    case centerThird = "centerThird"
    case rightThird = "rightThird"
    case leftTwoThirds = "leftTwoThirds"
    case rightTwoThirds = "rightTwoThirds"
    case maximize = "maximize"
    case center = "center"
    
    var displayName: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeft: return "Top Left Quarter"
        case .topRight: return "Top Right Quarter"
        case .bottomLeft: return "Bottom Left Quarter"
        case .bottomRight: return "Bottom Right Quarter"
        case .leftThird: return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird: return "Right Third"
        case .leftTwoThirds: return "Left Two Thirds"
        case .rightTwoThirds: return "Right Two Thirds"
        case .maximize: return "Maximize"
        case .center: return "Center"
        }
    }
}