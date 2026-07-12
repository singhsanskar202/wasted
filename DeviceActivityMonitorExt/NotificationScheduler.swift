import Foundation
import UserNotifications

final class NotificationScheduler {

    // The body is chosen by the caller (which owns the store, and so knows
    // which lines today has already spent) — this just delivers it.
    //
    // The identifier is deterministic on app + threshold rather than random:
    // DeviceActivity replays passed thresholds in bursts after a re-registration,
    // and a random id would turn each replay into a fresh buzz. Same threshold,
    // same id, so iOS collapses the duplicate instead of firing it twice.
    func scheduleNudge(appName: String, minutes: Int, body: String) {
        let content = UNMutableNotificationContent()
        content.title = NudgeCopy.title(minutes: minutes)
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "wasted.nudge.\(appName).\(minutes)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
