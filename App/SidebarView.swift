import SwiftUI

struct SidebarView: View {
    @Binding var section: LibrarySection
    let snapshot: LearningSnapshot?
    let showSetup: () -> Void
    @FocusState private var focusedSection: LibrarySection?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "leaf.fill").font(.system(size: 26)).foregroundStyle(WortagTheme.accent)
                Text("Wortag").font(.system(size: 29, weight: .medium, design: .serif))
                Text("A LITTLE GERMAN, EVERY DAY").font(.system(size: 8, weight: .bold)).tracking(1.1)
                    .foregroundStyle(WortagTheme.muted)
            }.padding(.top, 36)
            VStack(spacing: 8) {
                ForEach(LibrarySection.allCases) { item in
                    Button { section = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon).frame(width: 20)
                            Text(item.rawValue).font(.system(size: 13, weight: section == item ? .semibold : .regular))
                            Spacer()
                            if item == .reminders, let count = snapshot?.reviewCount, count > 0 {
                                Text("\(count)").font(.caption2).foregroundStyle(WortagTheme.muted)
                            }
                        }.padding(12)
                            .background(section == item ? WortagTheme.paper : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                                focusedSection == item ? WortagTheme.accent : .clear, lineWidth: 1))
                    }.buttonStyle(.plain).focusEffectDisabled().focused($focusedSection, equals: item)
                }
            }
            Spacer()
            if let snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    Text(snapshot.seenCount.formatted()).font(.system(size: 28, weight: .light, design: .serif))
                    Text("of \(snapshot.wordCount.formatted()) words explored").font(.system(size: 11)).foregroundStyle(WortagTheme.muted)
                    ProgressView(value: Double(snapshot.seenCount), total: Double(max(1, snapshot.wordCount))).tint(WortagTheme.accent)
                }
            }
            Button(action: showSetup) { Label("Add your widget", systemImage: "square.grid.2x2") }
                .font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(WortagTheme.accent)
            Text("OFFLINE · MADE FOR YOUR MAC").font(.system(size: 8, weight: .medium)).tracking(0.5).foregroundStyle(WortagTheme.muted)
        }.padding(26).frame(width: 215).frame(maxHeight: .infinity)
            .background(WortagTheme.sage.opacity(0.6))
    }
}
