import Foundation

/// Failures while creating or recovering a virtual screen.
enum VirtualDisplayError: Error, Equatable, LocalizedError {
    case unavailable
    case alreadyConnected
    case creationFailed
    case applySettingsFailed
    case displayNeverAppeared
    case screenRecordingDenied

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Virtual screens are not available on this macOS version."
        case .alreadyConnected:
            return "A WindowSnap virtual screen is already connected."
        case .creationFailed:
            return "macOS did not create the virtual screen."
        case .applySettingsFailed:
            return "The virtual screen was created but its resolutions could not be applied."
        case .displayNeverAppeared:
            return "The virtual screen was created but never appeared in Displays settings."
        case .screenRecordingDenied:
            return "Screen Recording is required to preview the virtual screen."
        }
    }
}
