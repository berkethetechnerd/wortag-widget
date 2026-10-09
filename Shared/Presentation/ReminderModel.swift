import Foundation
import Combine

enum NotificationPermission: Equatable { case notDetermined, denied, allowed }

@MainActor
protocol ReminderScheduling {
    func permission() async -> NotificationPermission
    func requestPermission() async throws -> Bool
    func replace(with preference: DailyReminder) async throws
}

/// Controls opt-in and reconciliation; the platform adapter owns notification
/// requests, while the repository remains the authority for saved preferences.
@MainActor
final class ReminderModel: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published var openPractice = false
    var showPracticeWindow: (() -> Void)?
    private let scheduler: any ReminderScheduling
    private var applied: DailyReminder?

    init(scheduler: any ReminderScheduling) { self.scheduler = scheduler }

    func requestPractice() {
        showPracticeWindow?()
        openPractice = true
    }

    func reconcile(_ preference: DailyReminder, force: Bool = false) async {
        guard !busy, force || preference != applied else { return }
        busy = true
        defer { busy = false }
        do {
            let permission = await scheduler.permission()
            if preference.enabled && permission != .allowed {
                try await scheduler.replace(with: DailyReminder())
                message = "Daily reminders are blocked by macOS. Allow Wortag in System Settings → Notifications, then return here."
            } else {
                try await scheduler.replace(with: preference)
                message = preference.enabled ? "Daily reminders are scheduled. Focus and macOS notification settings may silence them." : nil
            }
            applied = preference
        } catch { message = "Could not schedule reminders: \(error.localizedDescription)" }
    }


    func save(_ preference: DailyReminder, previous: DailyReminder,
              persist: (DailyReminder) -> Bool) async {
        guard !busy, preference.isValid else { message = "Choose a valid time and at least one weekday."; return }
        busy = true
        defer { busy = false }
        do {
            if preference.enabled {
                switch await scheduler.permission() {
                case .denied:
                    message = "Allow Wortag in System Settings → Notifications before enabling daily reminders."
                    return
                case .notDetermined:
                    guard try await scheduler.requestPermission() else {
                        message = "Notification permission was not granted. No reminder was enabled."
                        return
                    }
                case .allowed: break
                }
            }
            try await scheduler.replace(with: preference)
            guard persist(preference) else {
                try? await scheduler.replace(with: previous)
                message = "Reminder preferences could not be saved. The previous schedule was restored where possible."
                return
            }
            applied = preference
            message = preference.enabled ? "Daily reminders are scheduled. Focus and macOS notification settings may silence them." : "Daily reminders are off."
        } catch {
            try? await scheduler.replace(with: previous)
            message = "Could not schedule reminders: \(error.localizedDescription)"
        }
    }

    /// Cancel notifications before deleting progress. A failed store write uses
    /// the same schedule restoration as an ordinary reminder preference change.
    func resetProgress(previous: DailyReminder, persist: () -> Bool) async -> Bool {
        var committed = false
        await save(DailyReminder(), previous: previous) { _ in
            committed = persist()
            return committed
        }
        if committed {
            openPractice = false
            message = "Progress reset. All word reviews and daily reminders have been cleared."
        }
        return committed
    }
}

/// Layout fixtures never talk to the real notification center or request access.
@MainActor
final class PreviewReminderScheduler: ReminderScheduling {
    func permission() async -> NotificationPermission { .allowed }
    func requestPermission() async throws -> Bool { true }
    func replace(with preference: DailyReminder) async throws {}
}
