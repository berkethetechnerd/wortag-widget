import SwiftUI
import WidgetKit

struct PracticeWidgetView: View {
    let snapshot: LearningSnapshot
    let family: WidgetFamily
    let margins: EdgeInsets
    var renderingMode: WidgetRenderingMode = .fullColor
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var gap: CGFloat { small ? 4 : 8 }
    private var ink: Color { renderingMode == .fullColor ? WortagTheme.ink : .primary }

    var body: some View {
        VStack(spacing: 0) {
            WidgetRefreshSpace(height: margins.top)
            HStack(spacing: 0) {
                WidgetRefreshSpace(width: margins.leading, height: nil)
                content
                WidgetRefreshSpace(width: margins.trailing, height: nil)
            }
            WidgetRefreshSpace(height: margins.bottom)
        }.buttonStyle(.bordered).controlSize(.mini).foregroundStyle(ink)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button(intent: RefreshWordIntent()) {
                    Text("WORTAG · PRACTICE").font(.system(size: 8, weight: .bold)).tracking(0.5)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }.buttonStyle(.plain).layoutPriority(1).accessibilityLabel("Refresh practice question")
                WidgetRefreshSpace(height: 12)
                Button(intent: BrowseWidgetIntent()) { Image(systemName: "leaf") }
                    .accessibilityLabel("Return to discovery").help("Return to discovery")
            }.foregroundStyle(renderingMode == .fullColor ? WortagTheme.muted : .secondary)
            WidgetRefreshSpace(height: gap)
            if let challenge = snapshot.state.practice, let card = snapshot.practiceCard {
                Button(intent: RefreshWordIntent()) {
                    VStack(alignment: .leading, spacing: gap) {
                        Text(card.recallClue).font(.system(size: small ? 10 : (large ? 16 : 12)))
                            .lineLimit(small ? 3 : (large ? 5 : 2)).minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        if challenge.revealed {
                            Text(card.displayWord).font(.system(size: small ? 14 : (large ? 26 : 20), design: .serif))
                                .lineLimit(small ? 2 : 1).minimumScaleFactor(0.5)
                            if large, let example = card.examples.first {
                                Text(highlighted(example.german, word: card.word,
                                    accent: renderingMode == .fullColor ? WortagTheme.accent : nil))
                                    .font(.system(size: 13)).lineLimit(3)
                            }
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(challenge.revealed ? "\(card.recallClue). \(card.displayWord)" : card.recallClue)
                    .accessibilityHint("Refresh practice question in place")
                WidgetRefreshSpace(height: gap)
                if challenge.revealed {
                    if small {
                        gradeRow([.again, .hard], token: challenge.id)
                        WidgetRefreshSpace(height: 3)
                        gradeRow([.good, .easy], token: challenge.id)
                    } else { gradeRow(RecallGrade.allCases, token: challenge.id) }
                } else {
                    Button(intent: RevealPracticeIntent(challenge.id)) { Text("Reveal answer").frame(maxWidth: .infinity) }
                        .tint(ink)
                }
            } else {
                Button(intent: RefreshWordIntent()) {
                    VStack(alignment: .leading, spacing: gap) {
                        Text("No reviews due").font(.system(size: small ? 14 : 22, design: .serif))
                        Text("Scheduled words return when due.").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("No reviews due. Scheduled words return when due.")
                    .accessibilityHint("Refresh practice question in place")
                WidgetRefreshSpace(height: gap)
                Button(intent: StartPracticeIntent()) { Text("Check for words").frame(maxWidth: .infinity) }
            }
        }
    }

    private func gradeRow(_ grades: [RecallGrade], token: UUID) -> some View {
        HStack(spacing: 0) {
            ForEach(grades) { grade in
                if grade != grades.first { WidgetRefreshSpace(width: small ? 4 : 8, height: small ? 13 : 20) }
                Button(intent: GradePracticeIntent(token, grade)) {
                    Text(grade.rawValue).font(.system(size: small ? 9 : 11)).frame(maxWidth: .infinity)
                }.tint(grade == .again && renderingMode == .fullColor ? WortagTheme.accent : ink)
                    .accessibilityLabel("Rate recall: \(grade.rawValue)")
            }
        }
    }
}
