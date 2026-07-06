import Foundation
import UserNotifications

// Local notifications carry static content, so the 9 PM receipt is
// re-scheduled with fresh totals on every threshold event; re-adding with the
// same identifier replaces the pending request, and the last refresh before
// 9 PM is what fires.
final class ReceiptScheduler {
    static let identifier = "wasted.receipt"

    func refresh(usage: DailyUsage, displayNames: [String: String], now: Date = Date()) {
        let receipt = DailyReceipt.build(usage: usage, displayNames: displayNames)
        guard receipt.totalSeconds > 0 else { return }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.hour = AppGroupKeys.receiptHour
        guard let fireDate = Calendar.current.date(from: comps), fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "today's receipt"
        content.body = receipt.summaryLine
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: fireDate),
            repeats: false
        )
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger)
        )
    }
}
