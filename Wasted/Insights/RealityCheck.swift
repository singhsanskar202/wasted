import Foundation

// The conversion moment: confronts the user's own onboarding guess with
// their first tracked day. This is what turns "another screen time app"
// into "oh — I actually don't know how bad it is."
struct RealityCheck: Equatable, Identifiable {
    // Presented once, ever, via fullScreenCover(item:) — the identity is the
    // content, since a second distinct reality check never exists.
    var id: String { realityLine }

    let guessLine: String
    let realityLine: String
    let deltaLine: String
    // Whether reality came in WORSE than the guess. The delta line used to be
    // painted alarm red unconditionally — so a user who guessed accurately was
    // congratulated ("you actually knew.") in the colour the whole app reserves
    // for "this number is bad". The colour and the words were arguing. Red is
    // now earned only by an underestimate, which is the only bad news here.
    let underestimated: Bool

    static func make(guessSeconds: Int, firstFullDaySeconds: Int) -> RealityCheck? {
        guard guessSeconds > 0, firstFullDaySeconds > 0 else { return nil }

        let guessLine = "you guessed \(formatted(guessSeconds))."
        let realityLine = "reality: \(formatted(firstFullDaySeconds))."

        let underestimated = firstFullDaySeconds > guessSeconds
        let deltaLine: String
        if underestimated {
            let pct = Int(round((Double(firstFullDaySeconds) / Double(guessSeconds) - 1) * 100))
            deltaLine = "off by \(pct)%."
        } else {
            deltaLine = "you actually knew."
        }

        return RealityCheck(
            guessLine: guessLine,
            realityLine: realityLine,
            deltaLine: deltaLine,
            underestimated: underestimated
        )
    }

    // Unlike AppGroupKeys.formattedDuration (which always shows "1h 0m" to
    // match the Dynamic Island convention), the reality check reads a whole
    // hour as bare "2h" — it echoes the onboarding guess chip's own wording.
    private static func formatted(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }
}
