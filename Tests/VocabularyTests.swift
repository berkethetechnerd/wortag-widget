import XCTest
@testable import WortagCore

final class VocabularyTests: XCTestCase {
    private struct Document: Decodable { let cards: [WordCard] }

    func testLegacyCardsStillDecodeWithoutNounMetadata() throws {
        let card = try JSONDecoder().decode(WordCard.self, from:
            Data(#"{"id":"gehen","word":"gehen","examples":[]}"#.utf8))
        XCTAssertNil(card.nounForms)
        XCTAssertEqual(card.displayWord, "gehen")
        XCTAssertNil(card.exampleFormNote)
    }

    func testNounArticleDoesNotChangeIdentityOrSentenceTarget() throws {
        let card = WordCard(id: "wohnung", word: "Wohnung", examples: [],
                            nounForms: [NounForm(article: "die", word: "Wohnung")])
        XCTAssertEqual(card.displayWord, "die Wohnung")
        XCTAssertEqual(card.word, "Wohnung")
        XCTAssertEqual(card.id, "wohnung")
        XCTAssertNil(card.exampleFormNote)
        XCTAssertEqual(try JSONDecoder().decode(WordCard.self, from: JSONEncoder().encode(card)), card)
    }

    func testInflectedNounsShowTheirDictionaryArticleAndExampleForm() {
        let card = WordCard(id: "kindern", word: "Kindern", examples: [],
                            nounForms: [NounForm(article: "das", word: "Kind")])
        XCTAssertEqual(card.displayWord, "das Kind")
        XCTAssertEqual(card.exampleFormNote, "In examples: Kindern")
    }

    func testAlternativeArticlesShareOneHeadingWord() {
        let card = WordCard(id: "see", word: "See", examples: [], nounForms: [
            NounForm(article: "der", word: "See"), NounForm(article: "die", word: "See")
        ])
        XCTAssertEqual(card.displayWord, "der / die See")
    }

    func testBundledDeckContainsArticlesAndPreservesTenThousandIDs() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources/vocabulary.json")
        let cards = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url)).cards
        let vocabulary = Vocabulary(cards: cards)
        XCTAssertEqual(cards.count, 10000)
        XCTAssertEqual(Set(cards.map(\.id)).count, 10000)
        XCTAssertGreaterThan(vocabulary.cards.count, 1000)
        XCTAssertLessThan(vocabulary.cards.count, 3000)
        XCTAssertTrue(vocabulary.cards.allSatisfy { $0.active == true })
        XCTAssertFalse(vocabulary.cards.contains { ["wohnung", "kolumbien", "deutschland", "japaner", "gehen", "essen"].contains($0.id) })
        XCTAssertEqual(vocabulary["genehmigung"]?.displayWord, "die Genehmigung")
        XCTAssertEqual(vocabulary["mietvertrag"]?.displayWord, "der Mietvertrag")
        XCTAssertEqual(vocabulary["werkzeug"]?.displayWord, "das Werkzeug")
        XCTAssertEqual(vocabulary["wohnung"]?.displayWord, "die Wohnung")
        XCTAssertEqual(vocabulary["buch"]?.displayWord, "das Buch")
        XCTAssertEqual(vocabulary["tisch"]?.displayWord, "der Tisch")
        XCTAssertEqual(vocabulary["kindern"]?.displayWord, "das Kind")
        XCTAssertEqual(vocabulary["eltern"]?.displayWord, "die Eltern")
        XCTAssertEqual(vocabulary["gehen"]?.displayWord, "gehen")
        XCTAssertNil(vocabulary["sie"]?.nounForms)
        XCTAssertNil(vocabulary["deutschland"]?.nounForms)
    }

    func testArchivedCardsResolveSavedIDsButLeaveTheActiveLibrary() {
        let old = WordCard(id: "wohnung", word: "Wohnung", examples: [], active: false)
        let current = WordCard(id: "bewältigen", word: "bewältigen", examples: [], active: true)
        let vocabulary = Vocabulary(cards: [old, current])
        XCTAssertEqual(vocabulary.cards.map(\.id), ["bewältigen"])
        XCTAssertEqual(vocabulary[old.id], old)
    }
}

extension VocabularyTests {
    func testDictionaryFormsAndClueAreAvailableWithoutChangingCardIdentity() throws {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/vocabulary.json")
        let vocabulary = try Vocabulary(data: Data(contentsOf: path))
        XCTAssertTrue(vocabulary.cards.allSatisfy { $0.dictionary?.isValid == true })
        XCTAssertEqual(vocabulary["mietvertrag"]?.dictionary?.plurals, ["Mietverträge"])
        XCTAssertEqual(vocabulary["verzichten"]?.dictionary?.usage, ["verzichten auf + Akkusativ"])
        XCTAssertEqual(vocabulary["bewältigen"]?.dictionary?.participle, "bewältigt")
        let word = vocabulary["selbstverständlichkeit"]!
        XCTAssertFalse(word.recallClue.lowercased().contains(word.word.lowercased()))
        XCTAssertEqual(URLComponents(url: word.pronunciationURL!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, word.id)
    }
}
