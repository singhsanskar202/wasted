import Foundation

// The mirror's voice. It gets meaner as the number climbs.
//
// This used to be thirty sentence-case lines picked at random by calendar day —
// a fortune cookie that knew nothing about the person reading it. Which is the
// weakest possible provocation: the same line greets a clean morning and a
// six-hour binge.
//
// Now the temper is chosen by TODAY'S ACTUAL NUMBER, so the tone escalates while
// you scroll. Open the app at 20 minutes and it's patient. Open it at four hours
// and it isn't.
//
// Three things every line here had to lose, all of which the old bank was full
// of and all of which the product guide bans in writing:
//   · ADVICE. "close this. go do the hard thing." / "put the phone down." — the
//     app "never blocks, never shames, never offers a solution — it just keeps
//     count." A mirror doesn't tell you what to do.
//   · HUSTLE CLICHÉS. "every hour you scroll, someone else is building
//     something." / "the most successful people guard their attention like
//     money." That's a LinkedIn post, and it's the easiest line in the world to
//     dismiss.
//   · CONGRATULATION. "awareness is the first step. you're reading this. good."
//     The mirror never says good.
enum QuoteBank {

    enum Temper: Equatable, CaseIterable {
        case waiting    // under 30m — nothing has happened yet, and it knows
        case pointed    // 30m–2h — this stopped being a check
        case cruel      // 2h–4h — the day is being spent
        case brutal     // 4h+ — this is not an accident anymore

        init(seconds: Int) {
            switch seconds {
            case ..<1800:  self = .waiting
            case ..<7200:  self = .pointed
            case ..<14400: self = .cruel
            default:       self = .brutal
            }
        }
    }

    // Patient, and slightly ominous. The mirror is not impressed yet — it's just
    // watching.
    static let waiting: [String] = [
        "the day is young. so is the number.",
        "this is how it starts.",
        "you'll be back.",
        "you opened this to feel better about it.",
        "nothing yet. give it an hour.",
        "you already know how today ends.",
    ]

    // It has stopped being a quick check, and the mirror has noticed.
    static let pointed: [String] = [
        "five minutes became an hour again.",
        "you unlocked your phone looking for something. did you find it?",
        "you're not relaxing. you're numbing.",
        "the feed refreshes. your life doesn't.",
        "you already know you've been on too long.",
        "you will not remember a single thing you saw today.",
    ]

    // The day is being spent, and it is not coming back.
    static let cruel: [String] = [
        "that time is gone. permanently.",
        "the scroll has no end. you do.",
        "you had plans today.",
        "you are not going to look back on this fondly.",
        "this is the part of your life you're spending right now.",
        "somewhere there's a version of you that didn't do this. they're having a better day.",
    ]

    // No more benefit of the doubt.
    static let brutal: [String] = [
        "this wasn't a lapse. this is the habit.",
        "you would not accept this from anyone else.",
        "you're not going to fix this tomorrow either.",
        "a whole day to spend, and this is what you chose.",
        "you are watching your life happen to someone else.",
        "is this how you want to spend your one life?",
    ]

    static func lines(for temper: Temper) -> [String] {
        switch temper {
        case .waiting: return waiting
        case .pointed: return pointed
        case .cruel:   return cruel
        case .brutal:  return brutal
        }
    }

    /// The line for a given day's total. Stable within a day AND within a temper —
    /// HomeView refreshes every five seconds, and a quote that reshuffled on each
    /// tick would be noise, not a voice. It changes when the DAY changes, or when
    /// you make it worse.
    static func quote(forSeconds seconds: Int, on date: Date = Date()) -> String {
        let bank = lines(for: Temper(seconds: seconds))
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return bank[day % bank.count]
    }
}
