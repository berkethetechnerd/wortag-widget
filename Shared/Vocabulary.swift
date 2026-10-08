import Foundation

struct Example: Codable, Hashable {
    let german: String
    let english: String
    let attribution: String

    var sourceURL: URL? {
        let ids = attribution.components(separatedBy: "#").dropFirst()
        let id = ids.last?.prefix(while: { $0.isNumber }) ?? ""
        guard !id.isEmpty else { return nil }
        return URL(string: "https://tatoeba.org/en/sentences/show/\(id)")
    }
}

struct NounForm: Codable, Hashable {
    let article: String
    let word: String
}

struct WordCard: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let examples: [Example]
    let nounForms: [NounForm]?
    let active: Bool?

    init(id: String, word: String, examples: [Example], nounForms: [NounForm]? = nil, active: Bool? = nil) {
        self.id = id
        self.word = word
        self.examples = examples
        self.nounForms = nounForms
        self.active = active
    }

    /// Keep the original surface word for sentence highlighting and saved IDs.
    /// Nouns use the nominative form with their definite article for learning.
    var displayWord: String {
        guard let forms = nounForms, !forms.isEmpty else { return word }
        var words: [String] = []
        for form in forms where !words.contains(form.word) { words.append(form.word) }
        return words.map { noun in
            let articles = forms.filter { $0.word == noun }.map(\.article)
            return "\(articles.joined(separator: " / ")) \(noun)"
        }.joined(separator: " / ")
    }

    var exampleFormNote: String? {
        guard let forms = nounForms, !forms.isEmpty,
              !forms.contains(where: { $0.word == word }) else { return nil }
        return "In examples: \(word)"
    }
}

struct Vocabulary {
    private struct Document: Decodable { let cards: [WordCard] }
    let cards: [WordCard]
    let activeIDs: [String]
    let activeIDSet: Set<String>
    private let byID: [String: WordCard]
    init(cards: [WordCard]) {
        // Archived cards retain their IDs for saved history, but are excluded
        // from the library and every new random/review selection.
        self.cards = cards.filter { $0.active != false }
        activeIDs = self.cards.map(\.id)
        activeIDSet = Set(activeIDs)
        byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
    }
    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "vocabulary", withExtension: "json") else {
            throw WortagError.message("The offline vocabulary is missing. Rebuild Wortag.")
        }
        try self.init(data: Data(contentsOf: url))
    }

    init(data: Data) throws {
        let cards = try JSONDecoder().decode(Document.self, from: data).cards
        guard cards.contains(where: { $0.active != false }), Set(cards.map(\.id)).count == cards.count else {
            throw WortagError.message("The vocabulary is empty or contains duplicate IDs.")
        }
        guard cards.allSatisfy({ card in
            !card.id.isEmpty && !card.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !card.examples.isEmpty && card.examples.allSatisfy {
                !$0.german.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.attribution.isEmpty
            } && (card.nounForms ?? []).allSatisfy {
                ["der", "die", "das"].contains($0.article) && !$0.word.isEmpty
            }
        }) else {
            throw WortagError.message("The vocabulary contains an invalid word or missing examples. Rebuild Wortag.")
        }
        self.init(cards: cards)
    }
    subscript(_ id: String) -> WordCard? { byID[id] }
}

enum WortagError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
