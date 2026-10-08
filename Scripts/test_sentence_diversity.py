import json
import unittest
from pathlib import Path
from sentence_diversity import distinct, select_examples
from build_vocabulary import validate

def example(german, english=""):
    return {"german": german, "english": english, "attribution": "test"}

class SentenceDiversityTests(unittest.TestCase):
    def test_reported_apartment_variants_are_rejected(self):
        variants = [example(t) for t in [
            "Wir sehen uns, wenn du wieder in die Wohnung zurückkommst.",
            "Wir sehen uns, wenn ihr wieder in die Wohnung zurückkommt.",
            "Wir sehen uns, wenn Sie wieder in die Wohnung zurückkommen."]]
        self.assertEqual(len(select_examples(variants)), 1)

    def test_subject_possessive_and_regular_conjugation_changes_are_rejected(self):
        self.assertFalse(distinct(example("Ich kaufe mir jeden Morgen einen Kaffee."),
                                  example("Er kauft sich jeden Morgen einen Kaffee.")))
        self.assertFalse(distinct(example("Meine Wohnung ist schön und groß."),
                                  example("Deine Wohnung ist schön und groß.")))

    def test_english_also_catches_rewrites_with_different_german_words(self):
        self.assertFalse(distinct(example("Ich habe ihn dazu gebracht zu gehen.", "I got him to go."),
                                  example("Wir haben ihn dazu gebracht zu gehen.", "We got him to go.")))

    def test_different_contexts_survive(self):
        examples = [example(t) for t in [
            "Die Miete für diese Wohnung ist leider zu hoch.",
            "Von der Wohnung aus erreichen wir den Bahnhof zu Fuß.",
            "Am Samstag streichen wir die Wände in unserer Wohnung."]]
        self.assertEqual(len(select_examples(examples)), 3)

    def test_no_duplicate_fallback_when_only_rewrites_exist(self):
        examples = [example("Ich wohne in einer kleinen Wohnung."),
                    example("Du wohnst in einer kleinen Wohnung.")]
        self.assertEqual(len(select_examples(examples)), 1)

    def test_whole_deck_passes_pairwise_diversity_and_word_checks(self):
        deck = Path(__file__).resolve().parent.parent / "Resources" / "vocabulary.json"
        validate(json.loads(deck.read_text())["cards"])

if __name__ == "__main__":
    unittest.main()
