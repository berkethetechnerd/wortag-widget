import XCTest
@testable import WortagCore

final class LearningTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1700000000)
    let ids = (0..<100).map { "word-\($0)" }

    func testRevisedDeckSkipsArchivedHistoryAndRemindersWithoutErasingProgress() {
        var state = LearningState()
        state.history = ["vertrag", "wohnung", "genehmigung", "kolumbien"]
        state.cursor = 1
        state.advances = 50
        state.seen = Set(state.history)
        state.bag = ["wohnung", "vertrag", "genehmigung", "kolumbien"]
        state.remind(id: "wohnung", now: now)
        state.remind(id: "vertrag", now: now)
        let originalReviews = state.reviews
        let active = ["vertrag", "genehmigung"]
        state.start(ids: active, now: now)
        XCTAssertEqual(state.currentID, "genehmigung")
        XCTAssertEqual(state.advances, 50)
        XCTAssertEqual(state.reviews, originalReviews)
        XCTAssertTrue(state.canGoBack(ids: Set(active)))
        state.previous(now: now, ids: Set(active))
        XCTAssertEqual(state.currentID, "vertrag")
        XCTAssertFalse(state.canGoBack(ids: Set(active)))
        state.next(ids: active, now: now)
        XCTAssertEqual(state.currentID, "genehmigung")
        for _ in 0..<1000 {
            state.next(ids: active, now: now)
            XCTAssertTrue(Set(active).contains(state.currentID!))
            XCTAssertFalse(state.bag.contains("wohnung"))
        }
        XCTAssertTrue(state.history.contains("wohnung"))
        XCTAssertTrue(state.seen.contains("kolumbien"))
        XCTAssertEqual(state.reviews["wohnung"], originalReviews["wohnung"])
        XCTAssertGreaterThan(state.reviews["vertrag"]!.stage, 0)
    }

    func testStoreAdvancesArchivedCurrentCardAndCountsOnlyActiveProgress() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var state = LearningState()
        state.history = ["wohnung"]
        state.seen = ["wohnung"]
        state.remind(id: "wohnung", now: now)
        try JSONEncoder().encode(state).write(to: folder.appendingPathComponent("learning.json"))
        let vocabulary = Vocabulary(cards: [
            WordCard(id: "wohnung", word: "Wohnung", examples: [], active: false),
            WordCard(id: "bewältigen", word: "bewältigen", examples: [], active: true)
        ])
        let snapshot = try LearningStore(vocabulary: vocabulary, directory: folder).snapshot(now: now)
        XCTAssertEqual(snapshot.card.id, "bewältigen")
        XCTAssertEqual(snapshot.wordCount, 1)
        XCTAssertEqual(snapshot.seenCount, 1)
        XCTAssertEqual(snapshot.reviewCount, 0)
        XCTAssertFalse(snapshot.canGoBack)
        XCTAssertNotNil(snapshot.state.reviews["wohnung"])
        XCTAssertEqual(snapshot.state.history, ["wohnung", "bewältigen"])
    }

    func testShuffleVisitsEveryWordBeforeCyclingAndNeverRunsOut() {
        var state = LearningState()
        for _ in 0..<100 { state.next(ids: ids, now: now) }
        XCTAssertEqual(Set(state.history).count, 100)
        for _ in 0..<20000 {
            let previous = state.currentID
            state.next(ids: ids, now: now)
            XCTAssertNotEqual(state.currentID, previous)
        }
        XCTAssertEqual(state.history.count, 5000)
        XCTAssertEqual(state.cursor, 4999)
        XCTAssertEqual(state.seen.count, 100)
    }

    func testPreviousAndNextReplayHistoryWithoutAdvancingSchedule() {
        var state = LearningState()
        state.start(ids: ids, now: now)
        state.next(ids: ids, now: now)
        let second = state.currentID
        let step = state.advances
        state.previous(now: now)
        state.next(ids: ids, now: now)
        XCTAssertEqual(state.currentID, second)
        XCTAssertEqual(state.advances, step)
        XCTAssertEqual(state.history.count, 2)
        state.previous(now: now)
        state.previous(now: now)
        XCTAssertEqual(state.cursor, 0)
    }

    func testReminderReturnsAfterFourCardsThenTwelveThenThirtySix() {
        var state = LearningState()
        state.start(ids: ids, now: now)
        let word = state.currentID!
        state.remind(id: word, now: now)
        for _ in 0..<3 {
            state.next(ids: ids, now: now)
            XCTAssertNotEqual(state.currentID, word)
        }
        state.next(ids: ids, now: now)
        XCTAssertEqual(state.currentID, word)
        XCTAssertEqual(state.reviews[word]?.stage, 1)
        for _ in 0..<11 { state.next(ids: ids, now: now); XCTAssertNotEqual(state.currentID, word) }
        state.next(ids: ids, now: now)
        XCTAssertEqual(state.currentID, word)
        XCTAssertEqual(state.reviews[word]?.dueStep, state.advances + 36)
    }

    func testTimeDueReviewTakesPriority() {
        var state = LearningState()
        state.start(ids: ids, now: now)
        let word = state.currentID!
        state.remind(id: word, now: now)
        state.next(ids: ids, now: now)
        state.next(ids: ids, now: now.addingTimeInterval(3601))
        XCTAssertEqual(state.currentID, word)
    }

    func testRepeatedRemindDoesNotDuplicateOrPostpone() {
        var state = LearningState()
        state.start(ids: ids, now: now)
        let word = state.currentID!
        state.remind(id: word, now: now)
        let due = state.reviews[word]!
        state.remind(id: word, now: now.addingTimeInterval(1200))
        XCTAssertEqual(state.reviews.count, 1)
        XCTAssertEqual(state.reviews[word], due)
    }

    func testEmptyAndOneWordDecks() {
        var state = LearningState()
        state.next(ids: [], now: now)
        XCTAssertNil(state.currentID)
        for _ in 0..<100 {
            state.next(ids: ["only"], now: now)
            state.remind(id: "only", now: now)
        }
        XCTAssertEqual(state.currentID, "only")
    }

    private func makeStores() throws -> (LearningStore, LearningStore, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let vocab = Vocabulary(cards: ids.map { WordCard(id: $0, word: $0, examples: []) })
        return (LearningStore(vocabulary: vocab, directory: folder), LearningStore(vocabulary: vocab, directory: folder), folder)
    }

    func testPersistenceAndMultipleWritersPreserveEveryAdvance() throws {
        let (a, b, folder) = try makeStores()
        defer { try? FileManager.default.removeItem(at: folder) }
        _ = try a.snapshot(now: now)
        DispatchQueue.concurrentPerform(iterations: 100) { n in
            do { try (n.isMultiple(of: 2) ? a : b).perform(.next, now: now) }
            catch { XCTFail(error.localizedDescription) }
        }
        let snapshot = try b.snapshot(now: now)
        XCTAssertEqual(snapshot.state.advances, 101)
        XCTAssertEqual(snapshot.state.history.count, 101)
        try a.perform(.translations(true), now: now)
        XCTAssertTrue(try b.snapshot(now: now).state.showTranslations)
    }

    func testCorruptStateIsPreserved() throws {
        let (a, _, folder) = try makeStores()
        defer { try? FileManager.default.removeItem(at: folder) }
        _ = try a.snapshot(now: now)
        let file = folder.appendingPathComponent("learning.json")
        let bytes = Data("broken state".utf8)
        try bytes.write(to: file)
        XCTAssertThrowsError(try a.perform(.next, now: now))
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }

    func testAutomaticRotationDoesNotSkipHoursOrAdvanceWhenDisabled() throws {
        let (a, _, folder) = try makeStores()
        defer { try? FileManager.default.removeItem(at: folder) }
        _ = try a.snapshot(now: now)
        XCTAssertEqual(try a.snapshot(now: now.addingTimeInterval(7200), rotateIfDue: true).state.advances, 2)
        XCTAssertEqual(try a.snapshot(now: now.addingTimeInterval(7200), rotateIfDue: true).state.advances, 2)
        try a.perform(.rotation(false), now: now)
        XCTAssertEqual(try a.snapshot(now: now.addingTimeInterval(100000), rotateIfDue: true).state.advances, 2)
    }
}
