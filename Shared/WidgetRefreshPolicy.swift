import Foundation

/// Practice refreshes must not rotate an unanswered question or repeatedly
/// request updates against a stale discovery deadline.
enum WidgetRefreshPolicy {
    static func nextDate(for snapshot: LearningSnapshot?, now: Date) -> Date {
        guard let snapshot else { return now.addingTimeInterval(300) }
        let earliest = now.addingTimeInterval(60)
        if snapshot.state.practiceInWidget == true {
            let due: Date? = snapshot.state.practice == nil ? snapshot.state.reviews.values
                .filter { snapshot.activeIDs?.contains($0.id) ?? true }
                .map(\.dueDate).min() : nil
            return max(earliest, due ?? now.addingTimeInterval(ReviewSchedule.automaticInterval))
        }
        return max(earliest, snapshot.state.nextAutomaticAt)
    }
}
