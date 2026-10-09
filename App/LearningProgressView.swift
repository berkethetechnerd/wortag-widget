import SwiftUI

struct LearningProgressView: View {
    let snapshot: LearningSnapshot
    let cards: [WordCard]
    let onAction: (LearningAction) -> Void
    let practice: (String?) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let summary = ProgressSummary(state: snapshot.state, cards: cards, now: context.date)
            let goal = snapshot.state.dailyGoal ?? 10
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Progress").font(.system(size: 34, design: .serif))
                    Text("Graded answers measure practice. Exploring words and automatic widget refreshes are counted separately.")
                        .font(.system(size: 13)).foregroundStyle(WortagTheme.muted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metric("Reviews today", "\(summary.today.reviews)")
                        metric("Total graded reviews", "\(summary.totalReviews.formatted())")
                        metric("Self-rated recall", summary.recallRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                        metric("Words explored", "\(snapshot.seenCount.formatted()) / \(snapshot.wordCount.formatted())")
                    }
                    Text("Self-rated recall includes Hard, Good and Easy; it is your own assessment, not a spelling-test score.")
                        .font(.system(size: 11)).foregroundStyle(WortagTheme.muted)
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("Daily goal: \(goal) graded reviews", value: Binding(
                            get: { goal }, set: { onAction(.dailyGoal($0)) }), in: 1...100)
                        ProgressView(value: Double(min(goal, summary.today.reviews)), total: Double(goal))
                            .tint(WortagTheme.accent)
                        Text(summary.today.reviews >= goal ? "Today’s goal reached." : "\(goal - summary.today.reviews) reviews to reach today’s goal.")
                            .font(.caption).foregroundStyle(WortagTheme.muted)
                        Button("Practice · \(summary.dueReviews) words due") { practice(nil) }
                            .buttonStyle(.borderedProminent).tint(WortagTheme.ink)
                    }
                    Text("LAST SEVEN DAYS").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(WortagTheme.muted)
                    ActivityChartView(days: summary.week)
                    if !summary.difficultWords.isEmpty {
                        Text("WORDS TO REVISIT").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(WortagTheme.muted)
                        Text("Again or Hard ratings in your most recent 100 answers.").font(.caption).foregroundStyle(WortagTheme.muted)
                        ForEach(summary.difficultWords) { word in
                            Button { practice(word.card.id) } label: {
                                HStack {
                                    Text(word.card.displayWord).font(.system(size: 17, design: .serif))
                                    Spacer()
                                    Text("\(word.difficultRatings) difficult ratings").font(.caption)
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).foregroundStyle(WortagTheme.ink)
                        }
                    }
                    if summary.totalReviews == 0 {
                        Text("Your first graded answer will start these statistics. Your existing explored-word count is preserved.")
                            .font(.system(size: 12)).foregroundStyle(WortagTheme.muted)
                    }
                }.frame(maxWidth: 760, alignment: .leading).padding(.horizontal, 32)
                    .padding(.top, 48).padding(.bottom, 28).frame(maxWidth: .infinity)
            }
        }
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.system(size: 25, design: .serif)).lineLimit(1).minimumScaleFactor(0.6)
            Text(title).font(.system(size: 11)).foregroundStyle(WortagTheme.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(WortagTheme.sage.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}
