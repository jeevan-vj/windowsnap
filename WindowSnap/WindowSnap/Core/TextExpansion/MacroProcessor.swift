import Foundation

/// Expands macro tokens such as `{date}`, `{date:+3d}`, `{clipboard}`, and `{uuid}`.
enum MacroProcessor {
    private static let tokenPattern = #"\{([^{}]+)\}"#

    static func expand(
        _ text: String,
        now: Date,
        clipboard: String?,
        uuid: () -> String = { UUID().uuidString }
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        var result = text
        for match in matches.reversed() {
            let tokenRange = match.range(at: 0)
            let bodyRange = match.range(at: 1)
            let body = nsText.substring(with: bodyRange)
            let replacement = resolveToken(body: body, now: now, clipboard: clipboard, uuid: uuid)
            if let range = Range(tokenRange, in: result) {
                result.replaceSubrange(range, with: replacement)
            }
        }

        return result
    }

    private static func resolveToken(
        body: String,
        now: Date,
        clipboard: String?,
        uuid: () -> String
    ) -> String {
        switch body {
        case "date":
            return mediumDateFormatter.string(from: now)
        case "time":
            return shortTimeFormatter.string(from: now)
        case "isodate":
            return iso8601Formatter.string(from: now)
        case "clipboard":
            return clipboard ?? ""
        case "uuid":
            return uuid()
        default:
            break
        }

        if body.hasPrefix("date:") {
            let spec = String(body.dropFirst("date:".count))
            return expandDateToken(spec: spec, now: now)
        }

        return "{\(body)}"
    }

    private static func expandDateToken(spec: String, now: Date) -> String {
        let parts = spec.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard !parts.isEmpty else { return "{date:}" }

        var date = now
        var format: String?

        if parts.count == 1 {
            if let offset = parseOffset(parts[0]) {
                date = Calendar.current.date(byAdding: offset.component, value: offset.value, to: now) ?? now
            } else {
                format = parts[0]
            }
        } else if parts.count >= 2 {
            if let offset = parseOffset(parts[0]) {
                date = Calendar.current.date(byAdding: offset.component, value: offset.value, to: now) ?? now
                format = parts[1]
            } else {
                format = parts[0]
            }
        }

        if let format, !format.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return formatter.string(from: date)
        }

        return mediumDateFormatter.string(from: date)
    }

    private static func parseOffset(_ value: String) -> (component: Calendar.Component, value: Int)? {
        guard value.count >= 2 else { return nil }
        let numberPart = String(value.dropLast())
        guard let amount = Int(numberPart) else { return nil }
        let unit = value.last!

        let component: Calendar.Component
        switch unit {
        case "d": component = .day
        case "w": component = .weekOfYear
        case "m": component = .month
        case "y": component = .year
        default: return nil
        }

        return (component, amount)
    }

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()
}
