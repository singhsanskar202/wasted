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
    static let stepMinutes = 30
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
    // "30m on Instagram", "1h 30m on Instagram"
    static func title(appName: String, minutes: Int) -> String {
        "\(AppGroupKeys.formattedDuration(minutes * 60)) on \(appName)"
    }

    // Flat facts and redirects. No exclamation points, no guilt.
    static let bodies: [String] = [
        "that's enough for now — back to it?",
        "just so you know.",
        "the count doesn't pause. you can.",
        "still worth it?",
        "you opened it for a reason. was this it?",
        "the number only goes up from here.",
    ]

    static func body(at index: Int) -> String {
        bodies[((index % bodies.count) + bodies.count) % bodies.count]
    }
}
