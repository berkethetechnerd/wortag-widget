import XCTest
import Combine
@testable import WortagCore

final class ReviewRegressionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1700000000)

    func testInvalidScheduleAndEmptyHistoryCursorPreserveFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LearningStore(vocabulary: Vocabulary(cards: [WordCard(id: "word", word: "word", examples: [])]), directory: folder)
        var invalid: [LearningState] = []
        for stage in [-2, ReviewSchedule.steps.count] {
            var state = LearningState()
            state.reviews["word"] = Review(id: "word", stage: stage, dueStep: 0, dueDate: now)
            invalid.append(state)
        }
        var badCursor = LearningState(); badCursor.cursor = -2; invalid.append(badCursor)
        var overflow = LearningState(); overflow.advances = Int.max; invalid.append(overflow)
        var mismatch = LearningState()
        mismatch.reviews["word"] = Review(id: "different", stage: 0, dueStep: 0, dueDate: now)
        invalid.append(mismatch)
        var negative = LearningState(); negative.advances = -1; invalid.append(negative)
        for state in invalid {
            let file = folder.appendingPathComponent("learning.json")
            let bytes = try JSONEncoder().encode(state)
            try bytes.write(to: file)
            XCTAssertThrowsError(try store.snapshot(now: now))
            XCTAssertThrowsError(try store.perform(.next, now: now))
            XCTAssertEqual(try Data(contentsOf: file), bytes)
        }
    }

    func testNextOnFirstLaunchSelectsOneCardWithoutSkipping() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let vocabulary = Vocabulary(cards: (0..<10).map { WordCard(id: "\($0)", word: "\($0)", examples: []) })
        let store = LearningStore(vocabulary: vocabulary, directory: folder)
        try store.perform(.next, now: now)
        let snapshot = try store.snapshot(now: now)
        XCTAssertEqual(snapshot.state.history.count, 1)
        XCTAssertEqual(snapshot.state.advances, 1)
    }

    func testConcurrentAutomaticRefreshOnlyRotatesOnce() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let vocabulary = Vocabulary(cards: (0..<10).map { WordCard(id: "\($0)", word: "\($0)", examples: []) })
        let stores = (0..<12).map { _ in LearningStore(vocabulary: vocabulary, directory: folder) }
        _ = try stores[0].snapshot(now: now)
        DispatchQueue.concurrentPerform(iterations: stores.count) { i in
            do { _ = try stores[i].snapshot(now: now.addingTimeInterval(7200), rotateIfDue: true) }
            catch { XCTFail(error.localizedDescription) }
        }
        XCTAssertEqual(try stores[0].snapshot(now: now).state.advances, 2)
    }

    func testMalformedVocabularyFailsBeforeRendering() throws {
        for json in [
            #"{"cards":[{"id":"a","word":"A","examples":[]}]}"#,
            #"{"cards":[{"id":"","word":"A","examples":[{"german":"A ist gut.","english":"","attribution":"test"}]}]}"#,
            #"{"cards":[{"id":"a","word":"A","active":false,"examples":[{"german":"A ist gut.","english":"","attribution":"test"}]}]}"#
        ] {
            XCTAssertThrowsError(try Vocabulary(data: Data(json.utf8)))
        }
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/vocabulary.json")
        XCTAssertEqual(try Vocabulary(data: Data(contentsOf: file)).cards.count, 1642)
    }

    func testReminderOrderAndSearchWithArticlesWhitespaceAndUmlauts() {
        let cards = [WordCard(id: "z", word: "Zugang", examples: []),
                     WordCard(id: "m", word: "Möglichkeit", examples: [], nounForms: [.init(article: "die", word: "Möglichkeit")]),
                     WordCard(id: "a", word: "Antrag", examples: [])]
        let reviews = ["z": Review(id: "z", stage: 0, dueStep: 20, dueDate: now),
                       "a": Review(id: "a", stage: 0, dueStep: 4, dueDate: now)]
        XCTAssertEqual(LibrarySection.reminders.cards(in: cards, reviews: reviews).map(\.id), ["a", "z"])
        XCTAssertEqual(LibrarySection.search(cards, query: "  DIE MOGLICHKEIT \n").map(\.id), ["m"])
        XCTAssertEqual(LibrarySection.search(cards, query: "   "), cards)
        XCTAssertTrue(LibrarySection.search(cards, query: "not-a-word").isEmpty)
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    private final class Repository: LearningRepository {
        let vocabulary = Vocabulary(cards: [WordCard(id: "a", word: "A", examples: [])])
        var state = LearningState()
        var failsWrites = false
        var failsReads = false
        func snapshot(now: Date, rotateIfDue: Bool) throws -> LearningSnapshot {
            if failsReads { throw WortagError.message("Read failed") }
            state.start(ids: vocabulary.activeIDs, now: Date(timeIntervalSince1970: 0))
            return LearningSnapshot(card: vocabulary.cards[0], state: state, wordCount: 1, activeIDs: vocabulary.activeIDSet)
        }
        func perform(_ action: LearningAction, now: Date) throws {
            if failsWrites { throw WortagError.message("Write failed") }
            if case .translations(let value) = action { state.showTranslations = value }
            if case .dailyReminder(let preference) = action { state.dailyReminder = preference }
        }
    }

    func testRetryRecoversFromFailedStartupAndReloadsWidgets() async {
        let repository = Repository()
        var attempts = 0
        var reloads = 0
        let model = AppModel(makeRepository: {
            attempts += 1
            if attempts == 1 { throw WortagError.message("Temporarily unavailable") }
            return repository
        }, reloadWidgets: { reloads += 1 })
        XCTAssertNotNil(model.error)
        XCTAssertNil(model.snapshot)
        model.refresh()
        XCTAssertNil(model.error)
        XCTAssertEqual(model.cards.count, 1)
        XCTAssertEqual(reloads, 1)
        XCTAssertEqual(attempts, 2)
    }

    func testUnchangedPollingDoesNotRepublishAndWritesRefreshOtherWidgets() async {
        let repository = Repository()
        var reloads = 0
        let model = AppModel(makeRepository: { repository }, reloadWidgets: { reloads += 1 })
        var emissions = 0
        let subscription = model.$snapshot.sink { _ in emissions += 1 }
        model.refresh(); model.refresh()
        XCTAssertEqual(emissions, 1)
        model.act(.translations(true))
        XCTAssertEqual(emissions, 2)
        XCTAssertTrue(model.snapshot!.state.showTranslations)
        XCTAssertEqual(reloads, 2)
        repository.failsWrites = true
        model.act(.next)
        XCTAssertEqual(model.error, "Write failed")
        XCTAssertEqual(reloads, 2)
        withExtendedLifetime(subscription) {}
    }

    func testCommittedReminderPreferenceIsNotReportedAsFailedWhenRefreshFails() async {
        let repository = Repository()
        let model = AppModel(makeRepository: { repository })
        repository.failsReads = true
        var preference = DailyReminder(); preference.enabled = true
        XCTAssertTrue(model.act(.dailyReminder(preference)))
        XCTAssertEqual(repository.state.dailyReminder, preference)
        XCTAssertEqual(model.error, "Read failed")
        repository.failsWrites = true
        XCTAssertFalse(model.act(.dailyReminder(DailyReminder())))
        XCTAssertEqual(repository.state.dailyReminder, preference)
    }
}
