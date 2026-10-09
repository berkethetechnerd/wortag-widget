// Render production app views with native controls, using fixtures only.
// Compile with -D WORTAG_RENDER_APP plus App/ and Shared/ sources.
import AppKit
import SwiftUI

@main
struct RenderApp {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3,
              let bundle = Bundle(path: CommandLine.arguments[1]) else {
            fatalError("Usage: render-app /path/to/Wortag.app /output/directory")
        }
        let vocabulary = try Vocabulary(bundle: bundle)
        let card = vocabulary["genehmigung"]!
        var state = LearningState()
        state.history = ["mietvertrag", "genehmigung"]
        state.cursor = 1
        state.seen = ["mietvertrag", "genehmigung"]
        let snapshot = LearningSnapshot(card: card, state: state, wordCount: vocabulary.cards.count,
                                        activeIDs: Set(vocabulary.cards.map(\.id)))
        let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let cases: [(String, String, String, CGFloat, CGFloat, Bool)] = [
            ("reminders", "Reminders", "", 900, 690, false),
            ("reminders-small", "Reminders", "", 780, 590, false),
            ("reminders-wide", "Reminders", "", 1200, 800, false),
            ("reminders-search", "Reminders", "zzzzzz", 900, 690, true),
            ("reminders-saved", "Reminders", "", 900, 690, true),
            ("reminders-detail", "Reminders", "", 900, 690, true),
            ("vocabulary-search", "Vocabulary", "zzzzzz", 900, 690, false),
            ("vocabulary-small", "Vocabulary", "", 780, 590, false),
            ("today-translated-small", "Today", "", 780, 590, false),
            ("today-wide", "Today", "", 1200, 800, false),
            ("reminders-long-word", "Reminders", "", 780, 590, true),
            ("practice-hidden", "Practice", "", 780, 590, false),
            ("practice-revealed", "Practice", "", 780, 590, false),
            ("practice-wide", "Practice", "", 1200, 800, false),
            ("progress-empty", "Progress", "", 780, 590, false),
            ("progress-populated", "Progress", "", 900, 690, true),
            ("settings-disabled", "Settings", "", 780, 590, false),
            ("settings-enabled", "Settings", "", 780, 590, false)
        ]
        for (name, tab, query, width, height, saved) in cases {
            var fixtureState = state
            if saved {
                for id in ["genehmigung", "mietvertrag", "werkzeug", "selbstverständlichkeit"] {
                    fixtureState.remind(id: id, now: .now)
                }
            }
            if name.hasPrefix("practice") {
                fixtureState.practice = PracticeChallenge(id: UUID(), cardID: "selbstverständlichkeit", revealed: name != "practice-hidden")
            }
            if name == "progress-populated" {
                var history = RecallHistory()
                for day in 0..<7 {
                    let date = Calendar.current.date(byAdding: .day, value: -day, to: .now)!
                    for index in 0..<(day + 1) {
                        history.record(RecallEvent(id: UUID(), cardID: "genehmigung", grade: index % 3 == 0 ? .again : .good, date: date))
                    }
                }
                fixtureState.recallHistory = history
            }
            if name == "settings-enabled" {
                var preference = DailyReminder(); preference.enabled = true; preference.hour = 18; preference.minute = 30
                preference.weekdays = [2, 3, 4, 5, 6]; fixtureState.dailyReminder = preference
            }
            fixtureState.showTranslations = name == "today-translated-small"
            let sample = fixtureState.showTranslations ? vocabulary["selbstverständlichkeit"]! : snapshot.card
            let fixture = LearningSnapshot(card: sample, state: fixtureState, wordCount: snapshot.wordCount, activeIDs: snapshot.activeIDs, practiceCard: fixtureState.practice.flatMap { vocabulary[$0.cardID] })
            let model = AppModel(previewSnapshot: fixture, cards: vocabulary.cards)
            let view = ContentView(initialTab: tab, initialQuery: query, initialSelection: name == "reminders-detail" ? card : nil)
                .environmentObject(model)
                .environmentObject(SpeechController(preview: true))
                .environmentObject(ReminderModel(scheduler: PreviewReminderScheduler()))
                .environment(\.colorScheme, .light)
                .frame(width: width, height: height)
            let bitmap = NativePreview.bitmap(view, size: CGSize(width: width, height: height))
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                fatalError("Could not encode \(name)")
            }
            try png.write(to: folder.appendingPathComponent("\(name).png"))
            print("Rendered \(name): \(bitmap.pixelsWide) × \(bitmap.pixelsHigh)")
        }
    }
}
