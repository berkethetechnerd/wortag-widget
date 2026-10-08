import SwiftUI

struct LibraryView: View {
    let section: LibrarySection
    let cards: [WordCard]
    let snapshot: LearningSnapshot?
    @Binding var query: String
    @Binding var selected: WordCard?
    let onAction: (LearningAction) -> Void
    let showToday: () -> Void
    private var libraryCards: [WordCard] {
        section.cards(in: cards, reviews: snapshot?.state.reviews ?? [:])
    }
    private var filtered: [WordCard] { LibrarySection.search(libraryCards, query: query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(section.rawValue).font(.system(size: 32, design: .serif))
                Text(section == .reminders ? "Your saved words return at spaced intervals." : "Find a useful word to add to your day.")
                    .font(.system(size: 13)).foregroundStyle(WortagTheme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)

            if selected == nil && (section != .reminders || !libraryCards.isEmpty) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(WortagTheme.muted)
                    TextField(section == .reminders ? "Search saved words" : "Find a German word", text: $query)
                        .textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(WortagTheme.muted)
                            .accessibilityLabel("Clear search")
                    }
                }.font(.system(size: 13)).padding(12)
                    .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(WortagTheme.sage, lineWidth: 1))
            }
            if let selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Button { self.selected = nil } label: {
                            Label(section == .reminders ? "All reminders" : "All words", systemImage: "chevron.left")
                        }.buttonStyle(.plain).foregroundStyle(WortagTheme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 20)
                        WordDetailsView(card: selected, showTranslations: snapshot?.state.showTranslations == true)
                        HStack {
                            Spacer()
                            if snapshot?.state.reviews[selected.id] != nil {
                                Button("Stop reminding") { onAction(.unmark(selected.id)) }
                            } else {
                                Button("Remind me") { onAction(.remind(selected.id)) }
                            }
                        }.controlSize(.large).padding(.top, 24)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if filtered.isEmpty {
                libraryEmptyState
            } else {
                List(filtered) { card in
                    Button { selected = card } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(card.displayWord).font(.system(size: 17, design: .serif))
                                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right").font(.caption2)
                            }
                            if let review = snapshot?.state.reviews[card.id] {
                                Text("\(max(0, review.dueStep - (snapshot?.state.advances ?? 0))) cards / \(review.dueDate.formatted(.relative(presentation: .named)))")
                                    .font(.caption).foregroundStyle(WortagTheme.muted)
                            }
                        }.padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).listRowBackground(WortagTheme.paper)
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }
            if !libraryCards.isEmpty && selected == nil {
                HStack {
                    Text(section == .reminders
                         ? "\(libraryCards.count.formatted()) saved \(libraryCards.count == 1 ? "word" : "words")"
                         : "\(filtered.count.formatted()) of \(libraryCards.count.formatted()) words")
                    Spacer()
                    Text(section == .reminders ? "Longer intervals with each review" : "Examples from Tatoeba")
                }.font(.system(size: 10)).foregroundStyle(WortagTheme.muted)
            }
        }
        .padding(.top, 48).padding(.bottom, 28)
        .frame(maxWidth: 760, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var libraryEmptyState: some View {
        let noReminders = section == .reminders && libraryCards.isEmpty
        return VStack(spacing: 0) {
            Image(systemName: noReminders ? "bookmark" : "magnifyingglass")
                .font(.system(size: 27, weight: .light)).foregroundStyle(WortagTheme.accent)
                .frame(width: 68, height: 68)
                .background(WortagTheme.sage.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
                .padding(.bottom, 24)
            Text(noReminders ? "No reminders yet" : "No matching words")
                .font(.system(size: 26, weight: .regular, design: .serif))
                .fixedSize(horizontal: false, vertical: true).padding(.bottom, 12)
            Text(noReminders
                 ? "Use Remind me to save a word.\nIt will return at gradually longer intervals."
                 : "Try another word, or clear your search to see the full list.")
                .font(.system(size: 13)).foregroundStyle(WortagTheme.muted)
                .lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)
            Button(noReminders ? "Explore today’s word" : "Clear search") {
                query = ""
                if noReminders { showToday(); selected = nil }
            }.buttonStyle(.borderedProminent).tint(WortagTheme.ink).controlSize(.large)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 460)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

}
