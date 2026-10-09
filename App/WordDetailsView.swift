import SwiftUI

struct WordDetailsView: View {
    @EnvironmentObject private var speech: SpeechController
    let card: WordCard
    var showTranslations = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.displayWord).font(.system(size: 48, weight: .regular, design: .serif)).textSelection(.enabled)
                    .minimumScaleFactor(0.6).lineLimit(2)
                if let note = card.exampleFormNote {
                    Text(note).font(.system(size: 12)).foregroundStyle(WortagTheme.muted)
                }
                if (card.nounForms?.count ?? 0) > 1 {
                    Text("Articles vary by meaning or region.").font(.system(size: 11)).foregroundStyle(WortagTheme.muted)
                }
            }
            PronunciationControls(text: card.displayWord)
            if let message = speech.message {
                Text(message).font(.caption).foregroundStyle(WortagTheme.accent)
            }
            DictionaryDetailsView(card: card)
            Text("IN EVERYDAY SENTENCES").font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(WortagTheme.muted)
            ForEach(Array(card.examples.enumerated()), id: \.offset) { index, example in
                HStack(alignment: .top, spacing: 16) {
                    Text(String(format: "%02d", index + 1)).font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(WortagTheme.muted).padding(.top, 5)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(highlighted(example.german, word: card.word)).font(.system(size: 17)).lineSpacing(4).textSelection(.enabled)
                        if showTranslations && !example.english.isEmpty {
                            Text(example.english).font(.system(size: 13)).foregroundStyle(WortagTheme.muted).textSelection(.enabled)
                        }
                        PronunciationControls(text: example.german, compact: true)
                        if let sourceURL = example.sourceURL {
                            Link("Tatoeba · source & credit ↗", destination: sourceURL)
                                .font(.system(size: 9)).foregroundStyle(WortagTheme.muted)
                                .help(example.attribution)
                        } else {
                            Text(example.attribution).font(.system(size: 9)).foregroundStyle(WortagTheme.muted)
                        }
                    }
                }
            }
        }
    }
}
