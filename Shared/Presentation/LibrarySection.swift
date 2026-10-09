import Foundation

enum LibrarySection: String, CaseIterable, Identifiable {
    case today = "Today", vocabulary = "Vocabulary", reminders = "Reminders", practice = "Practice", progress = "Progress", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today: return "sun.max"
        case .vocabulary: return "text.book.closed"
        case .reminders: return "bookmark"
        case .practice: return "brain.head.profile"
        case .progress: return "chart.bar"
        case .settings: return "slider.horizontal.3"
        }
    }

    func cards(in vocabulary: [WordCard], reviews: [String: Review]) -> [WordCard] {
        if self == .reminders {
            return vocabulary.filter { reviews[$0.id] != nil }.sorted {
                reviews[$0.id]!.precedes(reviews[$1.id]!)
            }
        }
        return vocabulary.sorted { $0.word.localizedStandardCompare($1.word) == .orderedAscending }
    }

    static func search(_ cards: [WordCard], query: String) -> [WordCard] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? cards : cards.filter {
            $0.word.localizedStandardContains(query) || $0.displayWord.localizedStandardContains(query)
        }
    }
}
