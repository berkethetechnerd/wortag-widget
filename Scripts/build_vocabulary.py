#!/usr/bin/env python3
"""Build varied examples; never fill a card with grammatical rewrites.

Usage: python build_vocabulary.py deu-eng.zip Resources/vocabulary.json
       --supplement deu_sentences_detailed.tsv.bz2
Build dependencies: wordfreq==3.1.1, nltk==3.9.2. No NLP model downloads.
Existing output supplies stable IDs, preserving learning progress.
"""
import argparse
import bz2
import collections
import hashlib
import json
import re
import zipfile
from pathlib import Path
from wordfreq import zipf_frequency
from sentence_diversity import TOKEN, select_examples, distinct
from noun_articles import enrich_document
from practical_vocabulary import apply_selection

EXCLUDED = set('tom mary maria john boston australien japan amerika englisch deutsch französisch ck tatoeba toms marias marys jones smith peter paul hans london paris tokio berlin new york usa okay ok hey hmm hm ah oh mr mrs dr jr etc gros kompaß muß daß wußte wußten paß paßt läßt schloß biß kuß fluß faßt verpaßt bewußt'.split())
BLOCK = re.compile(r'\b(?:nazi\w*|hitler|scheiß\w*|fuck\w*|fick\w*|arsch\w*|hur\w*|porn\w*|vergewaltig\w*|suizid\w*|selbstmord\w*)\b', re.I)
OLD_SPELLING = re.compile(r'\b(?:daß|muß\w*|wußt\w*|paß\w*|läßt|schloß|biß\w*|kuß|fluß|faßt|verpaßt|bewußt\w*|kompaß)\b', re.I)
MODERN_DISPLAY = {'zusammengefaßt': 'zusammengefasst', 'boß': 'Boss', 'befaßt': 'befasst'}

def valid_sentence(de, en=''):
    return (18 <= len(de) <= 160 and len(en) <= 180 and not BLOCK.search(de)
            and not OLD_SPELLING.search(de) and 4 <= len(TOKEN.findall(de)) <= 26
            and de.endswith(('.', '?', '!')))

def validate(cards):
    assert len(cards) == 10000 and len({c['id'] for c in cards}) == 10000
    for card in cards:
        examples = card['examples']
        assert 2 <= len(examples) <= 3, card['id']
        for index, example in enumerate(examples):
            assert card['word'].lower() in TOKEN.findall(example['german'].lower()), card['id']
            assert example['attribution'], card['id']
            assert all(distinct(example, p) for p in examples[:index]), card['id']

def build(archive, output, supplement=None):
    destination = Path(output)
    old = json.loads(destination.read_text()) if destination.exists() else None
    blueprint = old['cards'] if old else None
    focus = {c['id']: MODERN_DISPLAY.get(c['id'], c['word']).lower() for c in blueprint} if blueprint else None
    targets = set(focus.values()) if focus else None
    candidates = collections.defaultdict(list)
    casing = collections.defaultdict(collections.Counter)
    occurrences = collections.Counter()
    with zipfile.ZipFile(archive) as z:
        rows = z.read('deu.txt').decode('utf-8').splitlines()
    seen = set()
    for row in rows:
        en, de, credit = row.split('\t', 2)
        if de in seen or not valid_sentence(de, en): continue
        seen.add(de)
        tokens = TOKEN.findall(de)
        words = {t.lower() for t in tokens}
        if targets is not None: words &= targets
        example = {'german': de, 'english': en, 'attribution': credit}
        for word in words:
            if targets is None and (word in EXCLUDED or not 2 <= len(word) <= 23): continue
            occurrences[word] += 1
            for position, token in enumerate(tokens):
                if token.lower() == word and position > 0: casing[word][token] += 1
            # Use the entire pool, rather than the first 80 short rewrites.
            candidates[word].append(example)
    if blueprint is None:
        ranked = sorted((w for w, ex in candidates.items() if len(ex) >= 2 and zipf_frequency(w, 'de') >= 2.7),
                        key=lambda w: (-zipf_frequency(w, 'de'), -occurrences[w], w))
        blueprint = [{'id': w, 'word': casing[w].most_common(1)[0][0] if casing[w] else w} for w in ranked[:10000]]
        focus = {c['id']: c['word'].lower() for c in blueprint}
    selections = {}
    for index, card in enumerate(blueprint):
        selections[card['id']] = select_examples(candidates[focus[card['id']]])
        if index % 2000 == 0: print(f'Checked {index:,} cards', flush=True)
    missing = {focus[c['id']] for c in blueprint if len(selections[c['id']]) < 2}
    print(f'{len(missing)} words need more distinct source contexts', flush=True)
    if missing and supplement:
        supplementary = collections.defaultdict(list)
        with bz2.open(supplement, 'rt', encoding='utf-8') as handle:
            for row in handle:
                sid, language, de, author, *_ = row.rstrip('\n').split('\t')
                if language != 'deu' or de in seen or not valid_sentence(de): continue
                words = {t.lower() for t in TOKEN.findall(de)} & missing
                if not words: continue
                seen.add(de)
                credit = f'CC-BY 2.0 France Attribution: tatoeba.org #{sid} ({author})'
                example = {'german': de, 'english': '', 'attribution': credit}
                for word in words: supplementary[word].append(example)
        for card in blueprint:
            word = focus[card['id']]
            if word in missing:
                selections[card['id']] = select_examples(candidates[word] + supplementary[word])
    originals = json.loads(Path(__file__).with_name('original_examples.json').read_text())
    curated = json.loads(Path(__file__).with_name('curated_examples.json').read_text())
    cards = []
    for card in blueprint:
        key = card['id']
        selected = select_examples(curated[key]) if key in curated else selections[key]
        if len(selected) < 2:
            # Explicitly authored contexts, not templates or a similarity bypass.
            selected = select_examples(selected + originals.get(key, []))
        if len(selected) < 2:
            raise ValueError(f'{key}: fewer than two varied examples. Output was not changed.')
        cards.append({'id': key, 'word': MODERN_DISPLAY.get(key, card['word']), 'examples': selected})
    validate(cards)
    document = {
        'source': 'Tatoeba via ManyThings.org (2026-02-13), plus German detailed export downloaded 2026-10-07',
        'license': 'Sentence text: CC BY 2.0 France; word selection: CC BY-SA 4.0; Wortag original examples: CC0',
        'wordSelectionCredit': 'wordfreq by Robyn Speer; see DATA-LICENSES.md for underlying source credits',
        'exampleSelection': 'German/English content stems, ignoring pronouns and function words; pairwise similarity below 0.5; no near-duplicate fallback',
        'corpusSHA256': hashlib.sha256(Path(archive).read_bytes()).hexdigest(),
        'supplementSHA256': hashlib.sha256(Path(supplement).read_bytes()).hexdigest() if supplement else None,
        'cards': cards
    }
    enrich_document(document)
    apply_selection(document)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix('.tmp')
    temporary.write_text(json.dumps(document, ensure_ascii=False, separators=(',', ':')) + '\n')
    temporary.replace(destination)
    print(f"Wrote {len(cards):,} cards / {sum(len(c['examples']) for c in cards):,} varied examples")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive')
    parser.add_argument('output')
    parser.add_argument('--supplement')
    args = parser.parse_args()
    build(args.archive, args.output, args.supplement)
