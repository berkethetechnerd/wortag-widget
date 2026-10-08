import SwiftUI

struct WidgetSetupView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Label("Wortag on your desktop", systemImage: "square.grid.2x2").font(.system(size: 26, design: .serif))
            Text("1. Right-click your desktop and choose Edit Widgets.\n\n2. Search for Wortag.\n\n3. Drag a small, medium, or large widget onto your desktop.")
                .font(.system(size: 15)).lineSpacing(5)
            Text("The medium size is a good everyday choice. The large size adds a third example and optional English translations. All widgets share the same current word and learning progress.")
                .font(.system(size: 12)).foregroundStyle(WortagTheme.muted)
            HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(WortagTheme.ink) }
        }.padding(32).frame(width: 490).background(WortagTheme.paper).foregroundStyle(WortagTheme.ink)
    }
}
