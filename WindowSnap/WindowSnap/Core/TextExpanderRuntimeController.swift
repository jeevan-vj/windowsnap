import Foundation

enum TextExpanderRuntimeState: Equatable {
    case disabled
    case permissionRequired
    case running

    var statusText: String {
        switch self {
        case .disabled: return "Disabled"
        case .permissionRequired: return "Enabled — Input Monitoring permission required"
        case .running: return "Enabled and running"
        }
    }
}

extension Notification.Name {
    static let textExpanderRuntimeStateDidChange = Notification.Name("TextExpanderRuntimeStateDidChange")
}

final class TextExpanderRuntimeController {
    static let shared = TextExpanderRuntimeController()

    private let manager: TextExpanderManager
    private let engine: TextExpansionEngine
    private let hasPermission: () -> Bool
    private let notificationCenter: NotificationCenter

    init(
        manager: TextExpanderManager = .shared,
        engine: TextExpansionEngine = .shared,
        hasPermission: @escaping () -> Bool = { InputMonitoringPermissions.hasPermissions() },
        notificationCenter: NotificationCenter = .default
    ) {
        self.manager = manager
        self.engine = engine
        self.hasPermission = hasPermission
        self.notificationCenter = notificationCenter
    }

    var state: TextExpanderRuntimeState {
        guard manager.isEnabled else { return .disabled }
        return hasPermission() ? .running : .permissionRequired
    }

    @discardableResult
    func setDesiredEnabled(_ enabled: Bool) -> TextExpanderRuntimeState {
        manager.isEnabled = enabled
        return reconcile()
    }

    @discardableResult
    func reconcile() -> TextExpanderRuntimeState {
        let newState = state
        switch newState {
        case .running:
            engine.start()
        case .disabled, .permissionRequired:
            engine.stop()
        }
        notificationCenter.post(name: .textExpanderRuntimeStateDidChange, object: self)
        return newState
    }
}
