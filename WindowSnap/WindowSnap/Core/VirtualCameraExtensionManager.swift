import Foundation
import SystemExtensions

enum VirtualCameraExtensionStatus: Equatable {
    case notRequested
    case activating
    case enabled
    case needsApproval
    case willCompleteAfterReboot
    case failed(String)

    var displayText: String {
        switch self {
        case .notRequested:
            return "Not enabled"
        case .activating:
            return "Activating..."
        case .enabled:
            return "Enabled"
        case .needsApproval:
            return "Approval required in System Settings"
        case .willCompleteAfterReboot:
            return "Restart required"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
}

protocol VirtualCameraExtensionActivating: AnyObject {
    func activateExtension(identifier: String, delegate: OSSystemExtensionRequestDelegate)
}

final class VirtualCameraExtensionManager: NSObject {
    static let shared = VirtualCameraExtensionManager()
    static let extensionBundleIdentifier = "com.jeevanwijerathna.windowsnap.VirtualCameraExtension"

    private let activator: VirtualCameraExtensionActivating
    private(set) var status: VirtualCameraExtensionStatus = .notRequested {
        didSet { onStatusChanged?(status) }
    }

    var onStatusChanged: ((VirtualCameraExtensionStatus) -> Void)?

    init(activator: VirtualCameraExtensionActivating = SystemExtensionActivator()) {
        self.activator = activator
        super.init()
    }

    func activate() {
        status = .activating
        activator.activateExtension(
            identifier: Self.extensionBundleIdentifier,
            delegate: self
        )
    }

    func resetForTesting(to status: VirtualCameraExtensionStatus = .notRequested) {
        self.status = status
    }
}

extension VirtualCameraExtensionManager: OSSystemExtensionRequestDelegate {
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        status = .needsApproval
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:
            status = .enabled
        case .willCompleteAfterReboot:
            status = .willCompleteAfterReboot
        @unknown default:
            status = .failed("Unknown system extension activation result")
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        status = .failed(error.localizedDescription)
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension replacement: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        return .replace
    }
}

private final class SystemExtensionActivator: VirtualCameraExtensionActivating {
    func activateExtension(identifier: String, delegate: OSSystemExtensionRequestDelegate) {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: identifier,
            queue: .main
        )
        request.delegate = delegate
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}
