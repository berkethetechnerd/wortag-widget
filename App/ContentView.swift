import SwiftUI
import Combine
import AppKit

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var reminders: ReminderModel
    @EnvironmentObject private var speech: SpeechController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
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
                    TodayView(snapshot: snapshot, onAction: { model.act($0) }, practice: {
                        model.act(.practice(snapshot.card.id)); section = .practice
                    })
                } else if section == .practice, let snapshot = model.snapshot {
                    PracticeView(snapshot: snapshot, onAction: { model.act($0) })
                } else if section == .progress, let snapshot = model.snapshot {
                    LearningProgressView(snapshot: snapshot, cards: model.cards, onAction: { model.act($0) }, practice: { id in
                        model.act(.practice(id)); section = .practice
                    })
                } else if section == .settings {
                    ReminderSettingsView(saved: model.snapshot?.state.dailyReminder ?? DailyReminder())
                } else {
                    LibraryView(section: section, cards: model.cards, snapshot: model.snapshot,
                                query: $query, selected: $selected, onAction: { model.act($0) },
                                showToday: { section = .today }, practice: { id in
                                    model.act(.practice(id)); section = .practice
                                })
                }
            }
        }
        .foregroundStyle(WortagTheme.ink).background(WortagTheme.paper)
        .onAppear {
            let open = openWindow
            reminders.showPracticeWindow = {
                open(id: "WortagMain", value: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
        .task {
            if model.error == nil, let snapshot = model.snapshot {
                await reminders.reconcile(snapshot.state.dailyReminder ?? DailyReminder())
            }
        }
        .onReceive(reminders.$openPractice) { requested in
            if requested { section = .practice; model.act(.practice(nil)); reminders.openPractice = false }
        }
        .onReceive(refreshTimer) { _ in
            if scenePhase == .active && model.error == nil { model.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active {
            model.refresh()
            if model.error == nil, let snapshot = model.snapshot {
                Task { await reminders.reconcile(snapshot.state.dailyReminder ?? DailyReminder(), force: true) }
            }
        } }
        .onChange(of: section) { _, current in
            selected = nil; query = ""
            if current == .practice { model.act(.practice(nil)) }
        }
        .onOpenURL { url in
            if url.scheme == "wortag", url.host == "speak" {
                if let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value,
                   let card = model.cards.first(where: { $0.id == id }) { speech.speak(card.displayWord) }
            } else if url.scheme == "wortag" {
                section = url.host == "practice" ? .practice : .today
                selected = nil; query = ""
                if section == .practice { model.act(.practice(nil)) }
            }
            model.refresh()
        }
        .handlesExternalEvents(preferring: ["wortag://"], allowing: ["wortag://"])
        .sheet(isPresented: $showSetup) { WidgetSetupView() }
    }
}
