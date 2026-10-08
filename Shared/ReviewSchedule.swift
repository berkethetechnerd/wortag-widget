import Foundation

/// The learning policy lives here, independently of storage and presentation.
enum ReviewSchedule {
    static let steps = [4, 12, 36, 108, 324, 972]
    static let hours: [Double] = [1, 24, 72, 168, 504, 1440]
    static let automaticInterval: TimeInterval = 3600
    static let historyLimit = 5000
    static let maximumCounter = Int.max - steps.last! - 1
}

extension Review {
    func precedes(_ other: Review) -> Bool {
        if dueStep != other.dueStep { return dueStep < other.dueStep }
        if dueDate != other.dueDate { return dueDate < other.dueDate }
        return id < other.id
    }
}
