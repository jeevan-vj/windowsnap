import XCTest
@testable import WindowSnap

final class VirtualDisplaySessionTests: XCTestCase {
    func testBeginConnectTransitionsFromDisconnected() {
        var session = VirtualDisplaySession()
        XCTAssertTrue(session.beginConnect())
        XCTAssertEqual(session.state, .connecting)
        XCTAssertTrue(session.wantsConnection)
    }

    func testBeginConnectFailsWhenUnavailableOrBusy() {
        var unavailable = VirtualDisplaySession()
        unavailable.markUnavailable()
        XCTAssertFalse(unavailable.beginConnect())
        XCTAssertEqual(unavailable.state, .unavailable)

        var connecting = VirtualDisplaySession()
        XCTAssertTrue(connecting.beginConnect())
        XCTAssertFalse(connecting.beginConnect())

        var connected = VirtualDisplaySession()
        XCTAssertTrue(connected.beginConnect())
        connected.didConnect(displayID: 42)
        XCTAssertFalse(connected.beginConnect())
        XCTAssertTrue(connected.isConnected)
        XCTAssertEqual(connected.connectedDisplayID, 42)
    }

    func testFailConnectReturnsToDisconnected() {
        var session = VirtualDisplaySession()
        XCTAssertTrue(session.beginConnect())
        session.failConnect()
        XCTAssertEqual(session.state, .disconnected)
        XCTAssertFalse(session.wantsConnection)
    }

    func testFailRecoveryKeepsReconnectIntent() {
        var session = VirtualDisplaySession()
        XCTAssertTrue(session.beginConnect())
        session.didConnect(displayID: 11)
        session.failRecovery()
        XCTAssertEqual(session.state, .disconnected)
        XCTAssertTrue(session.wantsConnection)
        XCTAssertEqual(session.recoverAfterWake(isDisplayPresent: false), .recreate)
        XCTAssertEqual(session.state, .connecting)
        XCTAssertTrue(session.wantsConnection)
    }

    func testFailRecoveryFromConnectingStaysRetryable() {
        var session = VirtualDisplaySession()
        XCTAssertTrue(session.beginConnect())
        session.failRecovery()
        XCTAssertEqual(session.state, .disconnected)
        XCTAssertTrue(session.wantsConnection)
        XCTAssertTrue(session.beginConnect())
        XCTAssertEqual(session.state, .connecting)
    }

    func testDisconnectClearsConnectionButLeavesUnavailable() {
        var session = VirtualDisplaySession()
        XCTAssertTrue(session.beginConnect())
        session.didConnect(displayID: 7)
        session.disconnect()
        XCTAssertEqual(session.state, .disconnected)
        XCTAssertFalse(session.wantsConnection)

        var unavailable = VirtualDisplaySession()
        unavailable.markUnavailable()
        unavailable.disconnect()
        XCTAssertEqual(unavailable.state, .unavailable)
    }

    func testWakeRecoveryRecreatesMissingDisplay() {
        var session = VirtualDisplaySession()
        XCTAssertTrue(session.beginConnect())
        session.didConnect(displayID: 9)

        XCTAssertEqual(session.recoverAfterWake(isDisplayPresent: true), .refreshCapture)
        XCTAssertEqual(session.state, .connected(displayID: 9))

        XCTAssertEqual(session.recoverAfterWake(isDisplayPresent: false), .recreate)
        XCTAssertEqual(session.state, .connecting)
        XCTAssertTrue(session.wantsConnection)
    }

    func testWakeRecoveryRecreatesWhenStillConnecting() {
        var session = VirtualDisplaySession()
        XCTAssertTrue(session.beginConnect())
        XCTAssertEqual(session.recoverAfterWake(isDisplayPresent: false), .recreate)
        XCTAssertEqual(session.state, .connecting)
    }

    func testWakeRecoveryIgnoresDisconnectedAndUnavailable() {
        var disconnected = VirtualDisplaySession()
        XCTAssertEqual(disconnected.recoverAfterWake(isDisplayPresent: false), .none)

        var unavailable = VirtualDisplaySession()
        unavailable.markUnavailable()
        XCTAssertEqual(unavailable.recoverAfterWake(isDisplayPresent: false), .none)
    }
}
