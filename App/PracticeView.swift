import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var speech: SpeechController
    let snapshot: LearningSnapshot
    let onAction: (LearningAction) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Practice").font(.system(size: 34, design: .serif))
                Text("Recall the German word and its article, then reveal the answer. Grade how well you remembered it.")
                    .font(.system(size: 13)).foregroundStyle(WortagTheme.muted)
                if let challenge = snapshot.state.practice, let card = snapshot.practiceCard {
                    Text("MEANING CLUE · GERMAN").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(WortagTheme.muted)
                    Text(card.recallClue).font(.system(size: 22, design: .serif)).textSelection(.enabled)
                    if challenge.revealed {
                        Text(card.displayWord).font(.system(size: 32, design: .serif))
                            .lineLimit(2).minimumScaleFactor(0.6).textSelection(.enabled)
                        PronunciationControls(text: card.displayWord)
                        if let message = speech.message {
                            Text(message).font(.caption).foregroundStyle(WortagTheme.accent)
                        }
                        Text("How well did you recall this word?").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(RecallGrade.allCases) { grade in
                                Button { onAction(.grade(challenge.id, grade)) } label: {
                                    VStack(spacing: 4) {
                                        Text(grade.rawValue).font(.headline)
                                        Text(explanation(grade)).font(.caption)
                                    }.frame(maxWidth: .infinity).padding(.vertical, 6)
                                }.buttonStyle(.bordered).tint(grade == .again ? WortagTheme.accent : WortagTheme.ink)
                            }
                        }
                        DisclosureGroup("Meaning, forms and example sentences") {
                            WordDetailsView(card: card, showTranslations: snapshot.state.showTranslations).padding(.top, 16)
                        }.font(.system(size: 13)).tint(WortagTheme.accent)
                    } else {
                        Button("Reveal answer") { onAction(.reveal(challenge.id)) }
                            .buttonStyle(.borderedProminent).tint(WortagTheme.ink).controlSize(.large)
                    }
                } else {
                    ContentUnavailableView("No reviews due", systemImage: "checkmark.circle",
                                           description: Text("You have reviewed every available word. Scheduled words will return when due."))
                    Button("Check for practice words") { onAction(.practice(nil)) }
                }
                Divider()
                Toggle("Use Practice mode in the widget", isOn: Binding(
                    get: { snapshot.state.practiceInWidget == true }, set: { onAction(.widgetPractice($0)) }))
                Text("Due words come first. Opening or revealing a question does not count as a review. Again brings a word back sooner; Good and Easy lengthen its interval. Browsing remains available in Today.")
                    .font(.system(size: 11)).foregroundStyle(WortagTheme.muted).lineSpacing(3)
            }.frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 32).padding(.top, 48).padding(.bottom, 28)
                .frame(maxWidth: .infinity)
        }
    }
    private func explanation(_ grade: RecallGrade) -> String {
        switch grade {
        case .again: return "Did not recall"
        case .hard: return "Recalled with difficulty"
        case .good: return "Recalled correctly"
        case .easy: return "Immediate recall"
        }
    }
}
