import Foundation

/// Persists clipboard history locally. Clipboard payloads never leave this store.
final class ClipboardHistoryStore {
    static let legacyDefaultsKey = "ClipboardHistory"

    let historyURL: URL
    let backupURL: URL

    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let legacyDefaultsKey: String

    init(
        applicationSupportDirectory: URL? = nil,
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        legacyDefaultsKey: String = ClipboardHistoryStore.legacyDefaultsKey
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
        self.legacyDefaultsKey = legacyDefaultsKey

        let baseDirectory = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let appDirectory = baseDirectory.appendingPathComponent("WindowSnap", isDirectory: true)
        historyURL = appDirectory.appendingPathComponent("clipboard-history.json")
        backupURL = appDirectory.appendingPathComponent("clipboard-history.backup.json")
    }

    func load() -> [ClipboardHistoryItem] {
        if fileManager.fileExists(atPath: historyURL.path) {
            defer { userDefaults.removeObject(forKey: legacyDefaultsKey) }
            if let items = decodeFile(at: historyURL) {
                return items
            }
            if let recovered = decodeFile(at: backupURL) {
                try? write(recovered, rotateBackup: false)
                return recovered
            }
            return []
        }

        guard let legacyData = userDefaults.data(forKey: legacyDefaultsKey),
              let legacyItems = decode(legacyData) else {
            return []
        }

        do {
            try save(legacyItems)
            userDefaults.removeObject(forKey: legacyDefaultsKey)
            return legacyItems
        } catch {
            // Keep the legacy payload so migration can be retried without data loss.
            return legacyItems
        }
    }

    func save(_ items: [ClipboardHistoryItem]) throws {
        try write(items, rotateBackup: true)
    }

    func clear() throws {
        for url in [historyURL, backupURL] where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        userDefaults.removeObject(forKey: legacyDefaultsKey)
    }

    private func write(_ items: [ClipboardHistoryItem], rotateBackup: Bool) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(items)

        try fileManager.createDirectory(
            at: historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
        )

        if rotateBackup {
            // Keep recovery data in lockstep with the new snapshot. Retaining the
            // previous snapshot would leave deleted or expired clipboard content
            // behind in the backup file.
            try data.write(to: backupURL, options: .atomic)
            try setOwnerOnlyPermissions(at: backupURL)
        }

        try data.write(to: historyURL, options: .atomic)
        try setOwnerOnlyPermissions(at: historyURL)
    }

    private func decodeFile(at url: URL) -> [ClipboardHistoryItem]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data)
    }

    private func decode(_ data: Data) -> [ClipboardHistoryItem]? {
        guard let objects = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedItems: [ClipboardHistoryItem] = objects.compactMap { object in
            guard JSONSerialization.isValidJSONObject(object),
                  let itemData = try? JSONSerialization.data(withJSONObject: object) else {
                return nil
            }
            return try? decoder.decode(ClipboardHistoryItem.self, from: itemData)
        }
        return objects.isEmpty || !decodedItems.isEmpty ? decodedItems : nil
    }

    private func setOwnerOnlyPermissions(at url: URL) throws {
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: url.path
        )
    }
}
