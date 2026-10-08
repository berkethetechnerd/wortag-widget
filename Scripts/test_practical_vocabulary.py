import copy
import json
import unittest
from pathlib import Path
from practical_vocabulary import apply_selection, selected_words, INDEX


class PracticalVocabularyTests(unittest.TestCase):
    def testDeckUsesReviewedUniqueNounAndVerbLemmasWithArticles(self):
        document = json.loads((Path(__file__).resolve().parents[1] / 'Resources/vocabulary.json').read_text())
        active = [c for c in document['cards'] if c['active']]
        self.assertEqual(len(active), document['activeSelection']['activeCount'])
        self.assertEqual(len(active), len({c['word'] for c in active}))
        self.assertGreater(len(active), 1000)
        index = json.loads(INDEX.read_text())['entries']
        approved = selected_words()
        for card in active:
            self.assertIn(card['word'], approved)
            self.assertIn(card['partOfSpeech'], {'noun', 'verb'})
            self.assertEqual(index[card['word']]['lemma'], card['word'])
            if card['partOfSpeech'] == 'noun':
                self.assertTrue(card['nounForms'])
                self.assertTrue(all(f['article'] in {'der', 'die', 'das'} and f['word'] == card['word']
                                    for f in card['nounForms']))
        targets = {c['word'] for c in active}
        self.assertTrue({'Genehmigung', 'Mietvertrag', 'Werkzeug', 'bewältigen', 'nachvollziehen'} <= targets)
        self.assertFalse(targets & {'Wohnung', 'Wohnungen', 'Kolumbien', 'Schweiz', 'Deutschland',
                                    'Japaner', 'Franzose', 'Amerikaner', 'Deutsch', 'essen', 'gehen', 'trinken'})

    def testSelectionIsIdempotentAndPreservesArchivedData(self):
        document = json.loads((Path(__file__).resolve().parents[1] / 'Resources/vocabulary.json').read_text())
        original = copy.deepcopy(document)
        apply_selection(document)
        self.assertEqual(document, original)
        self.assertEqual(len(document['cards']), 10000)


if __name__ == '__main__':
    unittest.main()
