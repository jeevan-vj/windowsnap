import XCTest
@testable import WindowSnap

final class FakeVirtualDisplayAdapter: VirtualDisplayCreating {
    var isAvailable = true
    var isConnected = false
    var displayID: CGDirectDisplayID?
    private(set) var connectCallCount = 0

    func connect(presets: [VirtualDisplayPreset]) throws -> CGDirectDisplayID {
        guard isAvailable else { throw VirtualDisplayError.unavailable }
        connectCallCount += 1
        isConnected = true
        displayID = 99
        return 99
    }

    func disconnect() {
        isConnected = false
        displayID = nil
    }
}

final class VirtualDisplayAdapterTests: XCTestCase {
    func testFakeAdapterConnectsAndDisconnectsWithoutSPI() throws {
        let adapter = FakeVirtualDisplayAdapter()
        XCTAssertEqual(try adapter.connect(presets: VirtualDisplayPreset.all), 99)
        XCTAssertTrue(adapter.isConnected)
        XCTAssertEqual(adapter.connectCallCount, 1)

        adapter.disconnect()
        XCTAssertFalse(adapter.isConnected)
        XCTAssertNil(adapter.displayID)
    }

    func testFakeAdapterThrowsWhenUnavailable() {
        let adapter = FakeVirtualDisplayAdapter()
        adapter.isAvailable = false
        XCTAssertThrowsError(try adapter.connect(presets: [])) { error in
            XCTAssertEqual(error as? VirtualDisplayError, .unavailable)
        }
    }

    func testRealAdapterDoesNotCreateADisplayOnInspection() {
        let adapter = VirtualDisplayAdapter()
        XCTAssertFalse(adapter.isConnected)
        XCTAssertNil(adapter.displayID)
        _ = adapter.isAvailable
    }
}
