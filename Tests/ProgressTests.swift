import XCTest
@testable import WortagCore

final class ProgressTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1700000000)
    func testOnlyGradedAnswersCountAndAgainIsNotRecalled() {
        var state = LearningState()
        state.start(ids: ["a", "b"], now: now)
        state.next(ids: ["a", "b"], now: now)
        let cards = ["a", "b"].map { WordCard(id: $0, word: $0, examples: []) }
        XCTAssertEqual(ProgressSummary(state: state, cards: cards, now: now).totalReviews, 0)
        state.startPractice(ids: ["a", "b"], now: now, cardID: "a")
        var token = state.practice!.id; state.revealPractice(token)
        state.gradePractice(token, grade: .again, ids: ["a", "b"], now: now)
        token = state.practice!.id; state.revealPractice(token)
        state.gradePractice(token, grade: .hard, ids: ["a", "b"], now: now)
        let summary = ProgressSummary(state: state, cards: cards, now: now)
        XCTAssertEqual(summary.today.reviews, 2)
        XCTAssertEqual(summary.totalRecalled, 1)
        XCTAssertEqual(summary.recallRate, 0.5)
        XCTAssertEqual(summary.week.count, 7)
        XCTAssertEqual(summary.week.last?.reviews, 2)
        XCTAssertEqual(summary.difficultWords.map(\.id), ["a", "b"])
        XCTAssertEqual(summary.difficultWords.map(\.difficultRatings), [1, 1])
    }
    func testDailyGoalAndDateRolloverIncludingDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let before = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 59))!
        let after = before.addingTimeInterval(120)
        var state = LearningState(); var history = RecallHistory()
        history.record(RecallEvent(id: UUID(), cardID: "a", grade: .good, date: before), calendar: calendar)
        state.recallHistory = history
        let summary = ProgressSummary(state: state, cards: [], now: after, calendar: calendar)
        XCTAssertEqual(summary.today.reviews, 0)
        XCTAssertEqual(summary.totalReviews, 1)
        XCTAssertEqual(summary.week.dropLast().last?.reviews, 1)
    }

    func testDayKeysSurviveRegionalCalendarChangesAndRespectLocalTimeZone() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = gregorian.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 23))!
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = gregorian.timeZone
        XCTAssertEqual(RecallHistory.dayKey(date, calendar: buddhist), "2026-10-09")
        buddhist.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual(RecallHistory.dayKey(date, calendar: buddhist), "2026-10-10")
    }
}

extension ProgressTests {
    func testInvalidAggregateCannotOverflowStatistics() throws {
        var history = RecallHistory()
        history.days = ["2026-10-08": DailyActivity(reviews: ReviewSchedule.maximumCounter, recalled: 0),
                        "2026-10-09": DailyActivity(reviews: ReviewSchedule.maximumCounter, recalled: 0)]
        XCTAssertFalse(history.isValid)
        var state = LearningState(); state.recallHistory = history
        XCTAssertThrowsError(try state.validate())
    }
}
