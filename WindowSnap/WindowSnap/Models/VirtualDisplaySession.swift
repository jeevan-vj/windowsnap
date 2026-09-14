import CoreGraphics
import Foundation

enum VirtualDisplayConnectionState: Equatable {
    case disconnected
    case unavailable
    case connecting
    case connected(displayID: CGDirectDisplayID)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

enum VirtualDisplayWakeAction: Equatable {
    case none
    case refreshCapture
    case recreate
}

/// Connection state for a single virtual screen, independent of AppKit and SPI.
struct VirtualDisplaySession: Equatable {
    private(set) var state: VirtualDisplayConnectionState = .disconnected
    private(set) var wantsConnection = false

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    var connectedDisplayID: CGDirectDisplayID? {
        if case .connected(let displayID) = state { return displayID }
        return nil
    }

    mutating func markUnavailable() {
        state = .unavailable
        wantsConnection = false
    }

    /// Transitions from disconnected to connecting. Returns false if the session cannot start.
    mutating func beginConnect() -> Bool {
        switch state {
        case .disconnected:
            wantsConnection = true
            state = .connecting
            return true
        case .unavailable, .connecting, .connected:
            return false
        }
    }

    mutating func didConnect(displayID: CGDirectDisplayID) {
        guard wantsConnection else { return }
        state = .connected(displayID: displayID)
    }

    mutating func failConnect() {
        wantsConnection = false
        if state != .unavailable {
            state = .disconnected
        }
    }

    /// Keeps reconnect intent after a failed recovery so wake or Connect can retry.
    mutating func failRecovery() {
        guard wantsConnection else { return }
        if state != .unavailable {
            state = .disconnected
        }
    }

    mutating func disconnect() {
        wantsConnection = false
        if state != .unavailable {
            state = .disconnected
        }
    }

    /// Decides whether wake recovery should rebuild the display or only restart capture.
    mutating func recoverAfterWake(isDisplayPresent: Bool) -> VirtualDisplayWakeAction {
        guard wantsConnection else { return .none }
        switch state {
        case .connected:
            if isDisplayPresent {
                return .refreshCapture
            }
            state = .connecting
            return .recreate
        case .connecting:
            return .recreate
        case .disconnected:
            state = .connecting
            return .recreate
        case .unavailable:
            return .none
        }
    }
}
