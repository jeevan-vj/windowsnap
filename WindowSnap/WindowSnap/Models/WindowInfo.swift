import Foundation
import CoreGraphics
import ApplicationServices

struct WindowInfo {
    let windowID: CGWindowID
    let processID: pid_t
    let applicationName: String
    let windowTitle: String
    let frame: CGRect
    let isMinimized: Bool
    let isOnScreen: Bool
    let axElement: AXUIElement?
    
    init(windowID: CGWindowID, processID: pid_t, applicationName: String, windowTitle: String, frame: CGRect, isMinimized: Bool = false, isOnScreen: Bool = true, axElement: AXUIElement? = nil) {
        self.windowID = windowID
        self.processID = processID
        self.applicationName = applicationName
        self.windowTitle = windowTitle
        self.frame = frame
        self.isMinimized = isMinimized
        self.isOnScreen = isOnScreen
        self.axElement = axElement
    }
}

extension WindowInfo: Equatable {
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.windowID == rhs.windowID
    }
}

extension WindowInfo: CustomStringConvertible {
    var description: String {
        return "WindowInfo(app: \(applicationName), title: \(windowTitle), frame: \(frame))"
    }
}