import SwiftUI
import WidgetKit
import OSLog

struct WordEntry: TimelineEntry {
    let date: Date
    let snapshot: LearningSnapshot?
    let error: String?
}

struct WordProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordEntry {
        let card = WordCard(id: "genehmigung", word: "Genehmigung", examples: [
            Example(german: "Für den Umbau brauchen wir eine Genehmigung.", english: "We need a permit for the renovation.", attribution: "Wortag preview"),
            Example(german: "Die Genehmigung gilt bis zum Ende des Jahres.", english: "The permit is valid until the end of the year.", attribution: "Wortag preview")
        ], nounForms: [NounForm(article: "die", word: "Genehmigung")])
        let count = (try? Vocabulary())?.cards.count ?? 0
        return WordEntry(date: .now, snapshot: LearningSnapshot(card: card, state: LearningState(), wordCount: count), error: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(rotate: false))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WordEntry>) -> Void) {
        let current = entry(rotate: true)
        let next = WidgetRefreshPolicy.nextDate(for: current.snapshot, now: Date())
        completion(Timeline(entries: [current], policy: current.snapshot?.state.automaticRotation == false ? .never : .after(next)))
    }
    private func entry(rotate: Bool) -> WordEntry {
        let logger = Logger(subsystem: "de.wortag.app", category: "widget")
        do {
            let snapshot = try LearningStore().snapshot(rotateIfDue: rotate)
            logger.notice("Successfully loaded a Wortag widget timeline from local progress storage.")
            return WordEntry(date: .now, snapshot: snapshot, error: nil)
        } catch {
            logger.error("Could not load Wortag widget progress: \(error.localizedDescription, privacy: .public)")
            return WordEntry(date: .now, snapshot: nil, error: error.localizedDescription)
        }
    }
}

struct WortagWidgetView: View {
    let entry: WordEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var contentMargins
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        WortagCardView(entry: entry, family: family, contentMargins: contentMargins, renderingMode: renderingMode)
            .containerBackground(WortagTheme.paper, for: .widget)
    }
}

struct WortagCardView: View {
    let entry: WordEntry
    let family: WidgetFamily
    let contentMargins: EdgeInsets
    var renderingMode: WidgetRenderingMode = .fullColor
    private var ink: Color { renderingMode == .fullColor ? WortagTheme.ink : .primary }
    private var muted: Color { renderingMode == .fullColor ? WortagTheme.muted : .secondary }
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if snapshot.state.practiceInWidget == true {
                    PracticeWidgetView(snapshot: snapshot, family: family, margins: contentMargins, renderingMode: renderingMode)
                } else {
                    let marked = snapshot.state.reviews[snapshot.card.id] != nil
                    VStack(alignment: .leading, spacing: 0) {
                        // The visible reading area is the refresh button's label.
                        // Keep controls in separate rows; overlapping full-size
                        // buttons can obscure content in WidgetKit's archived view.
                        Button(intent: RefreshWordIntent()) {
                            readingContent(snapshot, marked: marked)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .padding(.top, contentMargins.top)
                                .padding(.leading, contentMargins.leading)
                                .padding(.trailing, contentMargins.trailing)
                                .padding(.bottom, large ? 8 : 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Refresh this card without opening Wortag")

                        navigation(snapshot, marked: marked)
                        refreshSpace(height: large ? 8 : contentMargins.bottom)
                        if large {
                            HStack(spacing: 0) {
                                Button(intent: RefreshWordIntent()) {
                                    Text("\(snapshot.seenCount.formatted()) explored · \(snapshot.wordCount.formatted()) words")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, contentMargins.leading)
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                if let url = snapshot.card.pronunciationURL {
                                    Link("Listen ↗", destination: url).buttonStyle(.plain).padding(.trailing, 10)
                                }
                                if let sourceURL = snapshot.card.examples.first?.sourceURL {
                                    Link(destination: sourceURL) {
                                        Text("Examples ↗").padding(.trailing, contentMargins.trailing)
                                    }.buttonStyle(.plain)
                                } else {
                                    Button(intent: RefreshWordIntent()) {
                                        Text("Wortag examples").padding(.trailing, contentMargins.trailing)
                                    }.buttonStyle(.plain)
                                }
                            }.font(.system(size: 9)).foregroundStyle(muted)
                            refreshSpace(height: contentMargins.bottom)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Wortag", systemImage: "leaf.fill").font(.headline)
                    Text(entry.error ?? "Open Wortag to begin.").font(.caption)
                        .lineLimit(small ? 3 : 5)
                    Link("Open Wortag", destination: URL(string: "wortag://today")!)
                        .buttonStyle(.plain)
                }.padding(contentMargins)
            }
        }
        .foregroundStyle(ink)
    }

    private func readingContent(_ snapshot: LearningSnapshot, marked: Bool) -> some View {
        VStack(alignment: .leading, spacing: large ? 8 : 4) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "leaf.fill").accessibilityHidden(true)
                    Text("WORTAG").tracking(1.5)
                }.font(.system(size: 9, weight: .bold, design: .rounded)).fixedSize()
                Spacer()
                if marked { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10)).accessibilityLabel("Scheduled for review") }
            }.foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.card.displayWord)
                    .font(.system(size: small ? 20 : (large ? 30 : 24), weight: .medium, design: .serif))
                    .minimumScaleFactor(small ? 0.45 : 0.6).lineLimit(small ? 2 : 1)
                if let note = snapshot.card.exampleFormNote {
                    Text(note).font(.system(size: small ? 8 : 9)).foregroundStyle(muted).lineLimit(1)
                }
            }.invalidatableContent()

            // Bound the reading area explicitly. Nested fitting views inside
            // intent button labels can disappear in native rendering.
            examples(snapshot, count: small ? 1 : (large && !snapshot.state.showTranslations ? 3 : 2))
                .frame(maxWidth: .infinity, alignment: .topLeading).invalidatableContent()
        }
    }

    private func examples(_ snapshot: LearningSnapshot, count: Int) -> some View {
        VStack(alignment: .leading, spacing: large ? 12 : 5) {
            ForEach(Array(snapshot.card.examples.prefix(count).enumerated()), id: \.offset) { _, example in
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlighted(example.german, word: snapshot.card.word,
                                     accent: renderingMode == .fullColor ? WortagTheme.accent : nil))
                        .font(.system(size: small ? 10 : (large ? 15 : 11)))
                        .lineLimit(small ? 3 : (large ? 3 : 2))
                        .minimumScaleFactor(0.85)
                    if large && snapshot.state.showTranslations && !example.english.isEmpty {
                        Text(example.english).font(.system(size: 12)).foregroundStyle(muted).lineLimit(2)
                    }
                }
            }
        }
    }

    private func navigation(_ snapshot: LearningSnapshot, marked: Bool) -> some View {
        HStack(spacing: 0) {
            refreshSpace(width: contentMargins.leading)
            Button(intent: PreviousWordIntent()) { Image(systemName: "chevron.left") }
                .disabled(!snapshot.canGoBack).accessibilityLabel("Previous word").help("Previous word")
            refreshSpace(width: small ? 6 : 10)
            Button(intent: RemindWordIntent(wordID: snapshot.card.id)) {
                if small { Image(systemName: marked ? "bookmark.fill" : "bookmark") }
                else { Label(marked ? "Scheduled" : "Remind me", systemImage: marked ? "bookmark.fill" : "bookmark") }
            }
            .accessibilityLabel("Remind me").help("Repeat after 4 learning steps or about an hour, then at longer intervals")
            .tint(renderingMode == .fullColor ? WortagTheme.accent : ink)
            refreshSpace()
            Button(intent: NextWordIntent()) { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next word").help("Next word")
            refreshSpace(width: contentMargins.trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .buttonStyle(.bordered).controlSize(.mini)
    }

    private func refreshSpace(width: CGFloat? = nil, height: CGFloat = 20) -> some View {
        WidgetRefreshSpace(width: width, height: height)
    }
}

struct WidgetRefreshSpace: View {
    var width: CGFloat? = nil
    var height: CGFloat? = 20
    var body: some View {
        Button(intent: RefreshWordIntent()) {
            Color.clear.frame(width: width, height: height)
                .frame(maxWidth: width == nil ? .infinity : nil,
                       maxHeight: height == nil ? .infinity : nil)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityHidden(true)
    }
}

#if !WORTAG_RENDER
@main
struct WortagWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LearningStore.widgetKind, provider: WordProvider()) { entry in
            WortagWidgetView(entry: entry)
        }
        .configurationDisplayName("Wortag")
        .description("A little German, every day. Explore words and bring them back with spaced repetition.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
#endif
