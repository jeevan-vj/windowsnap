import Foundation
import AppKit

class WindowActionHistory {
    static let shared = WindowActionHistory()
    
    // Track the last action for cycling behavior
    private var lastAction: LastActionInfo?
    private let cycleCooldown: TimeInterval = 2.0 // 2 seconds to continue cycling
    
    // SPECTACLE PRODUCTIVITY: Undo/Redo functionality
    private var undoStack: [WindowState] = []
    private var redoStack: [WindowState] = []
    private let maxHistorySize = 50
    
    private struct LastActionInfo {
        let position: GridPosition
        let windowID: String
        let cycleCount: Int
        let timestamp: Date
        let windowFrame: CGRect
    }
    
    struct WindowState {
        let windowInfo: WindowInfo
        let frame: CGRect
        let timestamp: Date
        let actionName: String
        
        init(window: WindowInfo, frame: CGRect, action: String) {
            self.windowInfo = window
            self.frame = frame
            self.timestamp = Date()
            self.actionName = action
        }
    }
    
    private init() {}
    
    // Get the next position in cycle for repeated shortcuts (like Spectacle)
    func getNextCyclePosition(for position: GridPosition, window: WindowInfo) -> GridPosition {
        let windowID = getWindowIdentifier(window)
        let now = Date()
        
        // Check if this is a continuation of the last action
        if let last = lastAction,
           last.windowID == windowID,
           last.position.cycleGroup == position.cycleGroup,
           now.timeIntervalSince(last.timestamp) < cycleCooldown {
            
            // Continue cycling
            let nextCount = last.cycleCount + 1
            let nextPosition = getCyclePosition(for: position, count: nextCount)
            
            print("🔄 CYCLING: \(position.displayName) → \(nextPosition.displayName) (cycle \(nextCount + 1))")
            
            lastAction = LastActionInfo(
                position: nextPosition,
                windowID: windowID,
                cycleCount: nextCount,
                timestamp: now,
                windowFrame: window.frame
            )
            
            return nextPosition
        } else {
            // Start new cycle
            print("🆕 NEW CYCLE: Starting with \(position.displayName)")
            
            lastAction = LastActionInfo(
                position: position,
                windowID: windowID,
                cycleCount: 0,
                timestamp: now,
                windowFrame: window.frame
            )
            
            return position
        }
    }
    
    private func getCyclePosition(for position: GridPosition, count: Int) -> GridPosition {
        switch position.cycleGroup {
        case .leftSide:
            let cycle: [GridPosition] = [.leftHalf, .leftThird, .leftTwoThirds]
            return cycle[count % cycle.count]
            
        case .rightSide:
            let cycle: [GridPosition] = [.rightHalf, .rightThird, .rightTwoThirds]
            return cycle[count % cycle.count]
            
        case .topSide:
            let cycle: [GridPosition] = [.topHalf, .maximize]
            return cycle[count % cycle.count]
            
        case .bottomSide:
            let cycle: [GridPosition] = [.bottomHalf, .maximize]
            return cycle[count % cycle.count]
            
        case .corners:
            // Corners don't cycle, return same position
            return position
            
        case .center:
            let cycle: [GridPosition] = [.center, .maximize]
            return cycle[count % cycle.count]
            
        case .thirds:
            let cycle: [GridPosition] = [.leftThird, .centerThird, .rightThird]
            return cycle[count % cycle.count]
            
        case .none:
            return position
        }
    }
    
    private func getWindowIdentifier(_ window: WindowInfo) -> String {
        return "\(window.applicationName)_\(window.windowTitle)_\(window.processID)"
    }
    
    // SPECTACLE PRODUCTIVITY: Undo/Redo methods
    func saveState(before action: String, window: WindowInfo) {
        // Save current window state before performing action
        let state = WindowState(window: window, frame: window.frame, action: action)
        undoStack.append(state)
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
        
        // Limit stack size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        print("💾 SAVED STATE: \(action) for '\(window.windowTitle)' at \(window.frame)")
    }
    
    func canUndo() -> Bool {
        return !undoStack.isEmpty
    }
    
    func canRedo() -> Bool {
        return !redoStack.isEmpty
    }
    
    func undo() -> WindowState? {
        guard !undoStack.isEmpty else {
            print("❌ UNDO: No actions to undo")
            return nil
        }
        
        let lastState = undoStack.removeLast()
        
        // Get current state of the window for redo
        if let currentWindow = WindowManager.shared.getFocusedWindow(),
           getWindowIdentifier(currentWindow) == getWindowIdentifier(lastState.windowInfo) {
            let currentState = WindowState(window: currentWindow, frame: currentWindow.frame, action: "Redo: \(lastState.actionName)")
            redoStack.append(currentState)
        }
        
        print("⏪ UNDO: Restoring '\(lastState.windowInfo.windowTitle)' to \(lastState.frame)")
        return lastState
    }
    
    func redo() -> WindowState? {
        guard !redoStack.isEmpty else {
            print("❌ REDO: No actions to redo")
            return nil
        }
        
        let nextState = redoStack.removeLast()
        
        // Get current state for future undo
        if let currentWindow = WindowManager.shared.getFocusedWindow(),
           getWindowIdentifier(currentWindow) == getWindowIdentifier(nextState.windowInfo) {
            let currentState = WindowState(window: currentWindow, frame: currentWindow.frame, action: nextState.actionName)
            undoStack.append(currentState)
        }
        
        print("⏩ REDO: Restoring '\(nextState.windowInfo.windowTitle)' to \(nextState.frame)")
        return nextState
    }
    
    func getUndoDescription() -> String? {
        return undoStack.last?.actionName
    }
    
    func getRedoDescription() -> String? {
        return redoStack.last?.actionName
    }
}

// Extension to add cycle groups to GridPosition
extension GridPosition {
    enum CycleGroup {
        case leftSide, rightSide, topSide, bottomSide, corners, center, thirds, none
    }
    
    var cycleGroup: CycleGroup {
        switch self {
        case .leftHalf, .leftTwoThirds:
            return .leftSide
        case .rightHalf, .rightTwoThirds:
            return .rightSide
        case .leftThird, .centerThird, .rightThird:
            return .thirds
        case .topHalf:
            return .topSide
        case .bottomHalf:
            return .bottomSide
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return .corners
        case .center:
            return .center
        case .maximize:
            return .none
        }
    }
}