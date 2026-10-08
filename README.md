# Wortag

A native macOS desktop widget for a little German, every day. Built with SwiftUI,
WidgetKit and App Intents. Requires macOS 14 or newer.

## Start using it

Open `build/Wortag.app`, then right-click your desktop → **Edit Widgets** → search
**Wortag** → add a widget. Medium shows up to two German examples; large shows up to
three German examples, or two with English translations. Small shows one compact
example.
If the widget doesn't appear immediately, quit and reopen the widget gallery.
The app's **Add your widget** button also explains setup.

The project uses local ad hoc signatures; it is built for this Mac, without an
Apple Developer subscription. It is not notarized for distribution to other Macs.
The local build uses a dedicated progress folder shared by its two sandboxed
components. It does not request access to other apps' data.

## How learning works

- **Previous** replays the actual card history. **Next** moves forward through
  that history before selecting a new card. Command–Option–Left/Right also work in the app; plain arrow keys remain available for editing searches.
- New cards come from a shuffled bag. A new shuffle begins when the bag is used
  up, so learning continues indefinitely. Unmarked words are not repeated within
  one pass, and immediate repeats are avoided when another word remains in the bag.
- **Remind me** / the bookmark button schedules the displayed word within four
  new cards or one hour, whichever makes it due first. Due words take priority
  over random discovery. Repeated clicks do not add duplicates or postpone it.
- Reviews then recur after 12, 36, 108, 324 and 972 new cards, or 1, 3, 7, 21 and
  60 days. The final interval repeats. Clicking Remind me again brings a word
  back to the first interval. This is repeated exposure, not a graded recall test.
- If several words become due together, they appear over successive Next
  actions. A one-word or fully marked deck remains usable even if early repeats
  are necessary.
- The widget requests automatic rotation about once an hour. macOS decides the
  actual refresh time; manual buttons update immediately through App Intents.
  You can disable automatic rotation in the app. Browsing history resets the
  hourly refresh timer and does not advance the review counter.
- Clicking the word or background refreshes the card in place. Previous, Next
  and Remind me also work without opening the app. The Examples link opens its
  source website; the explicit Open Wortag link is available if loading fails.

All instances use the same current card and schedule. History keeps the latest
5,000 cards; the explored-word count persists. The companion app includes a
searchable vocabulary, reminder management and optional English translations.
Noun headings include their definite article: **die Genehmigung**, **der Mietvertrag**,
**das Werkzeug**. Articles also appear in vocabulary and reminder lists. Verbs
use their infinitive dictionary form.

## Offline data and privacy

The active deck contains **1,642 practical noun and verb lemmas**, targeting mostly
**B1–C2**. This is an editorial difficulty estimate, not a certified CEFR label
for every word. A reviewed allowlist (`Scripts/practical_words.txt`) selects
objects, useful processes and actions for home, work and public life. A recorded
German Wiktionary subset validates the part of speech and dictionary form.
Beginner targets such as Wohnung, conjugation/plural duplicates, personal names,
countries and nationalities are excluded. Each active card keeps two or three
varied examples and English translations where available.

The original 10,000 card identities remain bundled as an archive. Excluded
cards leave the library, shuffled bag, automatic reviews and Previous/Next
navigation. Their history, explored IDs and reminder records remain saved,
so changing the deck does not erase progress. The displayed explored count
includes only active words; reminders for retained words keep their schedules.
The smaller active deck continues reshuffling indefinitely.

Examples come from the ManyThings/Tatoeba corpus. It compares
German and English content stems after removing pronouns and function words,
rejecting grammatical rewrites. It searches the full sentence pool and never
fills a card with rejected near-duplicates. A larger Tatoeba export supplies
additional contexts; sixteen explicitly authored examples cover seven words.
Three legacy spellings use modern display forms while retaining their stable
card IDs. No API key, online account or
network request is needed at runtime. Clicking a source link opens its website.
See `DATA-LICENSES.md` for provenance and credits.

Learning progress lives in `~/Library/Application Support/Wortag/learning.json`.
Both targets remain sandboxed and receive read/write access only to that folder
through a home-relative file entitlement. The folder is accessible only to your
login user. The original App Group progress was preserved during the repair.
Writes are atomic and protected with a file lock across the app and extension.
Unreadable progress is preserved and reported instead of silently reset.

## Build and test

Xcode 15+ and XcodeGen are required to rebuild. The generated Xcode project is
included, and `project.yml` is the editable project definition.

```sh
bash Scripts/build.sh
bash Scripts/run.sh
swift test
```

`build.sh` uses Xcode's native local signing, so sandbox entitlements are present
before the app or extension is registered with macOS. Both the intermediate
product and installed copy are signed; only `build/Wortag.app` is left registered.
It stops previous builds before replacing their executable signatures.
For a Developer ID/App Store release, configure a developer team and provision
an App Group in both targets instead of using this local folder entitlement.
Do not mix local and team-signed variants in one installation.

To rebuild the vocabulary (build time only):

```sh
python3 -m venv .data-venv
.data-venv/bin/pip install wordfreq==3.1.1 nltk==3.9.2
curl -fL https://www.manythings.org/anki/deu-eng.zip -o /tmp/wortag-deu-eng.zip
curl -fL https://downloads.tatoeba.org/exports/per_language/deu/deu_sentences_detailed.tsv.bz2 -o /tmp/wortag-deu-detailed.tsv.bz2
.data-venv/bin/python Scripts/build_vocabulary.py /tmp/wortag-deu-eng.zip Resources/vocabulary.json --supplement /tmp/wortag-deu-detailed.tsv.bz2
.data-venv/bin/python -m unittest discover -s Scripts -p 'test_*.py'
```

When updating the corpus, update its version, checksum and notices as well.
The builder preserves IDs from the existing JSON. It validates all example
pairs before replacing the output atomically, and fails if a card lacks at least
two distinct contexts. NLTK's stemmers require no additional model downloads.
Runtime has no third-party package dependencies.

The vocabulary builder automatically applies the checked-in noun dictionary
subset and practical lemma selection. To edit the active words, edit
`Scripts/practical_words.txt` and run `python3 Scripts/practical_vocabulary.py
Resources/vocabulary.json`. New entries also require a validated dictionary
record and varied corpus examples. To regenerate that subset from the source recorded in DATA-LICENSES.md:

```sh
curl -fL https://kaikki.org/dictionary/downloads/de/de-extract.jsonl.gz -o /tmp/wortag-de-wiktionary.jsonl.gz
python3 Scripts/noun_articles.py Resources/vocabulary.json --extract /tmp/wortag-de-wiktionary.jsonl.gz
```

Running `noun_articles.py Resources/vocabulary.json` without `--extract` applies
the saved subset without downloading anything. Enrichment preserves all card
IDs, order, original word forms and examples, so learning history stays valid.

To check the widget layout with native SwiftUI rendering, without opening the
app or changing progress:

```sh
swiftc -parse-as-library -D WORTAG_RENDER Shared/*.swift Widget/WortagWidget.swift Scripts/NativePreview.swift Scripts/render_widget.swift -o /tmp/wortag-render
/tmp/wortag-render "$PWD/build/Wortag.app" /tmp/wortag-previews
```

This produces 18 PNG previews at the small, medium and large widget sizes,
including long nouns, translations, alternate foreground appearances, asymmetric
margins, load errors and 1×/2× rendering. The
production card view is shared with the renderer. The reading area and empty
spaces use separate refresh buttons rather than an overlapping background button.

The Reminders page uses a fixed top heading and a centered empty state. Search
appears once words are saved, and a no-results search offers Clear search.
The empty state links directly to today's word. Content width is capped and
centered within the main pane, with consistent margins as the window resizes.
Vocabulary uses the same page layout; searches reset when switching sections.

To render app layouts with native macOS controls and fixture data (no progress
reads or writes), including empty, saved, search and detail states:

```sh
swiftc -parse-as-library -D WORTAG_RENDER_APP Shared/*.swift Shared/Presentation/*.swift App/*.swift Scripts/NativePreview.swift Scripts/render_app.swift -o /tmp/wortag-render-app
/tmp/wortag-render-app "$PWD/build/Wortag.app" /tmp/wortag-app-previews
```

## Code structure and regression checks

`Shared/LearningState.swift` implements history, shuffled discovery and spaced
reviews without UI or file access. `ReviewSchedule.swift` owns the learning
intervals and review ordering. `LearningStore.swift` persists that state under
an interprocess lock and validates saved data before using it. `Vocabulary.swift`
loads and validates the offline deck, caching its active IDs.

The app model depends on `LearningRepository`, allowing recovery and write
failures to be tested with a substitute repository. Widget reloads are injected
by the app entry point. App views have separate responsibilities for navigation,
the sidebar, today's word, the library and setup. `WordDetailsView` shares the
article, examples, translation and attribution presentation between both pages;
`LibrarySection` shares filtering, search and schedule ordering with tests.
The widget uses the same learning domain, store and highlighting helper, without
compiling app presentation code into the extension.

GitHub Actions runs the Swift and Python suites, builds and verifies both signed
targets, and uploads layout fixtures on macOS 15 Apple Silicon and Intel runners.
The renderers exercise production views without reading or writing progress.
Their previews supplement manual desktop-widget checks; they do not reproduce
WidgetKit's complete host, rendering transformations or refresh scheduling.
See [REVIEW.md](REVIEW.md) for findings, coverage and remaining limits.
