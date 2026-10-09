import Foundation

enum RecallGrade: String, Codable, CaseIterable, Identifiable {
    case again = "Again", hard = "Hard", good = "Good", easy = "Easy"
    var id: String { rawValue }
    var recalled: Bool { self != .again }
}

struct PracticeChallenge: Codable, Equatable {
    let id: UUID
    let cardID: String
    var revealed = false
}

struct RecallEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let cardID: String
    let grade: RecallGrade
    let date: Date
}

struct DailyActivity: Codable, Equatable {
    var reviews = 0
    var recalled = 0
}

struct RecallHistory: Codable, Equatable {
    var events: [RecallEvent] = []
    var days: [String: DailyActivity] = [:]

    mutating func record(_ event: RecallEvent, calendar: Calendar = .current) {
        events.append(event)
        if events.count > 5000 { events.removeFirst(events.count - 5000) }
        let key = Self.dayKey(event.date, calendar: calendar)
        var day = days[key] ?? DailyActivity()
        day.reviews += 1
        if event.grade.recalled { day.recalled += 1 }
        days[key] = day
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        // Stable keys survive a change of the Mac's preferred calendar. Retain
        // its time zone so a review still belongs to the user's local day.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    var isValid: Bool {
        guard events.count <= 5000, Set(events.map(\.id)).count == events.count,
              events.allSatisfy({ !$0.cardID.isEmpty && $0.date.timeIntervalSinceReferenceDate.isFinite }) else { return false }
        var total = 0
        for (key, day) in days {
            guard key.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                  day.reviews >= 0, day.reviews <= ReviewSchedule.maximumCounter,
                  day.recalled >= 0, day.recalled <= day.reviews else { return false }
            let sum = total.addingReportingOverflow(day.reviews)
            guard !sum.overflow, sum.partialValue <= ReviewSchedule.maximumCounter else { return false }
            total = sum.partialValue
        }
        return true
    }

}

extension ReviewSchedule {
    static func graded(_ grade: RecallGrade, id: String, previous: Review?, step: Int, now: Date) -> Review {
        let stage: Int
        switch grade {
        case .again: stage = 0
        case .hard: stage = max(0, (previous?.stage ?? 0) - 1)
        case .good: stage = min((previous?.stage ?? 0) + 1, steps.count - 1)
        case .easy: stage = min((previous?.stage ?? 0) + 2, steps.count - 1)
        }
        return Review(id: id, stage: stage, dueStep: step + (grade == .again ? 1 : steps[stage]),
                      dueDate: now.addingTimeInterval(grade == .again ? 600 : hours[stage] * 3600), graded: true)
    }
}

extension LearningState {
    mutating func startPractice(ids: [String], now: Date, cardID: String? = nil, excluding: String? = nil) {
        let valid = Set(ids)
        if let cardID, valid.contains(cardID) {
            practice = PracticeChallenge(id: UUID(), cardID: cardID)
            return
        }
        if let practice, valid.contains(practice.cardID) { return }
        let due = reviews.values.filter {
            valid.contains($0.id) && ($0.dueDate <= now || $0.dueStep <= advances)
        }.sorted { $0.precedes($1) }
        let eligibleDue = due.first { $0.id != excluding } ?? due.first
        let new = ids.filter { reviews[$0] == nil }
        let available = new.filter { $0 != excluding }
        let id = eligibleDue?.id ?? (available.isEmpty ? new : available).randomElement()
        practice = id.map { PracticeChallenge(id: UUID(), cardID: $0) }
    }

    mutating func revealPractice(_ token: UUID) {
        guard practice?.id == token else { return }
        practice?.revealed = true
    }

    /// Persistent challenge tokens make repeated/stale widget clicks idempotent.
    mutating func gradePractice(_ token: UUID, grade: RecallGrade, ids: [String], now: Date) {
        guard let challenge = practice, challenge.id == token, challenge.revealed,
              ids.contains(challenge.cardID) else { return }
        let id = challenge.cardID
        advances += 1
        reviews[id] = ReviewSchedule.graded(grade, id: id, previous: reviews[id], step: advances, now: now)
        var history = recallHistory ?? RecallHistory()
        history.record(RecallEvent(id: token, cardID: id, grade: grade, date: now))
        recallHistory = history
        seen.insert(id)
        bag.removeAll { $0 == id }
        practice = nil
        startPractice(ids: ids, now: now, excluding: id)
    }
}
