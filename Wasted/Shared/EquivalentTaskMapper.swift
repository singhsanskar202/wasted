import Foundation

// What the time was worth — and, past a point, what it costs you.
//
// TWO THINGS WERE WRONG BEFORE THIS.
//
// 1. It suggested hobbies. "you could have read 69 pages" / "a 13 km run" /
//    "a 15-minute meditation" is the app OFFERING A SOLUTION, which the product
//    guide explicitly rules out ("never blocks, never shames, never offers a
//    solution — it just keeps count"). It's also a lie the reader can feel: you
//    were never going to run 13 km, so the guilt bounces straight off.
//
// 2. A SCALED COUNT IS NEVER RELATABLE. Nobody can picture 69 pages. Everybody
//    can picture ONE WHOLE THING — an episode, a match, a film. So a comparison
//    is only ever a single plausible thing, never a quantity.
//
// And when the number grows past what any single thing can hold, the comparison
// stops being credible at all — "2.5 films" means nothing. That's the moment to
// stop comparing and start COMPOUNDING: what this pace costs across a year. No
// counterfactual, no assumption about who you are, nothing to argue with. It's
// also the exact move the app's own Hook already makes — "that's 60 days a year.
// gone." — so the first thing a user ever reads and the line they see every day
// finally say the same thing.
struct EquivalentTaskMapper {
    struct Equivalent {
        let emoji: String       // empty for the reckoning — it isn't a "thing"
        let line: String        // a complete sentence, not a fragment

        var fullText: String {
            emoji.isEmpty ? line : "\(emoji) \(line)"
        }
    }

    // Past this, no single thing is a credible comparison, so we stop making
    // one. Four hours is also where the Hook's own number lives.
    private static let beyondComparison = 240  // minutes

    static func equivalent(for totalSeconds: Int) -> Equivalent? {
        let minutes = max(0, totalSeconds) / 60
        // Under ten minutes there's no honest comparison to make, and inventing
        // one would cheapen every line that follows.
        guard minutes >= 10 else { return nil }

        if minutes >= beyondComparison {
            return Equivalent(emoji: "", line: reckoning(minutes))
        }

        // Each of these is ONE thing, and roughly this long in real life — so the
        // claim is true, and the reader can see it without doing any arithmetic.
        switch minutes {
        case ..<25:  return Equivalent(emoji: "☕️", line: "that's a coffee with someone.")
        case ..<45:  return Equivalent(emoji: "📺", line: "that's an episode.")
        case ..<75:  return Equivalent(emoji: "🚇", line: "that's your commute. both ways.")
        case ..<105: return Equivalent(emoji: "⚽️", line: "that's a football match.")
        case ..<165: return Equivalent(emoji: "🎬", line: "that's a film.")
        default:     return Equivalent(emoji: "✈️", line: "that's a flight to another city.")
        }
    }

    // Not "you could have" — "here is the bill." A day's pace, extended across a
    // year, in days. Unarguable, and the one cost that is genuinely unrecoverable.
    private static func reckoning(_ minutes: Int) -> String {
        let daysPerYear = Int((Double(minutes) * 365 / (24 * 60)).rounded())
        return "\(daysPerYear) days a year, at this pace.\nyou don't get them back."
    }
}
