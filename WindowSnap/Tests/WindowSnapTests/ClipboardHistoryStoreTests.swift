import Foundation
@testable import WindowSnap
import XCTest

final class ClipboardHistoryStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        suiteName = "ClipboardHistoryStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try super.tearDownWithError()
    }

    func testPersistentHistoryUsesWindowSnapApplicationSupportDirectoryAndOwnerOnlyPermissions() throws {
        let store = makeStore()

        try store.save([makeItem(content: "local-only")])

        XCTAssertEqual(store.historyURL.deletingLastPathComponent().lastPathComponent, "WindowSnap")
        XCTAssertEqual(store.historyURL.lastPathComponent, "clipboard-history.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.historyURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: store.historyURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let backupAttributes = try FileManager.default.attributesOfItem(atPath: store.backupURL.path)
        XCTAssertEqual((backupAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertNil(userDefaults.data(forKey: ClipboardHistoryStore.legacyDefaultsKey))
    }

    func testMigratesLegacyDefaultsOnceWithoutDuplicationThenRemovesPayload() throws {
        let legacyItems = [makeItem(content: "legacy")]
        userDefaults.set(try encode(legacyItems), forKey: ClipboardHistoryStore.legacyDefaultsKey)
        let store = makeStore()

        XCTAssertEqual(store.load().map(\.content), ["legacy"])
        XCTAssertNil(userDefaults.data(forKey: ClipboardHistoryStore.legacyDefaultsKey))
        XCTAssertEqual(store.load().map(\.content), ["legacy"])
    }

    func testRecoversLastKnownGoodAtomicBackupWhenPrimaryIsPartial() throws {
        let store = makeStore()
        try store.save([makeItem(content: "first")])
        try store.save([makeItem(content: "second")])
        try Data("{partial".utf8).write(to: store.historyURL)

        let recovered = store.load()

        XCTAssertEqual(recovered.map(\.content), ["second"])
        XCTAssertEqual(makeStore().load().map(\.content), ["second"])
    }

    func testCorruptStorageWithoutBackupFailsClosedAndDoesNotCrash() throws {
        let store = makeStore()
        try FileManager.default.createDirectory(
            at: store.historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: store.historyURL)

        XCTAssertEqual(store.load().count, 0)
    }

    func testPartiallyCorruptArrayPreservesValidItems() throws {
        let store = makeStore()
        let validObject = try XCTUnwrap(
            (try JSONSerialization.jsonObject(with: encode([makeItem(content: "valid")])) as? [Any])?.first
        )
        let payload = try JSONSerialization.data(withJSONObject: [validObject, ["id": "invalid"]])
        try FileManager.default.createDirectory(
            at: store.historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try payload.write(to: store.historyURL)

        XCTAssertEqual(store.load().map(\.content), ["valid"])
    }

    func testClearRemovesPrimaryBackupAndLoadedContent() throws {
        let store = makeStore()
        try store.save([makeItem(content: "first")])
        try store.save([makeItem(content: "second")])

        try store.clear()

        XCTAssertEqual(store.load().count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.historyURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.backupURL.path))
    }

    private func makeStore() -> ClipboardHistoryStore {
        ClipboardHistoryStore(
            applicationSupportDirectory: temporaryDirectory,
            userDefaults: userDefaults
        )
    }

    private func makeItem(content: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            content: content,
            type: .text,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            preview: content,
            isPinned: false
        )
    }

    private func encode(_ items: [ClipboardHistoryItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(items)
    }
}
