import Foundation

/// Serializes capture lifecycle requests without owning the capture implementation.
/// Callers use the returned generation as a ticket for their asynchronous work.
actor CaptureSessionStateMachine {
    enum State: Equatable {
        case idle
        case starting(token: UInt64)
        case running
        case stopping
    }

    private(set) var state: State = .idle
    private var generation: UInt64 = 0

    /// Starts a new generation when idle. Duplicate starts are intentionally ignored.
    func requestStart() -> UInt64? {
        guard state == .idle else { return nil }
        generation &+= 1
        state = .starting(token: generation)
        return generation
    }

    /// Commits a completed start only when it still belongs to the active generation.
    @discardableResult
    func completeStart(token: UInt64) -> Bool {
        guard state == .starting(token: token), generation == token else { return false }
        state = .running
        return true
    }

    /// Moves an in-flight start or running session to stopping and invalidates old work.
    /// The returned token must be supplied to `completeStop(token:)`.
    func requestStop() -> UInt64? {
        switch state {
        case .idle, .stopping:
            return nil
        case .starting, .running:
            generation &+= 1
            state = .stopping
            return generation
        }
    }

    /// Returns to idle only for the currently active stop generation.
    @discardableResult
    func completeStop(token: UInt64) -> Bool {
        guard state == .stopping, generation == token else { return false }
        state = .idle
        return true
    }
}
