import Foundation
import UserNotifications

// THE PROACTIVE MIRROR — the one thing a week of history makes possible that
// no daily counter can do: state the cost BEFORE it's paid.
//
// Every other surface in this app is reactive — the nudge fires after 15
// minutes are gone, the receipt prints after the day is spent, the morning
// report bills yesterday. The habit bell fires at the OPENING of the user's
// own costliest window: "9pm–11pm — 5 of the last 7 days, about 41m a time.
// today isn't written yet." A forecast from their record, delivered at the
// moment of choice. Still zero advice: it never says don't.
//
// PRO. It exists only because of week-scale history — history's whole pitch is
// that it arrives early, not that it's a museum. (Beta: ProGate unlocks all.)
//
// Scheduling: a repeating daily calendar trigger at the window's start hour,
// re-planned on every main-app run (foreground and BG refresh) the same way
// the morning report is — a local notification carries static content, so the
// only way its numbers stay true is constant replacement. If the peak moves
// or dissolves, the old bell is removed.
enum HabitBell {
    static let identifier = "wasted.habitbell"

    /// Fires only for a habit, not a coincidence: at least 3 active days
    /// across at least 5 on file. Below that, "N of the last M days" is noise
    /// wearing a pattern's clothes.
    static let minActiveDays = 3
    static let minHistoryDays = 5

    struct Plan: Equatable {
        let hour: Int        // window start, 0–23
        let title: String    // "9pm–11pm"
        let body: String
    }

    static func plan(peak: HistoricalPeak?, isPro: Bool) -> Plan? {
        guard
            isPro,
            let peak,
            peak.daysActive >= minActiveDays,
            peak.daysTotal >= minHistoryDays,
            peak.windowSeconds > 0
        else { return nil }

        let perDay = peak.windowSeconds / peak.daysActive
        // Under ~5 minutes a time the window is real but the number is limp —
        // a bell for "4m a time" spends attention it can't pay back.
        guard perDay >= 300 else { return nil }

        return Plan(
            hour: peak.startHour,
            title: peak.label,
            body: "\(peak.daysActive) of the last \(peak.daysTotal) days, "
                + "about \(AppGroupKeys.formattedDuration(perDay)) a time. "
                + "today isn't written yet."
        )
    }

    static func refresh(
        peak: HistoricalPeak?,
        isPro: Bool,
        center: UNUserNotificationCenter = .current()
    ) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let plan = plan(peak: peak, isPro: isPro) else {
            EventLog.log(.nudge, "habit bell: no plan (peak too weak, or not pro)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default

        var components = DateComponents()
        components.hour = plan.hour
        components.minute = 0

        center.add(UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        ))
        EventLog.log(.nudge, "habit bell SET for \(plan.hour):00 — \"\(plan.body)\"")
    }
}
