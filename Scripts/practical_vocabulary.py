#!/usr/bin/env python3
"""Apply Wortag's reviewed lemma selection without deleting saved card identities.

Usage: practical_vocabulary.py Resources/vocabulary.json
       --dictionary-source /path/to/practical_dictionary.json
The optional source is the German Wiktionary target-entry extraction; the compact
validated index is saved next to this script for subsequent offline rebuilds.
"""
import argparse
import json
from pathlib import Path
from noun_articles import noun_entry, SOURCE

ROOT = Path(__file__).resolve().parent
INDEX = ROOT / 'practical_dictionary.json'


def selected_words():
    return {word for line in (ROOT / 'practical_words.txt').read_text().splitlines()
            if not line.startswith('#') for word in line.split()}


def extract_index(source):
    result = {}
    targets = selected_words()
    raw = json.loads(Path(source).read_text())
    for word in sorted(targets):
        for row in raw.get(word, []):
            row['tags'] = row.get('tags') or []
            row['forms'] = row.get('forms') or []
            if row['pos'] not in {'noun', 'verb'} or 'form-of' in row['tags']:
                continue
            senses = row.get('senses') or []
            if not senses or all('form_of' in s or set(s.get('tags', [])) &
                                  {'archaic', 'obsolete', 'dated', 'dialectal'} for s in senses):
                continue
            if row['pos'] == 'noun':
                entry = noun_entry(row)
                if not entry or entry['word'] != word:
                    continue
            elif not word.islower() or not word.endswith(('en', 'ern', 'eln')):
                continue
            result[word] = {'lemma': word, 'partOfSpeech': row['pos']}
            break
    return {'source': SOURCE, 'credit': 'German Wiktionary contributors; Tatu Ylönen / Wiktextract / Kaikki.org',
            'license': 'CC BY-SA 4.0',
            'sourceSHA256': '2e66f18a093e94b29b04733d0222625695a3d5ed199e700059193895490dfb19',
            'entries': result}


def apply_selection(document, dictionary=None):
    dictionary = dictionary or json.loads(INDEX.read_text())
    approved = selected_words()
    used = set()
    for card in document['cards']:
        entry = dictionary['entries'].get(card['word'])
        active = bool(entry and card['word'] in approved and card['word'] not in used)
        if active and entry['partOfSpeech'] == 'noun':
            # Require an unambiguous literal dictionary heading with an article.
            forms = card.get('nounForms', [])
            active = bool(forms) and all(f['word'] == card['word'] for f in forms)
        card['active'] = active
        card.pop('partOfSpeech', None)
        if active:
            card['partOfSpeech'] = entry['partOfSpeech']
            used.add(card['word'])
    assert len(used) >= 1000, 'Refusing to install an unexpectedly small deck'
    document['activeSelection'] = {
        'target': 'Mostly B1–C2; editorial difficulty estimate, not a certified CEFR classification',
        'method': 'Reviewed practical noun/verb allowlist, validated German Wiktionary dictionary lemmas; no inflection duplicates, beginner targets, proper names, countries or nationalities',
        'allowlistCredit': 'Wortag editorial lemma selection: CC0',
        'dictionaryCredit': {k: v for k, v in dictionary.items() if k != 'entries'},
        'activeCount': len(used),
        'archivedCount': len(document['cards']) - len(used),
        'archivePolicy': 'Archived identities, sentences and saved progress retained; excluded from library, history navigation, random rotation and due reviews'
    }
    from learning_dictionary import enrich
    return enrich(document)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('deck', type=Path)
    parser.add_argument('--dictionary-source', type=Path)
    args = parser.parse_args()
    if args.dictionary_source:
        INDEX.write_text(json.dumps(extract_index(args.dictionary_source), ensure_ascii=False, indent=2) + '\n')
    document = apply_selection(json.loads(args.deck.read_text()))
    temporary = args.deck.with_suffix('.tmp')
    temporary.write_text(json.dumps(document, ensure_ascii=False, separators=(',', ':')) + '\n')
    temporary.replace(args.deck)
    print(json.dumps(document['activeSelection'], ensure_ascii=False, indent=2))
