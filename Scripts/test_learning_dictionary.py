import json
import unittest
from pathlib import Path
from learning_dictionary import metadata, enrich

class LearningDictionaryTests(unittest.TestCase):
    def test_only_explicit_plural_forms_are_used(self):
        entry = metadata({'word':'Vertrag','pos':'noun','senses':[{'glosses':['an agreement']}],
                          'forms':[{'form':'Verträge','tags':['nominative','plural']},
                                   {'form':'Verträgen','tags':['dative','plural']}]})
        self.assertEqual(entry['plurals'], ['Verträge'])
    def test_english_translation_stays_with_its_sense(self):
        entry=metadata({'word':'Bank','pos':'noun','senses':[{'sense_index':'1','glosses':['bench']}],
                        'translations':[{'lang_code':'en','sense_index':'2','word':'bank'},
                                        {'lang_code':'en','sense_index':'1','word':'bench'}]})
        self.assertEqual(entry['meanings'][0]['english'], ['bench'])
    def test_deck_coverage_and_identity_are_preserved(self):
        path=Path(__file__).resolve().parent.parent/'Resources/vocabulary.json'
        document=json.loads(path.read_text()); before=[c['id'] for c in document['cards']]
        enriched=enrich(document)
        self.assertEqual(before,[c['id'] for c in enriched['cards']])
        active=[c for c in enriched['cards'] if c.get('active')]
        self.assertEqual(len(active),1642)
        self.assertTrue(all(c['dictionary']['meanings'] for c in active))
        self.assertEqual(next(c for c in active if c['id']=='mietvertrag')['dictionary']['plurals'],['Mietverträge'])
        self.assertEqual(next(c for c in active if c['id']=='verzichten')['dictionary']['auxiliary'],'haben')
