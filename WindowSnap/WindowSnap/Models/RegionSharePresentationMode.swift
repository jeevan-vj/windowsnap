import Foundation

enum RegionSharePresentationMode: String, Codable, CaseIterable {
    case floatingMirror
    case virtualDisplayWindow

    var windowTitle: String {
        switch self {
        case .floatingMirror:
            return "Region Share"
        case .virtualDisplayWindow:
            return "WindowSnap Virtual Display"
        }
    }

    var menuTitle: String {
        switch self {
        case .floatingMirror:
            return "Show Region Share"
        case .virtualDisplayWindow:
            return "Show Virtual Display Window"
        }
    }
}
