import Foundation

/// Resolves `{cursor}` tokens in snippet replacement text.
enum CursorResolver {
    private static let cursorToken = "{cursor}"

    static func resolve(_ text: String) -> (text: String, leftArrowCount: Int?) {
        guard let range = text.range(of: cursorToken) else {
            return (text, nil)
        }

        let before = String(text[..<range.lowerBound])
        let after = String(text[range.upperBound...])
        let remainingAfterFirst = after.replacingOccurrences(of: cursorToken, with: "")
        let resolvedText = before + remainingAfterFirst
        let leftArrowCount = remainingAfterFirst.count

        return (resolvedText, leftArrowCount)
    }
}
