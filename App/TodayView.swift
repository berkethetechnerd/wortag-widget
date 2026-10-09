import SwiftUI

struct TodayView: View {
    let snapshot: LearningSnapshot
    let onAction: (LearningAction) -> Void
    var practice: () -> Void = {}
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("YOUR WORD, RIGHT NOW").font(.system(size: 10, weight: .semibold)).tracking(2)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(context.date, format: .dateTime.day().month(.wide)).font(.system(size: 12))
                    }.fixedSize()
                }.foregroundStyle(WortagTheme.muted)
                WordDetailsView(card: snapshot.card, showTranslations: snapshot.state.showTranslations)
                HStack(spacing: 12) {
                    Button { onAction(.previous) } label: { Label("Previous", systemImage: "chevron.left") }
                        .disabled(!snapshot.canGoBack)
                    Button { onAction(.remind(snapshot.card.id)) } label: {
                        Label(snapshot.state.reviews[snapshot.card.id] == nil ? "Remind me" : "Scheduled", systemImage: "bookmark")
                    }.tint(WortagTheme.accent)
                    Spacer()
                    Button { onAction(.next) } label: { Label("Next", systemImage: "chevron.right") }
                        .buttonStyle(.borderedProminent).tint(WortagTheme.ink)
                }.controlSize(.large)
                if let review = snapshot.state.reviews[snapshot.card.id] {
                    Label("Back within \(max(0, review.dueStep - snapshot.state.advances)) learning steps, or \(review.dueDate.formatted(.relative(presentation: .named))).", systemImage: "arrow.clockwise")
                        .font(.system(size: 12)).foregroundStyle(WortagTheme.accent)
                }
                Button("Practice this word", action: practice).buttonStyle(.bordered)
                Divider().overlay(WortagTheme.sage)
                Toggle("Show English translations", isOn: Binding(get: { snapshot.state.showTranslations }, set: { onAction(.translations($0)) }))
                Toggle("Refresh the widget about once an hour", isOn: Binding(get: { snapshot.state.automaticRotation }, set: { onAction(.rotation($0)) }))
                Text("Remind me brings a word back after 4 learning steps or an hour. Later reviews are spaced further apart. macOS controls automatic widget refresh timing.")
                    .font(.system(size: 11)).foregroundStyle(WortagTheme.muted).lineSpacing(3)
            }.frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 32).padding(.top, 48).padding(.bottom, 28)
                .frame(maxWidth: .infinity)
        }
    }
}
