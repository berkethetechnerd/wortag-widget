import Foundation

struct Review: Codable, Equatable, Identifiable {
    let id: String
    var stage: Int
    var dueStep: Int
    var dueDate: Date
    var graded: Bool? = nil
}

struct LearningState: Codable, Equatable {
    var version = 2
    var history: [String] = []
    var cursor = 0
    var bag: [String] = []
    var advances = 0
    var seen: Set<String> = []
    var reviews: [String: Review] = [:]
    var nextAutomaticAt = Date.distantPast
    var showTranslations = false
    var automaticRotation = true
    var practice: PracticeChallenge?
    var recallHistory: RecallHistory?
    var practiceInWidget: Bool?
    var dailyGoal: Int?
    var dailyReminder: DailyReminder?

    var currentID: String? { history.indices.contains(cursor) ? history[cursor] : nil }
    var canGoBack: Bool { cursor > 0 }

    /// Return whether initialization or a deck update already selected a card.
    @discardableResult mutating func start(ids: [String], now: Date) -> Bool {
        guard currentID.map({ !ids.contains($0) }) ?? true else { return false }
        next(ids: ids, now: now)
        return currentID != nil
    }

    func canGoBack(ids: Set<String>?) -> Bool {
        guard let ids else { return canGoBack }
        return history.prefix(cursor).contains(where: { ids.contains($0) })
    }

    mutating func previous(now: Date, ids: Set<String>? = nil) {
        if let ids {
            if let index = history.prefix(cursor).lastIndex(where: { ids.contains($0) }) { cursor = index }
        } else if canGoBack { cursor -= 1 }
        nextAutomaticAt = now.addingTimeInterval(ReviewSchedule.automaticInterval)
    }

    mutating func next(ids: [String], now: Date) {
        guard !ids.isEmpty else { return }
        let valid = Set(ids)
        if let index = history.indices.dropFirst(cursor + 1).first(where: { valid.contains(history[$0]) }) {
            cursor = index
            nextAutomaticAt = now.addingTimeInterval(ReviewSchedule.automaticInterval)
            return
        }
        advances += 1
        let due = reviews.values.filter {
            $0.graded != true && valid.contains($0.id) && $0.id != currentID && ($0.dueStep <= advances || $0.dueDate <= now)
        }.min { $0.precedes($1) }
        let id: String
        if var review = due {
            id = review.id
            review.stage = min(review.stage + 1, ReviewSchedule.steps.count - 1)
            review.dueStep = advances + ReviewSchedule.steps[review.stage]
            review.dueDate = now.addingTimeInterval(ReviewSchedule.hours[review.stage] * 3600)
            reviews[id] = review
        } else {
            bag.removeAll { !valid.contains($0) }
            // Reviewed words have their own schedule, so keep them out of the random bag.
            bag.removeAll { reviews[$0] != nil }
            if bag.isEmpty { bag = ids.filter { reviews[$0] == nil }.shuffled() }
            if bag.isEmpty { bag = ids.shuffled() } // Even a fully marked deck never runs out.
            if bag.last == currentID, bag.count > 1 { bag.swapAt(0, bag.count - 1) }
            id = bag.removeLast()
        }
        history.append(id)
        if history.count > ReviewSchedule.historyLimit { history.removeFirst(history.count - ReviewSchedule.historyLimit) }
        cursor = history.count - 1
        seen.insert(id)
        nextAutomaticAt = now.addingTimeInterval(ReviewSchedule.automaticInterval)
    }

    mutating func remind(id: String, now: Date) {
        let fresh = Review(id: id, stage: 0, dueStep: advances + ReviewSchedule.steps[0],
                           dueDate: now.addingTimeInterval(ReviewSchedule.hours[0] * 3600))
        // Repeated clicks must not duplicate a review or postpone an earlier one.
        if let existing = reviews[id] {
            reviews[id] = Review(id: id, stage: 0, dueStep: min(existing.dueStep, fresh.dueStep),
                                 dueDate: min(existing.dueDate, fresh.dueDate), graded: existing.graded)
        } else { reviews[id] = fresh }
        bag.removeAll { $0 == id }
        nextAutomaticAt = now.addingTimeInterval(ReviewSchedule.automaticInterval)
    }

    /// Reject semantically corrupt JSON before it reaches array indexing or
    /// integer arithmetic. Preserve the file for recovery instead of resetting.
    func validate() throws {
        guard (1...2).contains(version), advances >= 0, advances <= ReviewSchedule.maximumCounter,
              history.isEmpty ? cursor == 0 : history.indices.contains(cursor),
              nextAutomaticAt.timeIntervalSinceReferenceDate.isFinite,
              reviews.allSatisfy({ key, review in
                  key == review.id && !key.isEmpty && ReviewSchedule.steps.indices.contains(review.stage)
                  && review.dueStep >= 0 && review.dueStep <= ReviewSchedule.maximumCounter
                  && review.dueDate.timeIntervalSinceReferenceDate.isFinite
              }), (recallHistory?.isValid ?? true), (dailyReminder?.isValid ?? true),
              (dailyGoal.map { (1...100).contains($0) } ?? true),
              (practice.map { !$0.cardID.isEmpty } ?? true) else {
            throw WortagError.message("Saved progress has an unsupported version or invalid history/review schedule. It has been preserved.")
        }
    }
}
