# Vocabulary and example credits

German and English sentence text comes from the Tatoeba Project, packaged by
Charles Kelly at [ManyThings.org](https://www.manythings.org/anki/).
The input is `deu-eng.zip`, export dated 2026-02-13, SHA256:
`96ede75973d21eb12dbb767d192c8b9b1c59e3dc653af7592a3d5b178fabbf04`.

Sentence text is licensed under [CC BY 2.0 France](https://creativecommons.org/licenses/by/2.0/fr/).
Additional German contexts come from Tatoeba's detailed German export,
downloaded 2026-10-07:
https://downloads.tatoeba.org/exports/per_language/deu/deu_sentences_detailed.tsv.bz2
SHA256: `4fc1b9c2c7ada0f8aebdc8a68532c69b79a483629872f1f3f0ab88f5c50c0772`.
Some supplementary examples have no bundled English translation.

Every Tatoeba example preserves its original attribution, including sentence
IDs and contributors. The app links to the German sentence;
hovering that link shows the full credit. `Resources/Corpus-Attribution.txt`
also contains the distributor's original notice. Text is unchanged; selecting,
grouping and highlighting examples are Wortag's presentation changes.

Sixteen original examples authored for Wortag are marked **Wortag · original
example**. They are dedicated to the public domain under
[CC0](https://creativecommons.org/publicdomain/zero/1.0/). They illustrate
different situations rather than applying pronoun or conjugation templates.
The build-time diversity checker uses NLTK's Apache-2.0 Snowball implementation;
neither NLTK nor its models are bundled in the running app.

Word-form selection and ordering use **wordfreq 3.1.1 by Robyn Speer**,
[project and full source credits](https://github.com/rspeer/wordfreq),
[citation](https://doi.org/10.5281/zenodo.7199437).
Its frequency data is available under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
Wortag's derived word selection is distributed under that license. The source
sentence text retains its original CC BY license. The JSON document embeds both
the license and word-selection attribution. wordfreq's build-time code is
Apache-2.0 and is not a runtime dependency.

wordfreq's underlying sources include Google Books Ngrams, Wikipedia, the Leeds
Internet Corpus, ParaCrawl, OPUS/OpenSubtitles, SUBTLEX, NewsCrawl/GlobalVoices,
OSCAR, Twitter and Reddit frequency statistics. Credit to OpenSubtitles:
https://www.opensubtitles.org/ ; freely available SUBTLEX data by Marc Brysbaert
and colleagues: http://crr.ugent.be/programs-data/subtitle-frequencies ; Google
Books Ngrams: https://books.google.com/ngrams . Full references and the source
conditions are in wordfreq's README linked above.

Noun articles and nominative forms come from **German Wiktionary contributors**,
extracted by **Tatu Ylönen / Wiktextract** and downloaded from
[Kaikki.org](https://kaikki.org/dictionary/rawdata.html) on 2026-10-07.
Input: `https://kaikki.org/dictionary/downloads/de/de-extract.jsonl.gz`,
last modified 2026-10-03; SHA256:
`2e66f18a093e94b29b04733d0222625695a3d5ed199e700059193895490dfb19`.
The dictionary forms and Wortag's derived dictionary subset are distributed under
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
Original entries and contributor histories are available at
`https://de.wiktionary.org/wiki/<lemma>` and each entry's **Versionsgeschichte**.
`Scripts/noun_dictionary.json` preserves the source credit and selected lemmas.
The deck retains this attribution in `nounArticleCredit`.

Wortag selects the first nominative article for common usage, resolves ambiguous
inflections to ordinary lemmas, excludes personal/place names that normally take
no article, and retains relevant alternative meanings for See, Teil and Leiter.
Inflected cards display the article with the dictionary form, while the original
surface word remains the sentence-highlight target. Some older spellings map to
their modern dictionary heading. These are Wortag's selection/presentation changes.
Explicit supplementary forms for productive nominalizations are CC0 and follow
the [IDS grammar's nominalization rules](https://grammis.ids-mannheim.de/rechtschreibung/6194).
The dictionary parser and grammar references are needed only at build time;
the app and widget continue to work entirely offline.

Frequency filtering does not amount to a linguist's review of every sentence.
The corpus includes word inflections and occasional regional or uncommon usage.

## Practical deck selection (1.0.6)

`Scripts/practical_words.txt` is Wortag's editorial selection, dedicated to CC0.
Difficulty targets mostly B1–C2 and is estimated editorially; it is not a
word-by-word certified CEFR classification. The validation index in
`Scripts/practical_dictionary.json` is derived from the same German Wiktionary
extraction credited above and remains CC BY-SA 4.0. It records only dictionary
lemmas and parts of speech, without copying dictionary examples or definitions.
The 1,642 active cards retain their existing sentence credits and noun articles.
The 8,358 excluded cards are archived to retain saved IDs and learning records.

## Learning dictionary (1.1.0)

`Scripts/learning_dictionary.json` and each active card's `dictionary` field
contain definitions, sense-matched English glosses, nominative plurals and
explicit verb forms selected from the same pinned German Wiktionary extract
credited above (SHA256 `2e66f18a093e94b29b04733d0222625695a3d5ed199e700059193895490dfb19`).
They remain **CC BY-SA 4.0** with credit to German Wiktionary contributors and
Tatu Ylönen / Wiktextract / Kaikki.org. All 1,642 active cards have a definition.
The deck embeds the source, checksum, credit and license in
`learningDictionaryCredit`. The app links each entry to Wiktionary, where its
contributor history is available.

Wortag selects at most three non-archaic senses, matches translations by source
sense index, removes unrecorded forms, adds presentation labels and masks the
headword in practice clues. Dictionary example sentences and audio recordings
are not copied. The independently authored preposition/case usage notes in
`Scripts/learning_dictionary.py` are dedicated to CC0. Pronunciation uses the
German speech voice installed on the user's Mac; no recorded audio is bundled.
