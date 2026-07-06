import Foundation
import UserNotifications

final class NotificationScheduler {

    func scheduleNudge(appName: String, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = NudgeCopy.title(appName: appName, minutes: minutes)
        content.body = NudgeCopy.body(at: Int.random(in: 0..<NudgeCopy.bodies.count))
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "wasted.nudge.\(appName).\(minutes)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
