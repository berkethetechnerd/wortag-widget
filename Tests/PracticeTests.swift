import XCTest
@testable import WortagCore

final class PracticeTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1700000000)
    func testRevealDoesNotRecordAndOnlyOneGradeCanConsumeQuestion() {
        var state = LearningState()
        state.startPractice(ids: ["a", "b"], now: now, cardID: "a")
        let token = state.practice!.id
        state.gradePractice(token, grade: .good, ids: ["a", "b"], now: now)
        XCTAssertNil(state.recallHistory)
        state.revealPractice(token)
        XCTAssertNil(state.recallHistory)
        state.gradePractice(token, grade: .good, ids: ["a", "b"], now: now)
        state.gradePractice(token, grade: .again, ids: ["a", "b"], now: now)
        XCTAssertEqual(state.recallHistory?.events.count, 1)
        XCTAssertEqual(state.recallHistory?.events.first?.grade, .good)
        XCTAssertEqual(state.reviews["a"]?.stage, 1)
        XCTAssertEqual(state.practice?.cardID, "b")
    }
    func testAgainReturnsSoonerThanGoodAndEasyAndStageIsBounded() {
        let again = ReviewSchedule.graded(.again, id: "a", previous: nil, step: 0, now: now)
        let hard = ReviewSchedule.graded(.hard, id: "a", previous: nil, step: 0, now: now)
        let good = ReviewSchedule.graded(.good, id: "a", previous: nil, step: 0, now: now)
        let easy = ReviewSchedule.graded(.easy, id: "a", previous: nil, step: 0, now: now)
        XCTAssertLessThan(again.dueDate, hard.dueDate)
        XCTAssertLessThan(hard.dueDate, good.dueDate)
        XCTAssertLessThan(good.dueDate, easy.dueDate)
        var review = easy
        for _ in 0..<20 { review = ReviewSchedule.graded(.easy, id: "a", previous: review, step: 0, now: now) }
        XCTAssertEqual(review.stage, ReviewSchedule.steps.count - 1)
    }
    func testBrowsingCannotAdvanceGradedReviewAndFutureReviewsDoNotFillPractice() {
        var state = LearningState()
        state.reviews["a"] = ReviewSchedule.graded(.good, id: "a", previous: nil, step: 0, now: now)
        let review = state.reviews["a"]
        state.next(ids: ["a"], now: now.addingTimeInterval(360000))
        XCTAssertEqual(state.reviews["a"], review)
        state.startPractice(ids: ["a"], now: now)
        XCTAssertNil(state.practice)
        state.startPractice(ids: ["a"], now: now.addingTimeInterval(360000))
        XCTAssertEqual(state.practice?.cardID, "a")
    }
    func testPracticePersistsAcrossTwoStoresAndStaleConcurrentGradesAreIgnored() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cards = ["a", "b"].map { WordCard(id: $0, word: $0, examples: []) }
        let one = LearningStore(vocabulary: Vocabulary(cards: cards), directory: folder)
        let two = LearningStore(vocabulary: Vocabulary(cards: cards), directory: folder)
        try one.perform(.practice("a"), now: now)
        let token = try two.snapshot(now: now).state.practice!.id
        try one.perform(.reveal(token), now: now)
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            do { try two.perform(.grade(token, .good), now: self.now) } catch { XCTFail(error.localizedDescription) }
        }
        let result = try one.snapshot(now: now)
        XCTAssertEqual(result.state.recallHistory?.events.count, 1)
        XCTAssertEqual(result.practiceCard?.id, "b")
    }
    func testVersionOneMigrationBacksUpOriginalBytesAndPreservesLearning() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        var old = LearningState(); old.version = 1; old.start(ids: ["a"], now: now)
        let bytes = try JSONEncoder().encode(old)
        try bytes.write(to: folder.appendingPathComponent("learning.json"))
        let store = LearningStore(vocabulary: Vocabulary(cards: [WordCard(id: "a", word: "a", examples: [])]), directory: folder)
        let state = try store.snapshot(now: now).state
        XCTAssertEqual(state.version, 2)
        XCTAssertEqual(state.history, old.history)
        XCTAssertEqual(state.seen, old.seen)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("learning-v1-backup.json")), bytes)
    }

    func testPracticeWidgetDoesNotAdvanceHiddenDiscoveryAndResumesWhenDue() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let cards = ["a", "b"].map { WordCard(id: $0, word: $0, examples: []) }
        let store = LearningStore(vocabulary: Vocabulary(cards: cards), directory: folder)
        for id in ["a", "b"] {
            try store.perform(.practice(id), now: now)
            let token = try store.snapshot(now: now).state.practice!.id
            try store.perform(.reveal(token), now: now)
            try store.perform(.grade(token, .good), now: now)
        }
        try store.perform(.widgetPractice(true), now: now)
        let before = try store.snapshot(now: now)
        XCTAssertNil(before.practiceCard)
        let idle = try store.snapshot(now: now.addingTimeInterval(3600), rotateIfDue: true)
        XCTAssertEqual(idle.state.advances, before.state.advances)
        XCTAssertEqual(idle.state.history, before.state.history)
        XCTAssertNil(idle.practiceCard)
        XCTAssertEqual(WidgetRefreshPolicy.nextDate(for: idle, now: now.addingTimeInterval(3600)),
                       now.addingTimeInterval(86400))
        let due = try store.snapshot(now: now.addingTimeInterval(86400), rotateIfDue: true)
        XCTAssertEqual(due.practiceCard?.id, "a")
        XCTAssertEqual(due.state.reviews, before.state.reviews)
        XCTAssertEqual(due.state.advances, before.state.advances)
        XCTAssertEqual(due.state.recallHistory?.events.count, 2)
        XCTAssertEqual(WidgetRefreshPolicy.nextDate(for: due, now: now.addingTimeInterval(86400)),
                       now.addingTimeInterval(90000))
    }
}
