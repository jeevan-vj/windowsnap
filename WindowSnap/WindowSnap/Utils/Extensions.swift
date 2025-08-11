import Foundation
import CoreGraphics
import AppKit

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for char in self {
            result = (result << 8) | FourCharCode(char.asciiValue ?? 0)
        }
        return result
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    func scaled(by factor: CGFloat) -> CGRect {
        let newWidth = width * factor
        let newHeight = height * factor
        let newX = midX - (newWidth / 2)
        let newY = midY - (newHeight / 2)
        return CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
    }
    
    func inset(by insets: NSEdgeInsets) -> CGRect {
        return CGRect(
            x: minX + insets.left,
            y: minY + insets.bottom,
            width: width - insets.left - insets.right,
            height: height - insets.top - insets.bottom
        )
    }
}

extension CGSize {
    func aspectRatio() -> CGFloat {
        return height == 0 ? 0 : width / height
    }
    
    func scaled(by factor: CGFloat) -> CGSize {
        return CGSize(width: width * factor, height: height * factor)
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
    
    func offset(by point: CGPoint) -> CGPoint {
        return CGPoint(x: x + point.x, y: y + point.y)
    }
}

extension NSScreen {
    var displayName: String {
        return localizedName
    }
    
    var isMainScreen: Bool {
        return self == NSScreen.main
    }
    
    var workingArea: CGRect {
        return visibleFrame
    }
}