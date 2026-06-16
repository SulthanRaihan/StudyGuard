//
//  NotificationService.swift
//  StudyGuard
//

import UserNotifications

/// Local notifications. Currently used to notify when a break is over even if the
/// user has backgrounded the app.
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let breakEndID = "break-end"

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Fires a "break's over" notification after `seconds`.
    func scheduleBreakEnd(after seconds: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "Break's over"
        content.body = "Ready to get back to studying? 🐱"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: breakEndID, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelBreakEnd() {
        center.removePendingNotificationRequests(withIdentifiers: [breakEndID])
    }
}
