import XCTest
@testable import WindowSnap

final class CaptureSessionStateMachineTests: XCTestCase {
    func testConcurrentStartRequestsCreateOnlyOneGeneration() async {
        let machine = CaptureSessionStateMachine()

        async let first = machine.requestStart()
        async let second = machine.requestStart()
        let results = await [first, second]

        XCTAssertEqual(results.compactMap { $0 }.count, 1)
    }

    func testStartTransitionsFromIdleToRunning() async throws {
        let machine = CaptureSessionStateMachine()

        let requestedToken = await machine.requestStart()
        let token = try XCTUnwrap(requestedToken)
        let startingState = await machine.state
        let didComplete = await machine.completeStart(token: token)
        let runningState = await machine.state
        XCTAssertEqual(startingState, .starting(token: token))
        XCTAssertTrue(didComplete)
        XCTAssertEqual(runningState, .running)
    }

    func testDuplicateStartIsIgnored() async throws {
        let machine = CaptureSessionStateMachine()
        let requestedToken = await machine.requestStart()
        let token = try XCTUnwrap(requestedToken)

        let duplicateStart = await machine.requestStart()
        let didComplete = await machine.completeStart(token: token)
        let startWhileRunning = await machine.requestStart()
        XCTAssertNil(duplicateStart)
        XCTAssertTrue(didComplete)
        XCTAssertNil(startWhileRunning)
    }

    func testStopDuringStartCancelsStaleCompletion() async throws {
        let machine = CaptureSessionStateMachine()
        let requestedStartToken = await machine.requestStart()
        let startToken = try XCTUnwrap(requestedStartToken)
        let requestedStopToken = await machine.requestStop()
        let stopToken = try XCTUnwrap(requestedStopToken)

        let stoppingState = await machine.state
        let staleStartCompleted = await machine.completeStart(token: startToken)
        let stopCompleted = await machine.completeStop(token: stopToken)
        let idleState = await machine.state
        XCTAssertEqual(stoppingState, .stopping)
        XCTAssertFalse(staleStartCompleted)
        XCTAssertTrue(stopCompleted)
        XCTAssertEqual(idleState, .idle)
    }

    func testDuplicateStopAndStaleStopCompletionAreIgnored() async throws {
        let machine = CaptureSessionStateMachine()
        let requestedStartToken = await machine.requestStart()
        let startToken = try XCTUnwrap(requestedStartToken)
        let startCompleted = await machine.completeStart(token: startToken)
        XCTAssertTrue(startCompleted)
        let requestedStopToken = await machine.requestStop()
        let stopToken = try XCTUnwrap(requestedStopToken)

        let duplicateStop = await machine.requestStop()
        let staleStopCompleted = await machine.completeStop(token: stopToken &+ 1)
        let stoppingState = await machine.state
        let stopCompleted = await machine.completeStop(token: stopToken)
        XCTAssertNil(duplicateStop)
        XCTAssertFalse(staleStopCompleted)
        XCTAssertEqual(stoppingState, .stopping)
        XCTAssertTrue(stopCompleted)
    }

    func testNewGenerationCannotBeCompletedByOldStart() async throws {
        let machine = CaptureSessionStateMachine()
        let requestedFirstStart = await machine.requestStart()
        let firstStart = try XCTUnwrap(requestedFirstStart)
        let requestedStop = await machine.requestStop()
        let stop = try XCTUnwrap(requestedStop)
        let stopCompleted = await machine.completeStop(token: stop)
        XCTAssertTrue(stopCompleted)
        let requestedSecondStart = await machine.requestStart()
        let secondStart = try XCTUnwrap(requestedSecondStart)

        XCTAssertNotEqual(firstStart, secondStart)
        let staleStartCompleted = await machine.completeStart(token: firstStart)
        let state = await machine.state
        XCTAssertFalse(staleStartCompleted)
        XCTAssertEqual(state, .starting(token: secondStart))
    }
}
