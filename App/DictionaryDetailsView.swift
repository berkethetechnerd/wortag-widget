import SwiftUI

struct DictionaryDetailsView: View {
    let card: WordCard
    var body: some View {
        if let info = card.dictionary {
            VStack(alignment: .leading, spacing: 12) {
                Text(info.partOfSpeech == "noun" ? "NOUN · MEANING & FORMS" : "VERB · MEANING & FORMS")
                    .font(.system(size: 9, weight: .bold)).tracking(1.5).foregroundStyle(WortagTheme.muted)
                ForEach(Array(info.meanings.enumerated()), id: \.offset) { _, meaning in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meaning.definition).font(.system(size: 14)).textSelection(.enabled)
                        if !meaning.english.isEmpty {
                            Text(meaning.english.joined(separator: ", "))
                                .font(.system(size: 12)).foregroundStyle(WortagTheme.muted).textSelection(.enabled)
                        }
                    }
                }
                if info.partOfSpeech == "noun" {
                    let plurals = info.plurals ?? []
                    form("Plural", plurals.isEmpty ? "Not recorded in this dictionary entry" : "die " + plurals.joined(separator: " / die "))
                } else {
                    form("Present (er/sie/es)", info.present)
                    form("Past (ich)", info.past)
                    form("Participle", info.participle)
                    form("Perfect auxiliary", info.auxiliary)
                }
                ForEach(info.usage, id: \.self) { Text($0).font(.system(size: 12, weight: .medium)).foregroundStyle(WortagTheme.accent) }
                if let url = card.dictionaryURL {
                    Link("Wiktionary · dictionary & credit ↗", destination: url)
                        .font(.system(size: 10)).foregroundStyle(WortagTheme.muted)
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(WortagTheme.sage.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
        }
    }
    @ViewBuilder private func form(_ label: String, _ value: String?) -> some View {
        if let value {
            Text("\(label): \(value)").font(.system(size: 12)).textSelection(.enabled)
        }
    }
}
