import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var section: LibrarySection
    @State private var query: String
    @State private var selected: WordCard?
    @State private var showSetup = false
    private let refreshTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    init(initialTab: String = "Today", initialQuery: String = "", initialSelection: WordCard? = nil) {
        _section = State(initialValue: LibrarySection(rawValue: initialTab) ?? .today)
        _query = State(initialValue: initialQuery)
        _selected = State(initialValue: initialSelection)
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(section: $section, snapshot: model.snapshot, showSetup: { showSetup = true })
            Group {
                if let error = model.error {
                    VStack(spacing: 18) {
                        Image(systemName: "exclamationmark.circle").font(.largeTitle)
                        Text(error).multilineTextAlignment(.center)
                        Button("Try again") { model.refresh() }
                    }.padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if section == .today, let snapshot = model.snapshot {
                    TodayView(snapshot: snapshot, onAction: model.act)
                } else {
                    LibraryView(section: section, cards: model.cards, snapshot: model.snapshot,
                                query: $query, selected: $selected, onAction: model.act,
                                showToday: { section = .today })
                }
            }
        }
        .foregroundStyle(WortagTheme.ink).background(WortagTheme.paper)
        .onReceive(refreshTimer) { _ in
            if scenePhase == .active && model.error == nil { model.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.refresh() } }
        .onChange(of: section) { _, _ in selected = nil; query = "" }
        .onOpenURL { url in
            if url.scheme == "wortag", url.host == "today" { section = .today; selected = nil; query = "" }
            model.refresh()
        }
        .sheet(isPresented: $showSetup) { WidgetSetupView() }
    }
}
