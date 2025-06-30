import SwiftUI

struct HabitsViewHelpers {

    // MARK: - Helper functions for emojis
    static func motivationEmoji(_ level: String?) -> String {
        switch level?.lowercased() {
        case "high": return "🟢"
        case "medium": return "🟡"
        case "low": return "🔴"
        default: return "⚪"
        }
    }

    static func abilityEmoji(_ level: String?) -> String {
        switch level?.lowercased() {
        case "easy": return "🟢"
        case "medium": return "🟡"
        case "hard": return "🔴"
        default: return "⚪"
        }
    }
}