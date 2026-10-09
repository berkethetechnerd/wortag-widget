import XCTest
@testable import WortagCore

@MainActor
final class ReminderTests: XCTestCase {
    final class Scheduler: ReminderScheduling {
        var status = NotificationPermission.notDetermined
        var grants = false
        var prompts = 0
        var replaced: [DailyReminder] = []
        var fails = false
        func permission() async -> NotificationPermission { status }
        func requestPermission() async throws -> Bool { prompts += 1; return grants }
        func replace(with preference: DailyReminder) async throws {
            if fails { throw WortagError.message("Scheduling failed") }
            replaced.append(preference)
        }
    }
    func testStartupAndDeniedPermissionNeverPromptOrPersistOptIn() async {
        let backend = Scheduler(); let model = ReminderModel(scheduler: backend)
        await model.reconcile(DailyReminder())
        XCTAssertEqual(backend.prompts, 0)
        var enabled = DailyReminder(); enabled.enabled = true
        var writes = 0
        await model.save(enabled, previous: DailyReminder()) { _ in writes += 1; return true }
        XCTAssertEqual(backend.prompts, 1)
        XCTAssertEqual(writes, 0)
        backend.status = .denied
        await model.save(enabled, previous: DailyReminder()) { _ in writes += 1; return true }
        XCTAssertEqual(backend.prompts, 1)
        XCTAssertEqual(writes, 0)
    }
    func testChangingTimeReplacesScheduleAndDisablingCancelsIt() async {
        let backend = Scheduler(); backend.status = .allowed
        let model = ReminderModel(scheduler: backend)
        var preference = DailyReminder(); preference.enabled = true; preference.weekdays = [2, 4]
        await model.save(preference, previous: DailyReminder()) { _ in true }
        preference.hour = 17; preference.minute = 30
        await model.save(preference, previous: DailyReminder()) { _ in true }
        XCTAssertEqual(backend.replaced.last?.hour, 17)
        XCTAssertEqual(preference.requestIDs, ["wortag.daily.2", "wortag.daily.4"])
        await model.save(DailyReminder(), previous: preference) { _ in true }
        XCTAssertEqual(backend.replaced.last?.requestIDs, [])
    }
    func testFailedPreferenceWriteRestoresScheduleAndSchedulingFailureDoesNotPersist() async {
        let backend = Scheduler(); backend.status = .allowed
        let model = ReminderModel(scheduler: backend)
        var next = DailyReminder(); next.enabled = true
        await model.save(next, previous: DailyReminder()) { _ in false }
        XCTAssertEqual(backend.replaced.last, DailyReminder())
        backend.fails = true
        var writes = 0
        await model.save(next, previous: DailyReminder()) { _ in writes += 1; return true }
        XCTAssertEqual(writes, 0)
        XCTAssertTrue(model.message?.contains("Scheduling failed") == true)
    }
    func testInvalidWeekdaysAndTimesAreRejected() async {
        var config = DailyReminder(); config.enabled = true; config.weekdays = []
        XCTAssertFalse(config.isValid)
        config.weekdays = [0, 8]; XCTAssertFalse(config.isValid)
        config.weekdays = [1]; config.hour = 24; XCTAssertFalse(config.isValid)
        config.hour = 9; config.minute = 60; XCTAssertFalse(config.isValid)
    }

    func testNotificationRouteOpensWindowAndRetainsPracticeRequest() async {
        let model = ReminderModel(scheduler: Scheduler())
        var opens = 0
        model.showPracticeWindow = { opens += 1 }
        model.requestPractice()
        XCTAssertEqual(opens, 1)
        XCTAssertTrue(model.openPractice)
        model.openPractice = false
        model.showPracticeWindow = nil
        model.requestPractice()
        XCTAssertTrue(model.openPractice)
    }

    func testResetCancelsRemindersWithoutPermissionPromptAndClearsPendingRoute() async {
        let backend = Scheduler(); backend.status = .denied
        let model = ReminderModel(scheduler: backend)
        model.openPractice = true
        var previous = DailyReminder(); previous.enabled = true
        var writes = 0
        let success = await model.resetProgress(previous: previous) { writes += 1; return true }
        XCTAssertTrue(success)
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(backend.prompts, 0)
        XCTAssertEqual(backend.replaced, [DailyReminder()])
        XCTAssertFalse(model.openPractice)
        XCTAssertTrue(model.message?.contains("Progress reset") == true)
        // Reconciliation must not reinstall the pre-reset schedule.
        await model.reconcile(DailyReminder())
        XCTAssertEqual(backend.replaced, [DailyReminder()])
    }

    func testResetFailureRestoresReminderScheduleAndDoesNotReportSuccess() async {
        let backend = Scheduler(); backend.status = .allowed
        let model = ReminderModel(scheduler: backend)
        var previous = DailyReminder(); previous.enabled = true; previous.weekdays = [2]
        let success = await model.resetProgress(previous: previous) { false }
        XCTAssertFalse(success)
        XCTAssertEqual(backend.replaced, [DailyReminder(), previous])
        XCTAssertTrue(model.message?.contains("could not be saved") == true)
        backend.fails = true
        var writes = 0
        let failedCancellation = await model.resetProgress(previous: previous) { writes += 1; return true }
        XCTAssertFalse(failedCancellation)
        XCTAssertEqual(writes, 0)
    }
}
