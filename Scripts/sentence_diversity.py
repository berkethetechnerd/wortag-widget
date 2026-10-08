"""Reject grammatical rewrites using the content of both languages.

No NLTK corpus downloads are needed: Snowball stemmers run entirely locally.
"""
import re
from functools import lru_cache
from nltk.stem.snowball import GermanStemmer, EnglishStemmer

TOKEN = re.compile(r"[A-Za-zÄÖÜäöüß]+")
DE_STOP = set("ich du er sie es wir ihr man mich dich sich uns euch mir dir ihm ihnen mein meine meinen meiner meines dein deine deinen deiner seines seinen seine ihr ihre ihren ihrer unserer unsere unseren euer eure euren der die das den dem des ein eine einen einem einer eines ist sind bist bin seid war waren wurde wurden wird werden hat haben hast habt hatte hatten habe zu zum zur in im am an auf aus von vom mit für bei über unter nach vor und oder aber wenn dass ob als es da dort nicht noch schon auch wieder gerade bitte tom mary maria john".split())
EN_STOP = set("i you he she it we they me him her us them my your his its our their mine yours ours theirs a an the is are am was were be been being has have had do does did will would can could shall should may might must to of in on at by for from with and or but if when that this these those not no again just please s t m d re ve ll let tom mary maria john mr mrs sir".split())
STEMMERS = {"de": GermanStemmer(), "en": EnglishStemmer()}

@lru_cache(maxsize=1200000)
def content_signature(text, language):
    stop = DE_STOP if language == "de" else EN_STOP
    return frozenset(STEMMERS[language].stem(t) for t in TOKEN.findall(text.lower()) if t not in stop)

def similarity(first, second):
    score = 0.0
    for key, language in [("german", "de"), ("english", "en")]:
        a, b = content_signature(first[key], language), content_signature(second[key], language)
        if a and b:
            score = max(score, len(a & b) / len(a | b))
    return score

def distinct(first, second):
    return similarity(first, second) < 0.5

def select_examples(examples, maximum=3):
    # Seed with a readable sentence; subsequent choices prefer new content.
    def quality(example):
        text = example["german"]
        return abs(len(text) - 58) + (20 if "Tom" in text else 0) + max(0, len(text) - 110)
    remaining = sorted(examples, key=quality)
    selected = []
    while remaining and len(selected) < maximum:
        eligible = [e for e in remaining if all(distinct(e, s) for s in selected)]
        if not eligible:
            break  # Never fill a card with rejected near-duplicates.
        chosen = min(eligible, key=lambda e: quality(e) + 85 * max((similarity(e, s) for s in selected), default=0))
        selected.append(chosen)
        remaining = [e for e in remaining if e is not chosen]
    return selected
