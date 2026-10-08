# Verification on the local Mac

Verified with Xcode 27.0 and macOS 26.7.1, Apple Silicon.

- Release build of the macOS app and embedded WidgetKit extension succeeds.
- Local code signatures for both bundles pass `codesign --verify --deep --strict`.
- The app launches and reads persistent progress from its dedicated local folder.
- `pluginkit` registers `de.wortag.app.widget`; the extension runs on this Mac.
- Nine Swift tests pass: shuffled coverage and 20,000 advances; actual history
  replay; reviews after 4/12/36 cards; reviews due by elapsed time; repeated
  reminder clicks; empty and single-word decks; concurrent store updates and
  persistence; preservation of corrupt progress; hourly rotation and disabling it.
- Full corpus checks validate 10,000 unique IDs, two or three distinct German
  examples per card, exact target-word occurrence and preserved attribution.
- Version 1.0.1 retains all existing card IDs and order, with 28,732 examples.
- Six Python diversity tests pass, including the reported Wohnung variants,
  pronoun/possessive/conjugation substitutions, bilingual comparison, distinct
  contexts, absence of duplicate fallback, and all 10,000 cards' example pairs.
- The new deck uses 662 additional German examples without bundled English
  translations and thirteen explicitly authored examples. Source credits and
  original-example labels are preserved.

On-screen inspection was blocked by automatic approval review. Widget placement,
rendered layout and clicking the native widget controls have not been visually
verified.

Version 1.0.2 repairs local installation and widget loading:

- Both targets keep App Sandbox and receive access only to
  `~/Library/Application Support/Wortag/`. The unprovisioned App Group entitlement
  is removed. Progress was copied unchanged before the repair.
- Xcode now signs both build products before Launch Services registration;
  unsigned intermediate apps no longer become widget launch candidates.
- The canonical installation is the only registered Wortag widget plug-in.
- macOS's widget host successfully launches the extension, loads progress and
  archives real medium and large timelines. The prior missing-sandbox error is
  gone. Runtime logs record successful timeline loads and reload completion.
- The nine learning-engine tests still pass.
- Relaunch checks show one canonical app process and no new sandbox-triggered
  shared App Data permission requests after migration. Existing history and
  reminder data match the pre-repair backup.

Version 1.0.3 adds noun articles:

- 4,114 noun cards include nominative articles from a recorded Wiktionary
  dictionary extract and explicit productive nominalizations. Inflections use
  a dictionary heading plus an In examples note. All 10,000 IDs, card order,
  original surface words and 28,732 examples match the previous deck exactly.
- App headings, vocabulary/reminder lists and widget headings use the same
  article display. Sentence highlighting keeps the original surface word.
- Fourteen Swift tests pass, including compatibility with older JSON, noun
  headings, inflected forms, alternative articles and the actual bundled deck.
- Ten Python tests pass, including primary dictionary articles, plural-only
  nouns, weak declension, nouns versus pronouns/names/verbs, idempotent enrichment
  and whole-deck sentence diversity.
- The Release build and both local bundle signatures pass validation.
- Restarting this project's widget extension resolves the cached previous-version
  process after upgrade. macOS then successfully archives the new large timeline;
  logs confirm successful reloads from the v1.0.3 installation. The build script
  now retires Wortag processes after installation as well as before it.
- History, cursor, reminders and seen-word data matched the pre-change backup
  immediately after installation. The subsequent scheduled hourly refresh appended
  one new word normally; earlier history and reminders remain intact. Relaunch
  produces no shared App Data permission requests.

Version 1.0.4 changes word/background clicks to refresh in place:

- Removed the whole-widget app-opening URL. A background RefreshWordIntent
  covers the widget surface, including margins; existing controls and source
  links remain above it. The intent reloads the current timeline without changing
  saved learning state and sets openAppWhenRun to false.
- The locally signed Release app and extension build successfully; all fourteen
  core Swift tests still pass.
- macOS registers the 1.0.4 plug-in and successfully archives/reloads the live
  large-widget timeline. Its decoded action metadata contains RefreshWordIntent,
  PreviousWordIntent, RemindWordIntent and NextWordIntent, all with
  openAppWhenRun=false. This verifies the delivered action configuration;
  clicking the rendered widget has not been visually tested.
- After triggering the initial reload, the companion app was closed so the
  installed desktop widget can be used independently.

Version 1.0.5 repairs the blank layout reported after that change:

- Removed the overlapping full-surface button. The reading area is now the
  visible label of its own refresh button. Navigation, footer and empty-space
  refresh regions occupy separate areas, with no full-size layer over the card.
- A native SwiftUI ImageRenderer harness uses the production WortagCardView.
  PNGs for 164×164, 344×164 and 344×344 point widgets were rendered and inspected;
  all show the noun/article, German examples and navigation controls. The large
  preview also shows the source link. This checks standalone native rendering,
  rather than a screenshot of the installed desktop widget.
- The signed 1.0.5 app and extension build successfully and register as the sole
  installed Wortag plug-in. macOS logs successful live timeline reloads. The
  companion app was closed after reloading; learning storage was not reset.

## Version 1.0.6: practical intermediate/advanced vocabulary

- A reviewed selection activates 1,642 unique dictionary lemmas (nouns and verbs),
  targeting mostly B1–C2 editorially. All active nouns have articles. Countries,
  nationalities, beginner targets and duplicate grammatical forms are excluded.
- All 10,000 original card identities, sentences and source credits are retained.
  Excluded cards are skipped in history navigation, random bags and due reviews.
  Saved history, explored IDs and archived reminder records remain intact.
- 17 Swift tests pass, including changed-deck navigation, reminder preservation,
  active progress counts, persistence and endless cycling. 12 Python tests pass,
  checking the selection, dictionary lemmas, noun articles and example diversity.
- Signed Release 1.0.6 builds successfully and is the sole registered Wortag extension.
- Production SwiftUI previews render the article and examples in all three sizes.
- macOS logs confirm successful small, medium and large timeline reloads after installation.
- Live progress retains its previous history prefix, seen IDs and reminder records; the current word is active (einreichen). Desktop clicks were not inspected in this data update.

## Version 1.0.7: centered Reminders layout

- The main pane fills the window vertically, with a top heading and centered,
  bounded content. Empty reminders hide the search field and redundant zero-count
  footer, and offer Explore today's word. Populated lists retain search; no-result
  searches offer Clear search. Switching sections clears the previous search.
- Native NSHostingView previews of production views cover 780×590, 900×690 and
  1200×800 windows, plus saved reminders, search misses and word details. Fixtures
  do not access live progress. Native control rendering avoids ImageRenderer's
  unsupported placeholders for List, TextField and ProgressView.
- The app and widget use the existing vocabulary, storage and review engine.
  The layout update adds no learning-state migration. Live click interaction is
  not part of these render checks.
- Signed Release 1.0.7 builds and installs successfully; only the canonical widget extension is registered. The app was reopened. Live history, reviews and seen IDs exactly match the backup taken before installation.
