import Foundation

// #region agent log
// Temporary debug instrumentation for region-share lifecycle debugging (session 22fe0f).
// Safe to delete once the bug is verified fixed.
enum RegionShareDebugLog {
    private static let path = "/Users/jeevan.wijerathna/jeevan/projects/windowsnap/.cursor/debug-22fe0f.log"
    private static let queue = DispatchQueue(label: "regionshare.debuglog")

    static func write(
        hypothesis: String,
        message: String,
        data: [String: Any],
        sync: Bool = false,
        fileID: String = #fileID,
        line: Int = #line
    ) {
        let runId = (data["runId"] as? String) ?? "unknown"
        var payloadData = data
        payloadData["runId"] = runId
        var payload: [String: Any] = [
            "sessionId": "22fe0f",
            "hypothesisId": hypothesis,
            "runId": runId,
            "location": "\(fileID):\(line)",
            "message": message,
            "data": payloadData,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        payload["id"] = "log_\(payload["timestamp"]!)_\(Int.random(in: 1000...9999))"

        let work = {
            guard let json = try? JSONSerialization.data(withJSONObject: payload, options: []),
                  var line = String(data: json, encoding: .utf8) else { return }
            line += "\n"
            guard let lineData = line.data(using: .utf8) else { return }

            let url = URL(fileURLWithPath: path)
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(lineData)
                try? handle.close()
            } else {
                try? lineData.write(to: url, options: .atomic)
            }
        }

        if sync {
            queue.sync(execute: work)
        } else {
            queue.async(execute: work)
        }
    }
}
// #endregion
