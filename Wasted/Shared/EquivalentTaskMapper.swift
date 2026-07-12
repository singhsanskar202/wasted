import Foundation

// What the time was worth — and, past a point, what it costs you.
//
// THE TEST EVERY LINE HERE HAS TO PASS: does a stranger, anywhere in the world,
// already know roughly how long this takes? A football match is ninety minutes
// in every country on earth. A 5K run is about half an hour to anyone who has
// ever laced up. A full-body workout is about forty-five minutes.
//
// Things that FAILED that test and were removed:
//   · "your commute, both ways" — assumes you commute, and assumes how long.
//     Twenty minutes for one person, ninety for another. Useless.
//   · "a coffee with someone" — fifteen minutes or two hours. Not a duration.
//   · "a flight to another city" — an hour, or eleven.
//   · "69 pages of a book" / "a 13 km run" — a SCALED COUNT. Nobody pictures 69
//     pages. And the old table's fixed-threshold lookup snapped DOWN, so 1h 23m
//     displayed the 1h row and silently discarded 23 minutes.
//
// Past the point where no single thing can hold the number, comparison stops
// being credible ("2.5 films" means nothing) — so it stops comparing and starts
// COMPOUNDING: what this pace costs across a year. That's the part you cannot
// get back, it needs no counterfactual, and it's the move the app's own Hook
// already makes ("that's 60 days a year. gone.").
struct EquivalentTaskMapper {
    struct Equivalent {
        let emoji: String       // empty for the reckoning — it isn't a "thing"
        let line: String        // a complete sentence, not a fragment

        var fullText: String {
            emoji.isEmpty ? line : "\(emoji) \(line)"
        }
    }

    // Past 2h30, no single familiar thing is long enough to hold the number.
    private static let beyondComparison = 150  // minutes

    static func equivalent(for totalSeconds: Int) -> Equivalent? {
        let minutes = max(0, totalSeconds) / 60
        // Under ten minutes there's no honest comparison to make, and inventing
        // one would cheapen every line that follows.
        guard minutes >= 10 else { return nil }

        if minutes >= beyondComparison {
            return Equivalent(emoji: "", line: reckoning(minutes))
        }

        // Buckets are tight, so the thing named is genuinely about as long as the
        // time shown next to it. The old table's buckets were an hour wide, which
        // is how 83 minutes ended up described as a 60-minute activity.
        switch minutes {
        case ..<18:  return Equivalent(emoji: "🧘", line: "that's a 15-minute meditation.")
        case ..<28:  return Equivalent(emoji: "📺", line: "that's an episode of a sitcom.")
        case ..<38:  return Equivalent(emoji: "🏃", line: "that's a 5K run.")
        case ..<53:  return Equivalent(emoji: "🏋️", line: "that's a full-body workout.")
        case ..<71:  return Equivalent(emoji: "📺", line: "that's an episode of a drama.")
        case ..<101: return Equivalent(emoji: "⚽️", line: "that's a football match.")
        default:     return Equivalent(emoji: "🎬", line: "that's a feature film.")
        }
    }

    // Not "you could have" — "here is the bill." One day's pace, extended across
    // a year, in days. Nothing to argue with, and the only cost that is truly
    // unrecoverable.
    //
    // 4h/day lands on 61 days, which is the number the Hook opens the entire app
    // with — so the first line a user ever reads and the line they see every day
    // finally say the same thing.
    private static func reckoning(_ minutes: Int) -> String {
        let daysPerYear = Int((Double(minutes) * 365 / (24 * 60)).rounded())
        return "\(daysPerYear) days a year, at this pace.\nyou don't get them back."
    }
}
