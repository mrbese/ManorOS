import Foundation
import UserNotifications

enum NotificationScheduler {
    private static let monthlyAuditReminderID = "monthly_audit_reminder"

    static func scheduleMonthlyAuditReminder() async {
        let center = UNUserNotificationCenter.current()

        // Request permission if needed.
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }

        let settingsAfter = await center.notificationSettings()
        guard settingsAfter.authorizationStatus == .authorized || settingsAfter.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Monthly energy check-in"
        content.body = "Open Manor OS to review your home report and see what changed."
        content.sound = .default

        var date = DateComponents()
        date.day = 1
        date.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)

        let request = UNNotificationRequest(
            identifier: monthlyAuditReminderID,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [monthlyAuditReminderID])
        try? await center.add(request)
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [monthlyAuditReminderID])
    }
}

