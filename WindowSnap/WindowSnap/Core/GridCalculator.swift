import Foundation
import AppKit

class GridCalculator {
    
    func calculateFrame(for position: GridPosition, on screen: CGRect) -> CGRect? {
        let workingArea = screen // screen parameter should already be visibleFrame
        
        // Debug information
        print("GridCalculator: Calculating \(position.displayName)")
        print("  Working area: \(workingArea)")
        
        switch position {
        // Halves
        case .leftHalf:
            return CGRect(
                x: workingArea.minX,
                y: workingArea.minY,
                width: workingArea.width / 2,
                height: workingArea.height
            )
            
        case .rightHalf:
            return CGRect(
                x: workingArea.minX + workingArea.width / 2,
                y: workingArea.minY,
                width: workingArea.width / 2,
                height: workingArea.height
            )
            
        case .topHalf:
            return CGRect(
                x: workingArea.minX,
                y: workingArea.minY + workingArea.height / 2,
                width: workingArea.width,
                height: workingArea.height / 2
            )
            
        case .bottomHalf:
            return CGRect(
                x: workingArea.minX,
                y: workingArea.minY,
                width: workingArea.width,
                height: workingArea.height / 2
            )
            
        // Quarters
        case .topLeft:
            return CGRect(
                x: workingArea.minX,
                y: workingArea.minY + workingArea.height / 2,
                width: workingArea.width / 2,
                height: workingArea.height / 2
            )
            
        case .topRight:
            return CGRect(
                x: workingArea.minX + workingArea.width / 2,
                y: workingArea.minY + workingArea.height / 2,
                width: workingArea.width / 2,
                height: workingArea.height / 2
            )
            
        case .bottomLeft:
            return CGRect(
                x: workingArea.minX,
                y: workingArea.minY,
                width: workingArea.width / 2,
                height: workingArea.height / 2
            )
            
        case .bottomRight:
            return CGRect(
                x: workingArea.minX + workingArea.width / 2,
                y: workingArea.minY,
                width: workingArea.width / 2,
                height: workingArea.height / 2
            )
            
        // Thirds
        case .leftThird:
            return CGRect(
                x: workingArea.minX,
                y: workingArea.minY,
                width: workingArea.width / 3,
                height: workingArea.height
            )
            
        case .centerThird:
            return CGRect(
                x: workingArea.minX + workingArea.width / 3,
                y: workingArea.minY,
                width: workingArea.width / 3,
                height: workingArea.height
            )
            
        case .rightThird:
            return CGRect(
                x: workingArea.minX + (workingArea.width * 2 / 3),
                y: workingArea.minY,
                width: workingArea.width / 3,
                height: workingArea.height
            )
            
        // Two Thirds
        case .leftTwoThirds:
            return CGRect(
                x: workingArea.minX,
                y: workingArea.minY,
                width: workingArea.width * 2 / 3,
                height: workingArea.height
            )
            
        case .rightTwoThirds:
            return CGRect(
                x: workingArea.minX + workingArea.width / 3,
                y: workingArea.minY,
                width: workingArea.width * 2 / 3,
                height: workingArea.height
            )
            
        // Special cases
        case .maximize:
            return workingArea
            
        case .center:
            return calculateCenterFrame(on: workingArea)
        }
    }
    
    func getAvailableScreenArea(for screen: CGRect) -> CGRect {
        // The screen parameter should already be the visibleFrame
        // This method is kept for backward compatibility
        return screen
    }
    
    private func calculateCenterFrame(on screen: CGRect) -> CGRect {
        let defaultSize = CGSize(width: 800, height: 600)
        let centeredOrigin = CGPoint(
            x: screen.midX - defaultSize.width / 2,
            y: screen.midY - defaultSize.height / 2
        )
        
        return CGRect(origin: centeredOrigin, size: defaultSize)
    }
    
    func calculateCustomFrame(widthRatio: CGFloat, heightRatio: CGFloat, on screen: CGRect) -> CGRect {
        let workingArea = getAvailableScreenArea(for: screen)
        
        let width = workingArea.width * widthRatio
        let height = workingArea.height * heightRatio
        
        return CGRect(
            x: workingArea.minX,
            y: workingArea.minY,
            width: width,
            height: height
        )
    }
    
    func calculateFrameWithMargins(_ frame: CGRect, margins: NSEdgeInsets) -> CGRect {
        return frame.inset(by: margins)
    }
    
    func isValidFrame(_ frame: CGRect, for screen: CGRect) -> Bool {
        let workingArea = getAvailableScreenArea(for: screen)
        
        return frame.width > 100 &&
               frame.height > 100 &&
               workingArea.contains(frame)
    }
    
    func snapToGrid(_ frame: CGRect, gridSize: CGFloat) -> CGRect {
        let snappedX = round(frame.origin.x / gridSize) * gridSize
        let snappedY = round(frame.origin.y / gridSize) * gridSize
        let snappedWidth = round(frame.width / gridSize) * gridSize
        let snappedHeight = round(frame.height / gridSize) * gridSize
        
        return CGRect(
            x: snappedX,
            y: snappedY,
            width: snappedWidth,
            height: snappedHeight
        )
    }
}