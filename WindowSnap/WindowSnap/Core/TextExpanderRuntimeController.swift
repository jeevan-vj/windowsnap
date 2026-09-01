import Foundation

enum TextExpanderRuntimeState: Equatable {
    case disabled
    case needsPermission(Set<PermissionKind>)
    case running

    var statusText: String {
        switch self {
        case .disabled: return "Disabled"
        case .needsPermission(let missing):
            let names = missing.map(\.displayName).sorted().joined(separator: " and ")
            return "Setup needed — \(names)"
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
    private let missingPermissions: () -> Set<PermissionKind>
    private let notificationCenter: NotificationCenter

    init(
        manager: TextExpanderManager = .shared,
        engine: TextExpansionEngine = .shared,
        missingPermissions: @escaping () -> Set<PermissionKind> = { InputMonitoringPermissions.missingPermissions() },
        notificationCenter: NotificationCenter = .default
    ) {
        self.manager = manager
        self.engine = engine
        self.missingPermissions = missingPermissions
        self.notificationCenter = notificationCenter
    }

    var state: TextExpanderRuntimeState {
        let missing = missingPermissions()
        if !missing.isEmpty { return .needsPermission(missing) }
        return manager.isEnabled ? .running : .disabled
    }

    @discardableResult
    func setDesiredEnabled(_ enabled: Bool) -> TextExpanderRuntimeState {
        let missing = missingPermissions()
        manager.isEnabled = enabled && missing.isEmpty
        return reconcile()
    }

    @discardableResult
    func reconcile() -> TextExpanderRuntimeState {
        let missing = missingPermissions()
        if !missing.isEmpty {
            manager.isEnabled = false
        }
        let newState: TextExpanderRuntimeState = missing.isEmpty
            ? (manager.isEnabled ? .running : .disabled)
            : .needsPermission(missing)
        switch newState {
        case .running:
            engine.start()
        case .disabled, .needsPermission:
            engine.stop()
        }
        notificationCenter.post(name: .textExpanderRuntimeStateDidChange, object: self)
        return newState
    }
}
