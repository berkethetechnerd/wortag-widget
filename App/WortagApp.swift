import SwiftUI
import WidgetKit

#if !WORTAG_RENDER_APP
@main
struct WortagApp: App {
    @StateObject private var model = AppModel(reloadWidgets: { WidgetCenter.shared.reloadTimelines(ofKind: LearningStore.widgetKind) })
    @StateObject private var speech = SpeechController()
    @StateObject private var reminders: ReminderModel
    init() {
        let scheduler = MacReminderScheduler()
        let reminderModel = ReminderModel(scheduler: scheduler)
        scheduler.onOpenPractice = { [weak reminderModel] in reminderModel?.requestPractice() }
        _reminders = StateObject(wrappedValue: reminderModel)
    }
    var body: some Scene {
        WindowGroup("Wortag", id: "WortagMain", for: String.self) { _ in
            ContentView().environmentObject(model).environmentObject(speech).environmentObject(reminders)
                .preferredColorScheme(.light)
                .frame(minWidth: 780, minHeight: 590)
        } defaultValue: { "main" }
        .defaultSize(width: 900, height: 690)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Next Word") { model.act(.next) }.keyboardShortcut(.rightArrow, modifiers: [.command, .option])
                    .disabled(model.snapshot == nil || model.error != nil)
                Button("Previous Word") { model.act(.previous) }.keyboardShortcut(.leftArrow, modifiers: [.command, .option])
                    .disabled(model.snapshot?.canGoBack != true || model.error != nil)
                Button("Remind Me") { if let id = model.snapshot?.card.id { model.act(.remind(id)) } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.snapshot == nil || model.error != nil)
            }
        }
    }
}
#endif
