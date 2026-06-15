import Foundation

enum SnippetFieldKind: Equatable {
    case singleLine
    case multiLine
    case popup(options: [String])
}

struct SnippetField: Equatable {
    let name: String
    let kind: SnippetFieldKind
    let defaultValue: String
}

enum ParsedSnippetSegment: Equatable {
    case literal(String)
    case field(name: String)
}

struct ParsedSnippet: Equatable {
    let segments: [ParsedSnippetSegment]
    let fields: [SnippetField]

    var hasFields: Bool {
        !fields.isEmpty
    }
}

enum SnippetParser {
    private static let tokenPattern = #"\{(field|area|popup):([^:}]+)(?::([^}]*))?\}"#

    static func parse(_ text: String) -> ParsedSnippet {
        guard let regex = try? NSRegularExpression(pattern: tokenPattern) else {
            return ParsedSnippet(segments: [.literal(text)], fields: [])
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else {
            return ParsedSnippet(segments: [.literal(text)], fields: [])
        }

        var segments: [ParsedSnippetSegment] = []
        var fields: [SnippetField] = []
        var fieldIndex: [String: Int] = [:]
        var cursor = 0

        for match in matches {
            let fullRange = match.range(at: 0)
            if fullRange.location > cursor {
                let literalRange = NSRange(location: cursor, length: fullRange.location - cursor)
                segments.append(.literal(nsText.substring(with: literalRange)))
            }

            let kindToken = nsText.substring(with: match.range(at: 1))
            let name = nsText.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            let valuePart = match.range(at: 3).location != NSNotFound
                ? nsText.substring(with: match.range(at: 3))
                : ""

            guard !name.isEmpty else {
                segments.append(.literal(nsText.substring(with: fullRange)))
                cursor = fullRange.location + fullRange.length
                continue
            }

            let fieldKind: SnippetFieldKind
            let defaultValue: String

            switch kindToken {
            case "field":
                fieldKind = .singleLine
                defaultValue = valuePart
            case "area":
                fieldKind = .multiLine
                defaultValue = valuePart
            case "popup":
                let options = valuePart.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                fieldKind = .popup(options: options)
                defaultValue = options.first ?? ""
            default:
                segments.append(.literal(nsText.substring(with: fullRange)))
                cursor = fullRange.location + fullRange.length
                continue
            }

            if fieldIndex[name] == nil {
                fields.append(SnippetField(name: name, kind: fieldKind, defaultValue: defaultValue))
                fieldIndex[name] = fields.count - 1
            }

            segments.append(.field(name: name))
            cursor = fullRange.location + fullRange.length
        }

        if cursor < nsText.length {
            segments.append(.literal(nsText.substring(from: cursor)))
        }

        if segments.isEmpty {
            segments = [.literal(text)]
        }

        return ParsedSnippet(segments: segments, fields: fields)
    }
}

enum SnippetRenderer {
    static func render(_ parsed: ParsedSnippet, values: [String: String]) -> String {
        parsed.segments.map { segment in
            switch segment {
            case .literal(let text):
                return text
            case .field(let name):
                if let value = values[name], !value.isEmpty {
                    return value
                }
                if let field = parsed.fields.first(where: { $0.name == name }) {
                    return field.defaultValue
                }
                return ""
            }
        }.joined()
    }
}

struct SnippetFormRow: Equatable {
    let name: String
    let kind: SnippetFieldKind
    let defaultValue: String
}

enum SnippetFormBuilder {
    static func formRows(for parsed: ParsedSnippet) -> [SnippetFormRow] {
        parsed.fields.map { field in
            SnippetFormRow(name: field.name, kind: field.kind, defaultValue: field.defaultValue)
        }
    }
}

enum SnippetExpansionPipeline {
    static func expand(
        _ text: String,
        values: [String: String] = [:],
        now: Date,
        clipboard: String?,
        uuid: () -> String = { UUID().uuidString }
    ) -> (text: String, leftArrowCount: Int?) {
        let parsed = SnippetParser.parse(text)
        let rendered = SnippetRenderer.render(parsed, values: values)
        let expanded = MacroProcessor.expand(rendered, now: now, clipboard: clipboard, uuid: uuid)
        return CursorResolver.resolve(expanded)
    }
}
