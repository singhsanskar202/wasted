import Foundation

struct EquivalentTaskMapper {
    struct Equivalent {
        let threshold: Int  // seconds
        let description: String
        let emoji: String

        var fullText: String { "\(emoji) \(description)" }
    }

    private static let table: [Equivalent] = [
        .init(threshold: 900,   description: "a 15-min meditation",        emoji: "🧘"),
        .init(threshold: 1800,  description: "a 5K run",                   emoji: "🏃"),
        .init(threshold: 3600,  description: "a book chapter (25 pages)",  emoji: "📖"),
        .init(threshold: 5400,  description: "cooking a full meal",        emoji: "🍳"),
        .init(threshold: 7200,  description: "a full workout",             emoji: "💪"),
        .init(threshold: 10800, description: "watching a short film",      emoji: "🎬"),
        .init(threshold: 14400, description: "learning a song on guitar",  emoji: "🎸"),
        .init(threshold: 21600, description: "a half-day hike",            emoji: "🥾"),
    ]

    static func equivalent(for totalSeconds: Int) -> Equivalent? {
        table.last { $0.threshold <= totalSeconds }
    }
}
