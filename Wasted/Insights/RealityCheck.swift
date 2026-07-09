import Foundation

// The conversion moment: confronts the user's own onboarding guess with
// their first tracked day. This is what turns "another screen time app"
// into "oh — I actually don't know how bad it is."
struct RealityCheck: Equatable {
    let guessLine: String
    let realityLine: String
    let deltaLine: String

    static func make(guessSeconds: Int, firstFullDaySeconds: Int) -> RealityCheck? {
        guard guessSeconds > 0, firstFullDaySeconds > 0 else { return nil }

        let guessLine = "you guessed \(formatted(guessSeconds))."
        let realityLine = "reality: \(formatted(firstFullDaySeconds))."

        let deltaLine: String
        if firstFullDaySeconds <= guessSeconds {
            deltaLine = "you actually knew."
        } else {
            let pct = Int(round((Double(firstFullDaySeconds) / Double(guessSeconds) - 1) * 100))
            deltaLine = "off by \(pct)%."
        }

        return RealityCheck(guessLine: guessLine, realityLine: realityLine, deltaLine: deltaLine)
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
