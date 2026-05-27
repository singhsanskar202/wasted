import Foundation
import UserNotifications

final class NotificationScheduler {

    private static let messages: [Int: [String]] = [
        1: [
            "1 hour on %@. That's 60 minutes you won't get back. Still scrolling?",
            "You've spent an hour on %@ today. Was it worth it?",
            "%@ has had your attention for a full hour. Just so you know."
        ],
        2: [
            "2 hours on %@. That's a workout, a book chapter, a walk. Just saying.",
            "Two hours on %@. What did you find?",
            "%@ again. Two hours today. No judgement. Just numbers."
        ],
        3: [
            "3 hours on %@. Longer than most people exercise in a week.",
            "Still here? %@. Three hours. Wow.",
            "Three hours on %@. Your goals are still waiting."
        ]
    ]

    private static let defaultMessages = [
        "%@: another hour gone.",
        "You've been on %@ for %d hours today.",
        "%d hours on %@. You're aware now."
    ]

    func scheduleHourlyMilestone(appName: String, hours: Int, totalSeconds: Int = 0) {
        let variants = Self.messages[hours] ?? Self.defaultMessages
        let template = variants.randomElement()!

        let base: String
        if template.contains("%d") {
            base = String(format: template, appName, hours)
        } else {
            base = String(format: template, appName)
        }

        let body: String
        if let eq = EquivalentTaskMapper.equivalent(for: totalSeconds) {
            body = "\(base) That's \(eq.description) \(eq.emoji)."
        } else {
            body = base
        }

        let content = UNMutableNotificationContent()
        content.title = "\(hours)h on \(appName)"
        content.body = body
        content.sound = .default

        let identifier = "wasted.\(appName).\(hours)h.\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
