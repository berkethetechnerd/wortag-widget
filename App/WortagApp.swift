import SwiftUI
import WidgetKit

#if !WORTAG_RENDER_APP
@main
struct WortagApp: App {
    @StateObject private var model = AppModel(reloadWidgets: { WidgetCenter.shared.reloadTimelines(ofKind: LearningStore.widgetKind) })
    var body: some Scene {
        WindowGroup("Wortag") {
            ContentView().environmentObject(model)
                .preferredColorScheme(.light)
                .frame(minWidth: 780, minHeight: 590)
        }
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
