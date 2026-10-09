import Foundation

struct ActivityDay: Identifiable {
    let date: Date
    let reviews: Int
    var id: Date { date }
}
struct DifficultWord: Identifiable {
    let card: WordCard
    let difficultRatings: Int
    var id: String { card.id }
}

struct ProgressSummary {
    let today: DailyActivity
    let totalReviews: Int
    let totalRecalled: Int
    let dueReviews: Int
    let week: [ActivityDay]
    let difficultWords: [DifficultWord]
    var recallRate: Double? { totalReviews == 0 ? nil : Double(totalRecalled) / Double(totalReviews) }

    init(state: LearningState, cards: [WordCard], now: Date, calendar: Calendar = .current) {
        let history = state.recallHistory ?? RecallHistory()
        today = history.days[RecallHistory.dayKey(now, calendar: calendar)] ?? DailyActivity()
        totalReviews = history.days.values.reduce(0) { $0 + $1.reviews }
        totalRecalled = history.days.values.reduce(0) { $0 + $1.recalled }
        let active = Set(cards.map(\.id))
        dueReviews = state.reviews.values.filter {
            active.contains($0.id) && ($0.dueDate <= now || $0.dueStep <= state.advances)
        }.count
        let start = calendar.startOfDay(for: now)
        week = (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return ActivityDay(date: date, reviews: history.days[RecallHistory.dayKey(date, calendar: calendar)]?.reviews ?? 0)
        }
        var failures: [String: Int] = [:]
        for event in history.events.suffix(100) where event.grade == .again || event.grade == .hard {
            failures[event.cardID, default: 0] += 1
        }
        var ranked: [DifficultWord] = []
        for card in cards {
            if let count = failures[card.id] {
                ranked.append(DifficultWord(card: card, difficultRatings: count))
            }
        }
        ranked.sort { left, right in
            if left.difficultRatings == right.difficultRatings { return left.id < right.id }
            return left.difficultRatings > right.difficultRatings
        }
        difficultWords = Array(ranked.prefix(5))
    }
}
