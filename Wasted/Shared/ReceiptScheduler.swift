import Foundation
import UserNotifications

// Local notifications carry static content, so the 9 PM receipt is
// re-scheduled with fresh totals on every threshold event (extension) and on
// every foreground (main app), so the last refresh before 9 PM has the
// current totals; re-adding with the same identifier replaces the pending
// request.
final class ReceiptScheduler {
    static let identifier = "wasted.receipt"

    func refresh(usage: DailyUsage, displayNames: [String: String], now: Date = Date()) {
        let receipt = DailyReceipt.build(usage: usage, displayNames: displayNames)
        guard receipt.totalSeconds > 0 else { return }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: now)
        comps.hour = AppGroupKeys.receiptHour
        guard let fireDate = Calendar.current.date(from: comps), fireDate > now else {
            // Past 9pm the receipt can no longer be scheduled for today. Silent
            // until now — and "why did I never get a receipt?" is a question the
            // log has to be able to answer.
            EventLog.log(.receipt, "not scheduled — past \(AppGroupKeys.receiptHour):00 already")
            return
        }

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
        EventLog.log(.receipt, "scheduled for \(AppGroupKeys.receiptHour):00 — \"\(receipt.summaryLine)\"")
    }
}
