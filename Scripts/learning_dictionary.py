#!/usr/bin/env python3
"""Build/apply offline learning metadata from the pinned German Wiktionary extract.
No dictionary examples or audio are copied. Existing card IDs are untouched.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path

INDEX = Path(__file__).with_name('learning_dictionary.json')
BAD_TAGS = {'archaic', 'obsolete', 'dated', 'dialectal', 'form-of'}
# Explicitly reviewed constructions, independent of automatic morphology extraction.
USAGE = {
    'verzichten': ['verzichten auf + Akkusativ'],
    'teilnehmen': ['teilnehmen an + Dativ'],
    'abhängen': ['abhängen von + Dativ'],
    'bestehen': ['bestehen aus + Dativ (composition)', 'bestehen auf + Dativ (insistence)'],
    'verfügen': ['verfügen über + Akkusativ'],
    'beitragen': ['beitragen zu + Dativ'],
    'scheitern': ['scheitern an + Dativ'],
    'sich': [],
    'zustimmen': ['jemandem / etwas zustimmen + Dativ'],
    'entsprechen': ['jemandem / etwas entsprechen + Dativ'],
    'widersprechen': ['jemandem / etwas widersprechen + Dativ'],
    'beantragen': ['etwas beantragen + Akkusativ'],
    'bewältigen': ['etwas bewältigen + Akkusativ'],
    'gewöhnen': ['sich gewöhnen an + Akkusativ'],
    'überzeugen': ['jemanden überzeugen von + Dativ'],
    'vergleichen': ['etwas vergleichen mit + Dativ'],
}

def clean(value):
    return value.strip() if isinstance(value, str) and value.strip() not in {'—', '-', '–', '?'} else ''

def metadata(row):
    meanings = []
    for sense in row.get('senses', []):
        if sense.get('form_of') or BAD_TAGS.intersection(sense.get('tags', [])):
            continue
        gloss = next((clean(g) for g in sense.get('glosses', []) if clean(g)), '')
        if not gloss:
            continue
        english = []
        for t in row.get('translations', []):
            if t.get('lang_code') == 'en' and not t.get('uncertain') and t.get('sense_index') == sense.get('sense_index'):
                word = clean(t.get('word'))
                if word and word not in english:
                    english.append(word)
        meanings.append({'definition': gloss, 'english': english[:4]})
        if len(meanings) == 3:
            break
    if not meanings:
        return None
    forms = row.get('forms') or []
    def first(tags, pronoun=None):
        return next((clean(f.get('form')) for f in forms
                     if set(tags).issubset(f.get('tags', []))
                     and not BAD_TAGS.intersection(f.get('tags', []))
                     and (pronoun is None or pronoun in f.get('pronouns', []))
                     and clean(f.get('form'))), None)
    result = {'partOfSpeech': row['pos'], 'meanings': meanings, 'usage': USAGE.get(row['word'], [])}
    if row['pos'] == 'noun':
        plurals = []
        for f in forms:
            if {'nominative', 'plural'}.issubset(f.get('tags', [])):
                word = clean(f.get('form'))
                if word and word not in plurals:
                    plurals.append(word)
        result['plurals'] = plurals[:3]
    else:
        result['present'] = first(['present'], 'er')
        result['past'] = first(['past'], 'ich')
        result['participle'] = first(['participle-2', 'perfect'])
        auxiliaries = []
        for f in forms:
            if {'auxiliary', 'perfect'}.issubset(f.get('tags', [])) and clean(f.get('form')) in {'haben', 'sein'}:
                if f['form'] not in auxiliaries:
                    auxiliaries.append(f['form'])
        result['auxiliary'] = ' / '.join(auxiliaries) or None
    return {k:v for k,v in result.items() if v is not None}

def extract(source, cards):
    targets = {c['word']:c for c in cards if c.get('active')}
    entries = {}
    with gzip.open(source, 'rt', encoding='utf-8') as stream:
        for line in stream:
            row = json.loads(line)
            card = targets.get(row.get('word'))
            if not card or card['id'] in entries or row.get('lang_code') != 'de' or row.get('pos') != card['partOfSpeech']:
                continue
            if BAD_TAGS.intersection(row.get('tags', [])):
                continue
            value = metadata(row)
            if value:
                entries[card['id']] = value
    missing = set(c['id'] for c in targets.values()) - entries.keys()
    if missing:
        raise ValueError(f'Missing dictionary information: {sorted(missing)}')
    return {
        'source': 'https://kaikki.org/dictionary/downloads/de/de-extract.jsonl.gz',
        'sourceSHA256': hashlib.sha256(Path(source).read_bytes()).hexdigest(),
        'license': 'CC BY-SA 4.0',
        'credit': 'German Wiktionary contributors; Tatu Ylönen / Wiktextract / Kaikki.org',
        'selection': 'Up to three non-archaic German definitions with sense-matched English translations where available; nominative plurals; explicit verb forms. No inferred forms. Usage notes curated by Wortag.',
        'entries': dict(sorted(entries.items())),
    }

def enrich(document, index=None):
    index = index or json.loads(INDEX.read_text())
    for card in document['cards']:
        card.pop('dictionary', None)
        if card.get('active'):
            if card['id'] not in index['entries']:
                raise ValueError(f'Missing dictionary entry: {card["id"]}')
            card['dictionary'] = index['entries'][card['id']]
    document['learningDictionaryCredit'] = {k:v for k,v in index.items() if k != 'entries'}
    return document

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('deck', type=Path)
    parser.add_argument('--extract', type=Path)
    args = parser.parse_args()
    document = json.loads(args.deck.read_text())
    if args.extract:
        INDEX.write_text(json.dumps(extract(args.extract, document['cards']), ensure_ascii=False, indent=2)+'\n')
    document = enrich(document)
    temporary = args.deck.with_suffix('.tmp')
    temporary.write_text(json.dumps(document, ensure_ascii=False, separators=(',', ':'))+'\n')
    temporary.replace(args.deck)
    print(f'Enriched {len([c for c in document["cards"] if c.get("dictionary")])} active cards')
