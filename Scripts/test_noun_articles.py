import copy
import json
import unittest
from pathlib import Path
from noun_articles import noun_entry, enrich_document


class NounArticleTests(unittest.TestCase):
    def testDictionaryPrefersPrimaryArticleOverRegionalAlternative(self):
        entry = noun_entry({'word': 'Foto', 'forms': [
            {'form': 'Foto', 'article': 'das', 'tags': ['nominative', 'singular']},
            {'form': 'Foto', 'article': 'die', 'tags': ['nominative', 'singular']},
        ]})
        self.assertEqual(entry['article'], 'das')

    def testPluralOnlyAndWeakDeclensionUseGrammaticalHeadings(self):
        parents = noun_entry({'word': 'Eltern', 'forms': [
            {'form': 'Eltern', 'article': 'die', 'tags': ['nominative', 'plural']}
        ]})
        self.assertEqual((parents['article'], parents['word']), ('die', 'Eltern'))
        friend = noun_entry({'word': 'Bekannter', 'forms': [
            {'form': 'Bekannter', 'tags': ['nominative', 'singular']},
            {'form': 'der Bekannte', 'tags': ['nominative', 'singular']},
            {'form': 'dem Bekannten', 'tags': ['dative', 'singular']},
        ]})
        self.assertEqual((friend['article'], friend['word']), ('der', 'Bekannte'))
        self.assertIn('Bekannten', friend['forms'])

    def testEnrichmentPreservesLearningIDsSurfaceWordsAndSentences(self):
        path = Path(__file__).resolve().parents[1] / 'Resources/vocabulary.json'
        document = json.loads(path.read_text())
        before = [(c['id'], c['word'], copy.deepcopy(c['examples'])) for c in document['cards']]
        enrich_document(document)
        self.assertEqual(before, [(c['id'], c['word'], c['examples']) for c in document['cards']])
        first = copy.deepcopy(document)
        enrich_document(document)
        self.assertEqual(first, document)

    def testActualDeckArticlesAndNonNouns(self):
        path = Path(__file__).resolve().parents[1] / 'Resources/vocabulary.json'
        cards = {c['id']: c for c in json.loads(path.read_text())['cards']}
        for word, article, lemma in [('wohnung', 'die', 'Wohnung'), ('buch', 'das', 'Buch'),
                                     ('tisch', 'der', 'Tisch'), ('kindern', 'das', 'Kind'),
                                     ('eltern', 'die', 'Eltern'), ('sonne', 'die', 'Sonne'),
                                     ('wagen', 'der', 'Wagen'), ('schweiz', 'die', 'Schweiz')]:
            self.assertEqual(cards[word]['nounForms'], [{'article': article, 'word': lemma}])
        for word in ['gehen', 'essen', 'sie', 'ihnen', 'deutschland', 'österreich', 'polen', 'fügen']:
            self.assertNotIn('nounForms', cards[word], word)
        for word, article, lemma in [('pc', 'der', 'PC'), ('wichtiges', 'das', 'Wichtige'),
                                     ('schluß', 'der', 'Schluss'), ('alter', 'das', 'Alter')]:
            self.assertEqual(cards[word]['nounForms'], [{'article': article, 'word': lemma}])
        self.assertGreater(sum(bool(c.get('nounForms')) for c in cards.values()), 4000)
        for card in cards.values():
            for form in card.get('nounForms', []):
                self.assertIn(form['article'], {'der', 'die', 'das'})
                self.assertTrue(form['word'][0].isupper())


if __name__ == '__main__':
    unittest.main()
