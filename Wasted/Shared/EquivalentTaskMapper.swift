import Foundation

// What the wasted time was worth, in something you can picture.
//
// The old version was a table of thresholds with FIXED text, and it picked the
// largest threshold at or below the total — so 1h 23m displayed the 1h row,
// "a book chapter (25 pages)", which was wrong twice: it silently discarded the
// extra 23 minutes, and 25 pages an hour is about half of what an average adult
// actually reads. Every value between two thresholds understated the cost, which
// is the one direction this app must never err in.
//
// So the quantities are now RATES, and they scale with the real number. The
// claim is always true for the time actually shown next to it.
struct EquivalentTaskMapper {
    struct Equivalent {
        let description: String
        let emoji: String

        var fullText: String { "\(emoji) \(description)" }
    }

    // ~240 words a minute is the average adult reading speed; a paperback page
    // runs ~280 words. That's a shade under a page a minute — call it 50 pages
    // an hour, and round down, because this number is a floor.
    private static func pages(_ minutes: Int) -> Int {
        max(1, Int(Double(minutes) * 0.83))
    }

    // An easy jog: 6.5 minutes a kilometre. A 5K lands at ~32 minutes, which is
    // where most people actually are.
    private static func kilometres(_ minutes: Int) -> Int {
        max(1, Int((Double(minutes) / 6.5).rounded()))
    }

    static func equivalent(for totalSeconds: Int) -> Equivalent? {
        let minutes = max(0, totalSeconds) / 60
        // Under ten minutes there is no honest comparison to make, and inventing
        // one would cheapen the ones that follow.
        guard minutes >= 10 else { return nil }

        switch minutes {
        case ..<30:
            return Equivalent(description: "a \(minutes)-minute meditation", emoji: "🧘")
        case ..<60:
            return Equivalent(description: "a \(kilometres(minutes)) km run", emoji: "🏃")
        case ..<180:
            return Equivalent(description: "\(pages(minutes)) pages of a book", emoji: "📖")
        case ..<360:
            return Equivalent(description: "\(pages(minutes)) pages — half a novel", emoji: "📖")
        default:
            return Equivalent(description: "\(pages(minutes)) pages — a whole novel", emoji: "📖")
        }
    }
}
