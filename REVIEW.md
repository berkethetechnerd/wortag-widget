# Branch review — 8 October 2026

Reviewed the learning flows, app and widget presentation, local storage,
data quality, and code structure. The fixes retain all card IDs and the saved
learning-state format. The local installation is build 9 (1.0.8).

## Findings addressed

| Area | Problem found | Improvement |
| --- | --- | --- |
| Startup | A failed repository initialization left Try again without a repository to retry. | The model recreates the repository after a failed initialization, clears recovered errors and reloads widgets. |
| First use | Next on an uninitialized store selected two cards, skipping the first. | Initialization reports whether it selected a card, so the first action advances once. |
| Storage | Valid JSON with an invalid cursor, review stage or counter could reach unsafe indexing or arithmetic. | Semantic validation rejects invalid schedules before use and preserves the file. |
| Deck loading | Missing examples or duplicate IDs could cause a rendering/indexing failure. | Vocabulary validation fails with an actionable error before constructing lookups or views. |
| Search | Global plain arrow shortcuts competed with text-field editing. | Word navigation uses Command–Option–Left/Right. Search trims whitespace and matches articles, case and diacritics. |
| Reminders | Alphabetical ordering hid the review schedule; long words competed with due information in one row. | Scheduled order uses the same comparator as learning. Each row places its schedule below the word. |
| Compact widgets | Long noun headings lost their endings. Large translated examples could crowd the controls. Fitting views inside intent labels produced missing content in native renders. | Headings wrap and scale. Explicit example limits leave space for controls: one in small, two in medium, three German-only or two translated in large. Small error cards retain the recovery link. |
| Appearance | Fixed text colors and symmetric padding assumed one widget appearance and margin geometry. | Alternate modes inherit primary/secondary colors, while each system margin is applied separately. A newer review icon was replaced with an older system symbol. |
| Polling | Unchanged snapshots were published repeatedly, and periodic refresh could obscure an action error. | Equal snapshots are not republished. Polling runs only while the app is active and has no displayed error. The date header refreshes independently, including when rotation is disabled. |
| Example variety | Sampled Austausch examples described almost the same situation despite passing lexical checks. | Three authored examples cover battery replacement, exchanging ideas and a school exchange. They are credited as Wortag originals and preserved by the builder. |
| Maintainability | One app file mixed storage/model setup, navigation and every page. Learning intervals were duplicated. | Separate views, an injectable repository boundary, shared word details/search and a single scheduling policy reduce coupling and duplication. |
| Regression coverage | Builds and layout checks depended on this local Mac. | A GitHub Actions matrix tests, signs, builds and renders on both Apple Silicon and Intel macOS 15 runners. |
| Preview portability | ImageRenderer produced native-control placeholders on macOS 15 and a Metal assertion in the Intel CI environment. | Both renderers share an offscreen NSHostingView capture helper that includes native controls. |

## Verification

- 24 Swift tests pass locally. Coverage includes shuffle exhaustion, history
  replay, step/time reviews, repeated reminders, archived IDs, multiple writers,
  concurrent automatic refresh, malformed state/decks, first launch, reminder
  ordering, search, startup retry and write-failure reporting.
- 12 Python tests pass, including whole-deck checks for example variety and
  target words, noun articles, practical lemmas and excluded beginner/place words.
- The Release app and widget build successfully for macOS 14 deployment on the
  local Apple Silicon Mac. Both installed targets pass strict signature checks;
  only the canonical local extension is registered, at version 1.0.8.
- Native fixtures cover 11 app layouts at 780×590, 900×690 and 1200×800, plus
  18 widget layouts across all three supported sizes. They include empty,
  populated, search and detail pages, long nouns, translations, errors,
  asymmetric margins, alternate foreground modes and 1×/2× scales.
- Production views are rendered with fixture repositories. The layout and test
  helpers do not modify live progress. Installation retains the existing file.

The preview helper captures its own offscreen view hierarchy, without opening
a window or taking a desktop screenshot. This also addresses Apple's documented
[ImageRenderer limitations for native controls](https://developer.apple.com/documentation/swiftui/imagerenderer).
Widget renders reject an empty reading region rather than treating every
successfully encoded PNG as a valid layout.

## Architecture

The learning state is a pure domain model. Persistence owns locking, decoding,
validation and atomic writes. Vocabulary owns the deck and ID indexes. The
main-actor app model adapts repository results into presentation state; the app
entry point supplies WidgetKit integration. Individual views receive the data
and actions they need. Widget App Intents use the same repository/domain rules.

This applies single responsibility and dependency inversion at the boundary
that needs substitution, without creating a protocol for every small view.
Review intervals, reminder ordering, library search, highlighted text and word
details each have one implementation. Future storage or UI changes can reuse
the domain and substitute the repository independently.

## Coverage limits

Native previews verify the views and layout branches, rather than every behavior
of the desktop WidgetKit host. Physical clicks, screen-reader navigation,
permission prompts and automatic refresh timing still need a desktop smoke test
on each supported macOS release. macOS 14 remains the deployment target; no
macOS 14 runtime was available for this review. CI validates builds and tests on
macOS 15, rather than every display or hardware configuration.

Compact widgets intentionally show fewer examples or truncate sentences when
space is limited; the full examples remain available in the app. Difficulty
levels are editorial estimates. Lexical diversity tests catch conjugation and
pronoun rewrites but cannot certify semantic variety or translation quality
for every corpus sentence.

The shared-folder entitlement and ad hoc signing are for local installations.
A distributable release requires the documented team signing/App Group setup.
