import Foundation
import UserNotifications

// YESTERDAY'S BILL, delivered while you can still do something about today.
//
// The 9pm receipt reports a day that is already lost. This lands in the morning
// with the FINAL number and a whole day still in front of you — which makes it
// the better of the two moments, not a second copy of it.
//
// THE LINE THAT SEPARATES THIS FROM A GROWTH HACK: the notification CARRIES the
// number. It never says "tap to see your report". The moment a notification's
// real job is to get the app opened — to revive a Live Activity, say — it stops
// being a mirror and becomes exactly the attention-farming this product exists to
// argue against. This one is complete on the Lock Screen. If someone opens the app
// out of discomfort, the island comes back, and that is a side effect we do not
// advertise and did not build this for.
struct MorningReport {
    static let identifier = "wasted.morning"
    static let hour = 8

    /// Re-scheduled on every threshold and every foreground, exactly like the
    /// receipt: a local notification carries STATIC content, so the only way its
    /// number can be right is to keep replacing it with a fresher one.
    ///
    /// The subtlety that makes this correct: the notification always reports
    /// *yesterday from the reader's point of view*. Before 8am it fires TODAY and
    /// must carry the archived previous day; after 8am the next firing is TOMORROW,
    /// so it must carry the day that's running now. Getting that backwards would
    /// clobber this morning's pending notification with a number that hasn't
    /// happened yet — and the report would silently never arrive.
    func refresh(store: UsageStore, now: Date = Date()) {
        let calendar = Calendar.current
        let firesToday = calendar.component(.hour, from: now) < Self.hour

        let seconds: Int = firesToday
            ? (store.loadYesterday()?.seconds.values.reduce(0, +) ?? 0)
            : store.totalSecondsAllApps()

        // Nothing to report is not a report. A "0m yesterday" notification is a
        // buzz that says nothing, and this app does not buzz for nothing.
        guard seconds >= 60 else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
            EventLog.log(.receipt, "morning report skipped — nothing to report")
            return
        }

        guard let fireDate = Self.nextFireDate(after: now, calendar: calendar) else { return }

        let content = UNMutableNotificationContent()
        content.title = "yesterday"
        content.body = Self.body(seconds: seconds)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour], from: fireDate),
            repeats: false
        )
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        )
        EventLog.log(.receipt, "morning report set for \(Self.hour):00 — \"\(content.body)\"")
    }

    /// The number, and what it cost. Never a call to action.
    static func body(seconds: Int) -> String {
        let total = AppGroupKeys.formattedDuration(seconds)
        guard let equivalent = EquivalentTaskMapper.equivalent(for: seconds) else {
            return "you wasted \(total)."
        }
        // The equivalent already reads as a sentence — "that's a football match." /
        // "61 days a year, at this pace. you don't get them back."
        return "\(total). \(equivalent.line.replacingOccurrences(of: "\n", with: " "))"
    }

    static func nextFireDate(after now: Date, calendar: Calendar = .current) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = 0
        guard let today = calendar.date(from: components) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }
}
