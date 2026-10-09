import Foundation

struct DailyReminder: Codable, Equatable {
    var enabled = false
    var hour = 9
    var minute = 0
    var weekdays: Set<Int> = Set(1...7)
    var isValid: Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
        && weekdays.isSubset(of: Set(1...7)) && (!enabled || !weekdays.isEmpty)
    }
    var requestIDs: [String] { enabled ? weekdays.sorted().map { "wortag.daily.\($0)" } : [] }
}
