import Foundation

enum PermissionKind: String, CaseIterable, Hashable {
    case accessibility
    case inputMonitoring
    case screenRecording

    var displayName: String {
        switch self {
        case .accessibility: return "Accessibility"
        case .inputMonitoring: return "Input Monitoring"
        case .screenRecording: return "Screen Recording"
        }
    }
}
