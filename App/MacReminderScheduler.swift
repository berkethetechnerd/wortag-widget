import UserNotifications
import Foundation

@MainActor
final class MacReminderScheduler: NSObject, ReminderScheduling, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    var onOpenPractice: (() -> Void)?
    override init() { super.init(); center.delegate = self }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .allowed
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
    func requestPermission() async throws -> Bool { try await center.requestAuthorization(options: [.alert]) }

    func replace(with preference: DailyReminder) async throws {
        guard preference.isValid else { throw WortagError.message("Invalid daily reminder preference.") }
        let allIDs = (1...7).map { "wortag.daily.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIDs)
        center.removeDeliveredNotifications(withIdentifiers: allIDs)
        guard preference.enabled else { return }
        do {
            for weekday in preference.weekdays.sorted() {
                let content = UNMutableNotificationContent()
                content.title = "A little German, today"
                content.body = "Take a moment to recall a few words in Wortag."
                content.userInfo = ["route": "practice"]
                var components = DateComponents()
                components.weekday = weekday; components.hour = preference.hour; components.minute = preference.minute
                try await center.add(UNNotificationRequest(identifier: "wortag.daily.\(weekday)", content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
            }
        } catch {
            center.removePendingNotificationRequests(withIdentifiers: allIDs)
            throw error
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let isPractice = response.notification.request.content.userInfo["route"] as? String == "practice"
        Task { @MainActor in if isPractice { self.onOpenPractice?() }; completionHandler() }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
