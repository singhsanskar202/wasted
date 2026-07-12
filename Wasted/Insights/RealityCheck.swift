import Foundation

// The conversion moment: confronts the user's own onboarding guess with their
// first tracked day. This is what turns "another screen time app" into "oh — I
// actually don't know how bad it is."
//
// IT MUST NEVER CONGRATULATE. The old delta line said "you actually knew."
// whenever reality came in at or below the guess — so the single most important
// moment in the funnel stood up, roughly half the time, and told the user their
// instinct was fine and they didn't need a mirror. The app's whole thesis is
// "your sense of it is wrong; only the number is true", and its centrepiece was
// arguing the opposite.
//
// The fix isn't to hide the accurate guess — it's to notice that an accurate
// guess is WORSE, not better. You knew exactly what it was costing you, and you
// spent it anyway. That lands harder than the underestimate ever did.
struct RealityCheck: Equatable, Identifiable {
    // Presented once, ever, via fullScreenCover(item:) — the identity is the
    // content, since a second distinct reality check never exists.
    var id: String { realityLine }

    enum Verdict: Equatable {
        case underestimated(percent: Int)  // reality came in worse than the guess
        case knew                          // the guess was close
        case sawItComing                   // the guess was higher than reality
    }

    let guessLine: String
    let realityLine: String
    let verdict: Verdict

    // Within this band of the guess, the user essentially called it.
    private static let accurateBand = 0.15

    var deltaLine: String {
        switch verdict {
        case .underestimated(let percent):
            return "off by \(percent)%."
        case .knew:
            return "you knew. and you did it anyway."
        case .sawItComing:
            return "you saw it coming. you did it anyway."
        }
    }

    // The closer has to follow the verdict too. It used to read "your sense of
    // it was wrong. the number is the only thing that isn't." — which is simply
    // FALSE for a user who called it correctly, and the screen would say it to
    // their face. When someone guessed right, the mirror's point isn't that they
    // were wrong; it's that being right didn't save them.
    var closingLine: String {
        switch verdict {
        case .underestimated:
            return "your sense of it was wrong.\nthe number is the only thing that isn't."
        case .knew, .sawItComing:
            return "knowing was never the problem.\nthe number just won't let you forget."
        }
    }

    // Red is for bad news, and it's only bad news when the number beat your
    // instinct. The other two verdicts are the harsher lines, but they aren't a
    // bad *number* — painting them alarm red is what made the old screen
    // congratulate you in the colour reserved for failure.
    var isAlarming: Bool {
        if case .underestimated = verdict { return true }
        return false
    }

    static func make(guessSeconds: Int, firstFullDaySeconds: Int) -> RealityCheck? {
        guard guessSeconds > 0, firstFullDaySeconds > 0 else { return nil }

        let ratio = Double(firstFullDaySeconds) / Double(guessSeconds)
        let verdict: Verdict
        if ratio > 1 + accurateBand {
            verdict = .underestimated(percent: Int(round((ratio - 1) * 100)))
        } else if ratio >= 1 - accurateBand {
            verdict = .knew
        } else {
            verdict = .sawItComing
        }

        // AppGroupKeys.formattedDuration used to render a whole hour as "1h 0m",
        // so this type carried its own copy of the formatter just to say "2h" —
        // the way the onboarding guess chips word it. The shared formatter now
        // drops the zero minutes, so the duplicate is gone and every surface in
        // the app speaks one format.
        return RealityCheck(
            guessLine: "you guessed \(AppGroupKeys.formattedDuration(guessSeconds)).",
            realityLine: "reality: \(AppGroupKeys.formattedDuration(firstFullDaySeconds)).",
            verdict: verdict
        )
    }
}
