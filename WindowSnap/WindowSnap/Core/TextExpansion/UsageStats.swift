import Foundation

struct UsageStats: Codable, Equatable {
    var expansionCount: Int
    var charactersSaved: Int

    init(expansionCount: Int = 0, charactersSaved: Int = 0) {
        self.expansionCount = expansionCount
        self.charactersSaved = charactersSaved
    }

    func recording(trigger: String, replacement: String) -> UsageStats {
        let saved = max(0, replacement.count - trigger.count)
        return UsageStats(
            expansionCount: expansionCount + 1,
            charactersSaved: charactersSaved + saved
        )
    }

    func timeSavedEstimate(wpm: Int = 40) -> String {
        guard charactersSaved > 0 else { return "0 minutes saved" }
        let wordsSaved = Double(charactersSaved) / 5.0
        let minutes = wordsSaved / Double(wpm)
        if minutes < 1 {
            return "Less than 1 minute saved"
        }
        let rounded = Int(minutes.rounded())
        return "\(rounded) minute\(rounded == 1 ? "" : "s") saved"
    }
}
