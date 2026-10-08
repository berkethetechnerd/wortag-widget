#!/usr/bin/env python3
"""Enrich noun cards from a reproducible, offline Wiktionary dictionary subset.

Regenerate the subset: noun_articles.py DECK --extract de-extract.jsonl.gz
Apply the saved subset: noun_articles.py DECK
"""
import argparse
import collections
import gzip
import hashlib
import json
import re
from pathlib import Path

DICTIONARY = Path(__file__).with_name('noun_dictionary.json')
SOURCE = 'https://kaikki.org/dictionary/downloads/de/de-extract.jsonl.gz'
ARTICLES = {'masculine': 'der', 'feminine': 'die', 'neuter': 'das'}
CASES = {'nominative', 'accusative', 'dative', 'genitive'}
# Most personal and place names normally occur without an article. These place
# names in the deck conventionally take one; their forms still come from data.
ARTICLE_NAMES = set('Schweiz Türkei Ukraine Iran Irak Niederlande Niederlanden USA Sowjetunion UdSSR Philippinen Rhein Donau Alpen Atlantik Sonne Mond Erde Venus Saturn Merkur Jupiter'.split())
NON_NOUN_CARDS = set('Sie Ihre Ihnen Ihr Ihren Ihrer Ihres Na Somit Andernfalls Polen'.split())
# Resolve homographic inflections to their usual everyday lemma, rather than
# rarer dictionary entries (e.g. Sekunden is normally the plural of Sekunde).
PREFERRED = {
    'Jungen': 'Junge', 'Leuten': 'Leute', 'Sekunden': 'Sekunde',
    'Studien': 'Studie', 'Quellen': 'Quelle', 'Typen': 'Typ',
    'Zeugen': 'Zeuge', 'Fakten': 'Fakt', 'Runden': 'Runde', 'Türen': 'Tür',
    'Katzen': 'Katze', 'Schäden': 'Schaden', 'Alternativen': 'Alternative',
    'Riesen': 'Riese', 'Akten': 'Akte', 'Massen': 'Masse', 'Kurse': 'Kurs',
    'Ecken': 'Ecke', 'Leichen': 'Leiche', 'Bakterien': 'Bakterium',
    'Speisen': 'Speise', 'Bären': 'Bär', 'Tabletten': 'Tablette', 'Dosen': 'Dose',
    'Zwecken': 'Zweck', 'Unruhen': 'Unruhe', 'Friedens': 'Frieden',
    'Mythen': 'Mythos', 'Fächern': 'Fach', 'Tauben': 'Taube', 'Zehen': 'Zehe',
    'Passanten': 'Passant', 'Buben': 'Bub', 'Kursen': 'Kurs', 'Asiaten': 'Asiat',
    'Schnecken': 'Schnecke', 'Medien': 'Medium', 'Marken': 'Marke',
}
# These deck examples contain both meanings, or use a different sense from the
# dictionary's first entry. Retain the corresponding dictionary articles.
ALTERNATIVE_ARTICLES = {'See': {'der', 'die'}, 'Teil': {'der', 'das'},
                        'Leiter': {'der', 'die'}, 'Band': {'die'}}
SPELLING_ALIASES = {
    'Schluß': 'Schluss', 'Einfluß': 'Einfluss', 'Abschluß': 'Abschluss',
    'Prozeß': 'Prozess', 'Anlaß': 'Anlass', 'Haß': 'Hass', 'Streß': 'Stress',
    'Füsse': 'Füße', 'Schuß': 'Schuss', 'Kompromiß': 'Kompromiss',
    'Entschluß': 'Entschluss', 'Photo': 'Foto', 'Fitneßstudio': 'Fitnessstudio',
    'Schlußfolgerung': 'Schlussfolgerung', 'Verlaß': 'Verlass',
}
# Productive nominalizations do not always have their own dictionary entry.
# These explicit forms were checked against the deck's noun usage; imperative
# forms such as Fügen are deliberately excluded. See the grammar credit below.
NEUTER_NOMINALIZATIONS = {
    'Allgemeinen': 'Allgemeine', 'Wichtigste': 'Wichtigste', 'Besseres': 'Bessere',
    'Wesentlichen': 'Wesentliche', 'Wichtiges': 'Wichtige', 'Ähnliches': 'Ähnliche',
    'Schlimmste': 'Schlimmste', 'Notwendige': 'Notwendige', 'Wesentliche': 'Wesentliche',
    'Doppelte': 'Doppelte', 'Interessantes': 'Interessante', 'Persönliches': 'Persönliche',
    'Nötige': 'Nötige', 'Dunkeln': 'Dunkle', 'Bestimmtes': 'Bestimmte',
    'Falsches': 'Falsche', 'Schlimmes': 'Schlimme', 'Schlimmeres': 'Schlimmere',
    'Geringsten': 'Geringste', 'Dummes': 'Dumme', 'Spezielles': 'Spezielle',
    'Laufenden': 'Laufende', 'Stehende': 'Stehende', 'Eingreifen': 'Eingreifen',
    'Umdrehen': 'Umdrehen', 'Platzen': 'Platzen', 'Tausende': 'Tausend',
}


def split_form(form):
    text = form['form'].strip()
    article = form.get('article')
    match = re.match(r'^\(?((?:der|die|das|des|dem|den))\)?\s+(.+)$', text)
    if match:
        article, text = match.groups()
    return article, text


def noun_entry(row):
    if 'form-of' in row.get('tags', []):
        return None
    # Prefer the dictionary's first nominative article, which gives the common
    # form ahead of regional alternatives such as die Foto or das Monat.
    nominatives = [f for f in row.get('forms', [])
                   if 'nominative' in f.get('tags', [])]
    singular = [f for f in nominatives if 'singular' in f.get('tags', [])]
    plural = [f for f in nominatives if 'plural' in f.get('tags', [])]
    head = next((split_form(f) for f in singular
                 if split_form(f)[0] in {'der', 'die', 'das'}), None)
    if head is None:
        head = next((split_form(f) for f in plural if split_form(f)[0] == 'die'), None)
    if head is None and not nominatives:
        # Alternative spellings sometimes have a gender but no inflection table.
        article = next((ARTICLES[t] for t in row.get('tags', []) if t in ARTICLES), None)
        if article:
            head = (article, row['word'])
    if head is None:
        return None
    forms = {row['word'], head[1]}
    for f in row.get('forms', []):
        if CASES.intersection(f.get('tags', [])):
            _, word = split_form(f)
            if word and word not in {'—', '-', '–'}:
                forms.add(word)
    return {'lemma': row['word'], 'article': head[0], 'word': head[1],
            'forms': sorted(forms)}


def extract_dictionary(path, cards):
    targets = {c['word'] for c in cards if c['word'][0].isupper()}
    targets.update(SPELLING_ALIASES.values())
    entries = []
    with gzip.open(path, 'rt', encoding='utf-8') as source:
        for line in source:
            row = json.loads(line)
            if row.get('lang_code') != 'de' or row.get('pos') not in {'noun', 'name', 'abbrev'}:
                continue
            if row['pos'] == 'name' and row['word'] not in ARTICLE_NAMES:
                continue
            entry = noun_entry(row)
            if entry and targets.intersection(entry['forms']):
                entries.append(entry)
    return {'source': SOURCE, 'credit': 'German Wiktionary contributors; extraction by Tatu Ylönen / Wiktextract / Kaikki.org',
            'downloaded': '2026-10-07', 'license': 'CC BY-SA 4.0',
            'sourceSHA256': hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            'nominalizationGrammar': 'https://grammis.ids-mannheim.de/rechtschreibung/6194',
            'supplementCredit': 'Wortag explicit nominalization forms: CC0; dictionary forms: CC BY-SA 4.0',
            'selection': 'German noun entries; first nominative article; usual everyday lemmas for ambiguous inflections; ordinary names and pronouns excluded',
            'entries': entries}


def enrich_document(document, dictionary=None):
    dictionary = dictionary or json.loads(DICTIONARY.read_text())
    index = collections.defaultdict(list)
    for entry in dictionary['entries']:
        for word in entry['forms']:
            index[word].append(entry)
    for old, modern in SPELLING_ALIASES.items():
        index[old] = index[modern]
    for card in document['cards']:
        card.pop('nounForms', None)
        word = card['word']
        if not word[0].isupper() or word in NON_NOUN_CARDS:
            continue
        candidates = index[word]
        if word in PREFERRED:
            candidates = [c for c in candidates if c['lemma'] == PREFERRED[word]]
        else:
            exact = [c for c in candidates if c['lemma'] == word]
            candidates = exact or candidates
            # Prefer the literal noun (das Alter) over an adjectival noun whose
            # indefinite form has the same spelling (ein Alter / der Alte).
            literal = [c for c in candidates if c['word'] == word]
            candidates = literal or candidates
        # One primary entry per lemma; other headwords are retained for genuine
        # morphology ambiguities (e.g. der Arme / die Arme).
        chosen = {}
        for candidate in candidates:
            if candidate['lemma'] not in chosen:
                chosen[candidate['lemma']] = candidate
        selected = list(chosen.values())
        if word in ALTERNATIVE_ARTICLES:
            selected = [c for c in candidates if c['article'] in ALTERNATIVE_ARTICLES[word]]
        forms = []
        for c in selected:
            form = {'article': c['article'], 'word': c['word']}
            if form not in forms:
                forms.append(form)
        if forms:
            card['nounForms'] = forms
        if word in NEUTER_NOMINALIZATIONS:
            card['nounForms'] = [{'article': 'das', 'word': NEUTER_NOMINALIZATIONS[word]}]
    document['nounArticleCredit'] = {k: v for k, v in dictionary.items() if k != 'entries'}
    return document


def write_json(path, data):
    path = Path(path)
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
    temp.replace(path)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('deck', type=Path)
    parser.add_argument('--extract', type=Path)
    args = parser.parse_args()
    document = json.loads(args.deck.read_text())
    if args.extract:
        write_json(DICTIONARY, extract_dictionary(args.extract, document['cards']))
    enrich_document(document)
    write_json(args.deck, document)
    count = sum(bool(c.get('nounForms')) for c in document['cards'])
    print(f'Added nominative articles to {count:,} noun cards; IDs and examples preserved.')
