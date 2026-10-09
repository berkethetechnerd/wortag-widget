import AppKit
import SwiftUI
import WidgetKit

/// Render the production card view without launching the app or altering progress.
/// Compile with -D WORTAG_RENDER plus Widget/ and Shared/ sources.
@main
struct RenderWidget {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 3,
              let bundle = Bundle(path: CommandLine.arguments[1]) else {
            fatalError("Usage: render-widget /path/to/Wortag.app /output/directory")
        }
        let vocabulary = try Vocabulary(bundle: bundle)
        guard let card = vocabulary["genehmigung"] else { fatalError("Missing sample noun") }
        let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var state = LearningState()
        state.history = ["mietvertrag", "genehmigung"]
        state.cursor = 1
        let sizes: [(String, WidgetFamily, CGFloat, CGFloat)] = [
            ("small", .systemSmall, 164, 164),
            ("medium", .systemMedium, 344, 164),
            ("large", .systemLarge, 344, 344)
        ]
        let cases: [(String, WordCard, Bool, WidgetRenderingMode, ColorScheme, EdgeInsets)] = [
            ("", card, false, .fullColor, .light, EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)),
            ("-long-word", vocabulary["selbstverständlichkeit"]!, true, .fullColor, .light,
             EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)),
            ("-translated", vocabulary["senkung"]!, true, .fullColor, .light,
             EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)),
            ("-vibrant-dark", vocabulary["senkung"]!, true, .vibrant, .dark,
             EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 12)),
            ("-accented", card, true, .accented, .light,
             EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 20))
        ]
        for (suffix, sample, translated, mode, scheme, margins) in cases {
            for (size, family, width, height) in sizes {
                let name = size + suffix
                var fixtureState = state
                fixtureState.showTranslations = translated
                fixtureState.remind(id: sample.id, now: .now)
                let entry = WordEntry(date: .now, snapshot: LearningSnapshot(card: sample, state: fixtureState,
                                     wordCount: vocabulary.cards.count), error: nil)
                let view = WortagCardView(entry: entry, family: family,
                                         contentMargins: margins, renderingMode: mode)
                    .frame(width: width, height: height)
                    .background(scheme == .dark ? Color(white: 0.15) : WortagTheme.paper)
                    .environment(\.colorScheme, scheme)
                try save(view, name: name, size: CGSize(width: width, height: height),
                         scheme: scheme, scale: scheme == .dark ? 1 : 2, to: folder)
            }
        }
        for revealed in [false, true] {
            for (name, family, width, height) in sizes {
                for (suffix, mode, scheme) in [("", WidgetRenderingMode.fullColor, ColorScheme.light),
                                                ("-accented", .accented, .light), ("-vibrant", .vibrant, .dark)] {
                    var fixture = state
                    fixture.practiceInWidget = true
                    let sample = vocabulary["selbstverständlichkeit"]!
                    fixture.practice = PracticeChallenge(id: UUID(), cardID: sample.id, revealed: revealed)
                    let entry = WordEntry(date: .now, snapshot: LearningSnapshot(card: sample, state: fixture,
                        wordCount: vocabulary.cards.count, practiceCard: sample), error: nil)
                    let view = WortagCardView(entry: entry, family: family,
                        contentMargins: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16), renderingMode: mode)
                        .frame(width: width, height: height)
                        .background(scheme == .dark ? Color(white: 0.15) : WortagTheme.paper)
                        .environment(\.colorScheme, scheme)
                    try save(view, name: name + (revealed ? "-practice-revealed" : "-practice-hidden") + suffix,
                        size: CGSize(width: width, height: height), scheme: scheme, scale: 2, to: folder)
                }
            }
        }
        for (name, family, width, height) in sizes {
            let entry = WordEntry(date: .now, snapshot: nil,
                                  error: "Saved progress could not be read. It has been preserved. Open Wortag to check the learning folder and try again.")
            let view = WortagCardView(entry: entry, family: family,
                contentMargins: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                .frame(width: width, height: height).background(WortagTheme.paper)
            try save(view, name: name + "-error", size: CGSize(width: width, height: height),
                     scheme: .light, scale: 2, to: folder)
        }
    }

    @MainActor private static func save<V: View>(_ view: V, name: String, size: CGSize,
                                                scheme: ColorScheme, scale: CGFloat, to folder: URL) throws {
        let bitmap = NativePreview.bitmap(view, size: size, scheme: scheme, scale: scale)
        // A valid PNG can still contain only the background or navigation.
        // Fail CI if the reading region disappears during native layout.
        guard let background = bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.deviceRGB) else {
            fatalError("Could not inspect \(name) widget")
        }
        var visible = 0, samples = 0
        for y in stride(from: 0, to: bitmap.pixelsHigh * 3 / 4, by: 4) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: 4) {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                samples += 1
                if abs(color.redComponent - background.redComponent)
                    + abs(color.greenComponent - background.greenComponent)
                    + abs(color.blueComponent - background.blueComponent) > 0.15 { visible += 1 }
            }
        }
        guard visible > samples / 200, let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("The \(name) widget has an empty reading area or could not be encoded")
        }
        try png.write(to: folder.appendingPathComponent("wortag-\(name).png"))
        print("Rendered \(name) widget: \(bitmap.pixelsWide) × \(bitmap.pixelsHigh)")
    }
}
