import Foundation

struct NudgeRecord: Codable, Equatable {
    let date: String     // yyyy-MM-dd
    let minutes: Int     // last threshold nudged for this app
    let firedAt: Date
}

// Decides whether a threshold event earns a nudge. DeviceActivity can deliver
// stale thresholds in bursts (e.g. after an extension restart) — the minutes
// comparison and wall-clock gap keep that from double-firing.
enum NudgeGate {
    // Every 15 minutes of usage in a single app. Every ThresholdPlan is
    // required to land on multiples of this (ThresholdPlan.coversNudgeSteps) —
    // a plan that skips 45m silently swallows the 45m nudge, because the gate
    // only ever sees thresholds that were actually registered.
    static let stepMinutes = 15
    static let minGap: TimeInterval = 600

    static func shouldNudge(
        minutes: Int,
        last: NudgeRecord?,
        today: String = DailyUsage.todayString(),
        now: Date = Date()
    ) -> Bool {
        guard minutes > 0, minutes % stepMinutes == 0 else { return false }
        guard let last, last.date == today else { return true }
        guard minutes > last.minutes else { return false }
        return now.timeIntervalSince(last.firedAt) >= minGap
    }
}

enum NudgeCopy {
    struct Line: Equatable {
        let id: Int
        let text: String
    }

    // FamilyControls never reliably exposes the real app name to app code (it's
    // a deliberate privacy boundary — device data confirms it: display names
    // come back as literally "App 1"). Titles stay name-free rather than show a
    // broken placeholder. The title carries the number — "45m", "2h 15m" — so
    // every body line below must read correctly at any duration.
    static func title(minutes: Int) -> String {
        AppGroupKeys.formattedDuration(minutes * 60)
    }

    // The tone escalates with the hour. "still worth it?" lands at 15 minutes
    // and is limp at four hours; "this is your evening now" lands at four hours
    // and is melodramatic at 15. A single flat bank can't do both, which is why
    // the old six lines went stale — the user read all of them by lunch.
    enum Tier {
        case opening    // under 1h — flat, factual, easy to walk away from
        case settling   // 1h–2h — this is no longer a quick check
        case deep       // 2h+ — name what it costs

        init(minutes: Int) {
            switch minutes {
            case ..<60:  self = .opening
            case ..<120: self = .settling
            default:     self = .deep
            }
        }

        var lines: [Line] {
            switch self {
            case .opening:  return NudgeCopy.opening
            case .settling: return NudgeCopy.settling
            case .deep:     return NudgeCopy.deep
            }
        }
    }

    // Flat facts, sharpened. Lowercase, no exclamation points — the mirror
    // doesn't shout and it doesn't advise (no "put it down", no "back to it"),
    // it just refuses to look away and says the quiet part. IDs are stable and
    // unique across tiers: they're what the day's used-line set stores.
    static let opening: [Line] = [
        Line(id: 0,  text: "you opened it for a reason. this wasn't it."),
        Line(id: 1,  text: "you're not even enjoying this."),
        Line(id: 2,  text: "still worth it?"),
        Line(id: 3,  text: "the count doesn't stop for this."),
        Line(id: 4,  text: "nothing new since you last checked."),
        Line(id: 5,  text: "this is the part you won't remember tomorrow."),
        Line(id: 6,  text: "you're killing time. it doesn't come back."),
        Line(id: 7,  text: "just so it's on the record."),
    ]

    static let settling: [Line] = [
        Line(id: 10, text: "the number only goes up from here."),
        Line(id: 11, text: "this stopped being a break."),
        Line(id: 12, text: "you said one more minute a while ago."),
        Line(id: 13, text: "you could have finished something by now."),
        Line(id: 14, text: "you've already seen this feed."),
        Line(id: 15, text: "no one is doing this to you."),
        Line(id: 16, text: "an hour of your life, handed to a feed."),
    ]

    static let deep: [Line] = [
        Line(id: 20, text: "this is what the day went to."),
        Line(id: 21, text: "you're not choosing this anymore. you're just not leaving."),
        Line(id: 22, text: "you don't get this back."),
        Line(id: 23, text: "you already know how this feels tomorrow."),
        Line(id: 24, text: "you'd be furious if someone took this much from you."),
        Line(id: 25, text: "hours. you spent hours here."),
        Line(id: 26, text: "you'll wonder where the day went. it went here."),
    ]

    // Appended below a nudge's line when the Live Activity has died and only a
    // foreground open can revive it (IslandStatus). Stated as fact — true
    // whether the island died at the 8h cap or was never lit today — and never
    // as an instruction: the notification's tap already does the reviving.
    static let meterDarkLine = "the meter is dark. the count isn't."

    // THE PERSONAL LINES — the sharpest copy in the bank, and the app didn't
    // write a word of it. During onboarding the user finishes the sentence
    // "i keep meaning to: …"; mid-scroll, a nudge quotes it back: "you said:
    // play the ukulele." No advice is given — the mirror only repeats what
    // the user themselves wrote, at the moment it costs the most. The colon
    // construction is deliberate: it quotes ANY phrase without conjugating it.
    //
    // IDs start at 100 and are POSITIONAL, so the no-repeat set survives
    // rewording ("play ukulele" → "play the ukulele" keeps id 100). Editing
    // an intention mid-day at worst re-arms one line — acceptable.
    static let personalLineBase = 100

    // Tier-aware: a light hour gets a quiet reminder of their own words; two
    // hours in, the same words come back as an accusation — the aspiration set
    // against the thing they're actually doing. The colon quotes any phrase
    // verbatim (no conjugation), so both templates read correctly whether the
    // user wrote "play the ukulele", "read more", or "learn something new". IDs
    // stay positional so a phrase is never nudged twice in a day across tiers.
    static func personalLines(_ intentions: [String], deep: Bool = false) -> [Line] {
        intentions.prefix(3).enumerated().map { index, phrase in
            let text = deep
                ? "you said: \(phrase). you're doing this instead."
                : "you said: \(phrase)."
            return Line(id: personalLineBase + index, text: text)
        }
    }

    /// What the intentions editor stores: trimmed, lowercased (the mirror's
    /// register), no trailing period (the template adds its own). nil when
    /// nothing survives.
    static func canonicalIntention(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while text.hasSuffix(".") { text.removeLast() }
        return text.isEmpty ? nil : text
    }

    // Never sends the same line twice in a day while an unused one exists —
    // a nudge that repeats stops being read, and one that stops being read
    // stops working. `used` is the day's set from UsageStore, cleared at
    // midnight with everything else. Personal lines join every tier's pool:
    // "you said: …" lands at any hour, and with ≤3 of them against a tier's
    // six the rotation stays mostly fresh copy.
    static func next(
        minutes: Int,
        used: Set<Int>,
        intentions: [String] = [],
        pick: ([Line]) -> Line? = { $0.randomElement() }
    ) -> Line {
        let pool = Tier(minutes: minutes).lines + personalLines(intentions, deep: Tier(minutes: minutes) == .deep)
        let unused = pool.filter { !used.contains($0.id) }
        // Pool exhausted: reuse it rather than fall silent or reach for a line
        // written for a different hour of the day.
        return pick(unused.isEmpty ? pool : unused) ?? pool[0]
    }
}
