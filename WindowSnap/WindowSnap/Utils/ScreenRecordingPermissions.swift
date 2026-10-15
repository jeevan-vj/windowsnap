import AppKit
import Foundation
import Security

/// Screen Recording permission state for Region Share.
///
/// The state is derived **only** from `CGPreflightScreenCaptureAccess()` plus
/// what WindowSnap itself has done. ScreenCaptureKit is never consulted to
/// decide the state: `SCShareableContent.current` participates in the TCC
/// prompt flow, so probing it on every refresh produced extra system prompts
/// and a false "restart required" whenever CoreGraphics and SCK disagreed.
enum ScreenRecordingPermissionState: Equatable {
    /// WindowSnap has never asked for Screen Recording.
    case notRequested
    /// WindowSnap asked during this launch and preflight is still false. If
    /// the user approved, macOS only applies the grant after a relaunch.
    case restartRequired
    /// WindowSnap asked in an earlier launch but preflight is false now. Either
    /// the user turned it off, or the grant belongs to a differently signed
    /// copy of WindowSnap (tccd: "Failed to match existing code requirement").
    case needsRecovery
    case granted

    var statusText: String {
        switch self {
        case .notRequested: return "Not set up"
        case .restartRequired: return "Restart required"
        case .needsRecovery: return "Screen Recording is off"
        case .granted: return "Granted"
        }
    }
}

protocol ScreenRecordingPermissionProviding {
    /// Non-prompting check (`CGPreflightScreenCaptureAccess`).
    func hasAccess() -> Bool
    /// Prompting request (`CGRequestScreenCaptureAccess`).
    func requestAccess() -> Bool
    /// ScreenCaptureKit probe. The permission flow must never call this; it is
    /// part of the protocol so tests can assert that it stays unused.
    func checkAccess(completion: @escaping (Bool) -> Void)
    func openSettings()
}

protocol ScreenRecordingPermissionStoring: AnyObject {
    var hasRequestedScreenRecordingPermission: Bool { get set }
}

extension PreferencesManager: ScreenRecordingPermissionStoring {}

private struct SystemScreenRecordingPermissionProvider: ScreenRecordingPermissionProviding {
    func hasAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func checkAccess(completion: @escaping (Bool) -> Void) {
        // Intentionally not implemented with ScreenCaptureKit; see the type
        // documentation on ScreenRecordingPermissionState.
        completion(hasAccess())
    }

    func openSettings() {
        guard let url = URL(string: ScreenRecordingPermissions.settingsURLString) else { return }
        NSWorkspace.shared.open(url)
    }
}

final class ScreenRecordingPermissionCoordinator {
    static let recoveryAlertDebounce: TimeInterval = 30

    private let provider: ScreenRecordingPermissionProviding
    private let store: ScreenRecordingPermissionStoring
    private let now: () -> Date

    /// At most one `CGRequestScreenCaptureAccess` per launch.
    private(set) var hasRequestedThisLaunch = false
    private var lastRecoveryAlertDate: Date?

    init(
        provider: ScreenRecordingPermissionProviding,
        store: ScreenRecordingPermissionStoring,
        now: @escaping () -> Date = Date.init
    ) {
        self.provider = provider
        self.store = store
        self.now = now
    }

    /// Preflight-only state. Never prompts and never probes ScreenCaptureKit.
    var immediateState: ScreenRecordingPermissionState {
        if provider.hasAccess() { return .granted }
        if hasRequestedThisLaunch { return .restartRequired }
        return store.hasRequestedScreenRecordingPermission ? .needsRecovery : .notRequested
    }

    func refreshState(completion: @escaping (ScreenRecordingPermissionState) -> Void) {
        completion(immediateState)
    }

    /// Call only from an explicit user action. Prompts at most once per launch.
    @discardableResult
    func requestAccess() -> ScreenRecordingPermissionState {
        if provider.hasAccess() { return .granted }
        guard !hasRequestedThisLaunch else { return immediateState }

        hasRequestedThisLaunch = true
        store.hasRequestedScreenRecordingPermission = true
        // CGRequestScreenCaptureAccess returns false while the system prompt or
        // Settings toggle is pending; a grant only applies after a relaunch.
        return provider.requestAccess() ? .granted : immediateState
    }

    /// Explicit recovery action from the stale/mismatched-identity alert.
    /// Re-registers the current binary with TCC (so its row appears in
    /// Settings) but still never more than once per launch.
    @discardableResult
    func retryAccess() -> ScreenRecordingPermissionState {
        requestAccess()
    }

    /// Debounces the recovery alert so repeated feature triggers do not stack
    /// alerts. Records the presentation when it returns true.
    func shouldPresentRecoveryAlert() -> Bool {
        let current = now()
        if let last = lastRecoveryAlertDate,
           current.timeIntervalSince(last) < Self.recoveryAlertDebounce {
            return false
        }
        lastRecoveryAlertDate = current
        return true
    }

    func openSettings() {
        provider.openSettings()
    }
}

/// Signing identity of the running app, used to make TCC identity mismatches
/// obvious in the log.
struct AppSigningIdentity: Equatable {
    var bundlePath: String
    var bundleIdentifier: String?
    var teamIdentifier: String?
    var isAdHoc: Bool
    var isSigned: Bool

    var signingSummary: String {
        if !isSigned { return "unsigned" }
        if isAdHoc { return "ad-hoc" }
        return "team \(teamIdentifier ?? "unknown")"
    }

    /// Warnings that explain why TCC may not match a previous grant.
    var warnings: [String] {
        var result: [String] = []
        if !isSigned || isAdHoc {
            result.append("WindowSnap is \(signingSummary) signed; every rebuild changes its code identity, so macOS will not match an existing Screen Recording grant. Sign with a stable identity (see docs/REGION_SHARE_PACKAGING.md).")
        }
        if !bundlePath.hasPrefix("/Applications/") {
            result.append("WindowSnap is running from \(bundlePath), outside /Applications. Grants for another copy of WindowSnap will not apply to this one.")
        }
        return result
    }

    static func current(bundle: Bundle = .main) -> AppSigningIdentity {
        var identity = AppSigningIdentity(
            bundlePath: bundle.bundleURL.path,
            bundleIdentifier: bundle.bundleIdentifier,
            teamIdentifier: nil,
            isAdHoc: false,
            isSigned: false
        )

        var code: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &code) == errSecSuccess, let code else { return identity }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode) == errSecSuccess, let staticCode else { return identity }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return identity }

        identity.teamIdentifier = dict[kSecCodeInfoTeamIdentifier as String] as? String
        if let codeFlags = (dict[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value {
            identity.isAdHoc = codeFlags & SecCodeSignatureFlags.adhoc.rawValue != 0
        }
        identity.isSigned = dict[kSecCodeInfoIdentifier as String] != nil
        return identity
    }
}

enum ScreenRecordingPermissions {
    static let settingsURLString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"

    private static let coordinator = ScreenRecordingPermissionCoordinator(
        provider: SystemScreenRecordingPermissionProvider(),
        store: PreferencesManager.shared
    )
    private static var hasShownRestartAlert = false

    static func hasPermissions() -> Bool {
        coordinator.immediateState == .granted
    }

    static var state: ScreenRecordingPermissionState {
        coordinator.immediateState
    }

    static func refreshState(completion: @escaping (ScreenRecordingPermissionState) -> Void) {
        coordinator.refreshState(completion: completion)
    }

    /// Logs bundle path, signing identity and preflight result.
    static func logDiagnostics(reason: String) {
        let identity = AppSigningIdentity.current()
        let preflight = CGPreflightScreenCaptureAccess()
        let requested = PreferencesManager.shared.hasRequestedScreenRecordingPermission
        AppLog.permissions.info("Screen Recording diagnostics (\(reason, privacy: .public)): bundle=\(identity.bundlePath, privacy: .public) id=\(identity.bundleIdentifier ?? "nil", privacy: .public) signing=\(identity.signingSummary, privacy: .public) preflight=\(preflight, privacy: .public) previouslyRequested=\(requested, privacy: .public) state=\(coordinator.immediateState.statusText, privacy: .public)")
        for warning in identity.warnings {
            AppLog.permissions.warning("\(warning, privacy: .public)")
        }
    }

    static func requestPermissionForRegionShare(completion: @escaping (Bool) -> Void) {
        switch state {
        case .granted:
            completion(true)
        case .notRequested:
            showPrimer(completion: completion)
        case .needsRecovery:
            logDiagnostics(reason: "stale or mismatched grant")
            showRecoveryAlert(completion: completion)
        case .restartRequired:
            logDiagnostics(reason: "grant pending relaunch")
            showRestartRequiredAlert(force: true)
            completion(false)
        }
    }

    private static func showPrimer(completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Set Up Region Share"
        alert.informativeText = "Region Share needs Screen Recording access to capture only the area you select. macOS uses generic screen-and-audio wording, but WindowSnap requests no audio stream and crops the selected area locally on this Mac.\n\nAfter you allow it, restart WindowSnap so macOS applies the change."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Not Now")

        guard alert.runModal() == .alertFirstButtonReturn else {
            completion(false)
            return
        }

        let state = coordinator.requestAccess()
        if state != .granted {
            logDiagnostics(reason: "request returned \(state.statusText)")
        }
        completion(state == .granted)
    }

    /// Stale or mismatched grant: preflight is false although WindowSnap asked
    /// in an earlier launch. Explain how to clean up instead of re-prompting.
    private static func showRecoveryAlert(completion: @escaping (Bool) -> Void) {
        guard coordinator.shouldPresentRecoveryAlert() else {
            completion(false)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Screen Recording Needs Attention"
        alert.informativeText = """
        macOS is not applying a Screen Recording grant to this copy of WindowSnap. This usually happens when an older or differently signed WindowSnap was allowed instead.

        1. Open Privacy & Security > Screen & System Audio Recording.
        2. Remove every WindowSnap row (select it and click −).
        3. Add or enable this WindowSnap, then restart it.

        macOS uses generic screen-and-audio wording; WindowSnap does not capture audio.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Restart WindowSnap")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            // One registration per launch so this copy appears in the list.
            let state = coordinator.retryAccess()
            if state == .granted {
                completion(true)
                return
            }
            coordinator.openSettings()
            completion(false)
        case .alertSecondButtonReturn:
            restartApp()
            completion(false)
        default:
            completion(false)
        }
    }

    static func showRestartRequiredAlert(force: Bool = false) {
        guard force || !hasShownRestartAlert else { return }
        hasShownRestartAlert = true

        let alert = NSAlert()
        alert.messageText = "Restart WindowSnap"
        alert.informativeText = "If you allowed Screen Recording, WindowSnap needs to restart before Region Share can use it. If WindowSnap is not listed or is off, enable it in Privacy & Security > Screen & System Audio Recording first."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            restartApp()
        case .alertSecondButtonReturn:
            coordinator.openSettings()
        default:
            break
        }
    }

    /// Relaunches this exact bundle (not whichever copy LaunchServices
    /// prefers) and terminates the current instance.
    private static func restartApp() {
        let appURL = Bundle.main.bundleURL
        AppLog.permissions.info("Relaunching \(appURL.path, privacy: .public) to apply Screen Recording")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error {
                    AppLog.permissions.error("Relaunch failed: \(error.localizedDescription, privacy: .public)")
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }

    static func openScreenRecordingSettings() {
        coordinator.openSettings()
    }

    static func checkPermissionsWithAlert(completion: @escaping (Bool) -> Void) {
        requestPermissionForRegionShare(completion: completion)
    }
}
