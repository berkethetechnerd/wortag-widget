# Version 1.1.0 branch review — 9 October 2026

Reviewed the five additions against existing discovery, reminders, history,
offline data and local installation. Version 1.1.0 is build 10. The branch
retains all 10,000 original IDs and the 1,642 active noun/verb lemmas.

## Feature use cases and fixes

| Area | Behavior reviewed | Improvement or safeguard |
| --- | --- | --- |
| Dictionary | Read meanings, noun plurals, verb forms and selected case/preposition notes from Today or any library detail. | Every active card has a definition. English glosses stay with their source sense; plurals are nominative and verb forms are explicit source records. Missing forms are not guessed. Entry links and bundled credits preserve attribution. |
| Pronunciation | Speak a word or sentence at normal/slow speed, replace playback, stop, or use the large widget's Listen link. | An app-owned synthesizer survives playback. An old finish/cancel callback cannot stop a new utterance. Missing German voices produce an actionable message in both word details and revealed Practice. No microphone permission is needed. |
| Recall | Open a due/new question or select a specific word, reveal, grade and continue. Use the same flow in every widget size. | Reveals do not record answers. Persistent question tokens and the interprocess lock prevent duplicate/stale grades across app and widget instances. Browsing cannot advance a graded word's schedule. Future reviews wait until due, while discovery continues indefinitely. |
| Migration | Open existing version 1 progress. | The first upgrade preserves the exact original bytes in a one-time backup, then adds optional version 2 fields. History, explored IDs and existing review schedules survive; previous browsing does not invent recall statistics. Invalid/unsupported progress stays preserved and shows an error. |
| Notifications | Opt in, choose time/weekdays, change or disable reminders, refuse permission and handle a failed save. | Startup never asks permission. Stable weekday request IDs replace previous schedules; disabling cancels them. A failed preference write attempts to restore the previous schedule. A failed UI refresh after a successful commit does not roll back that schedule. Unreadable progress does not cancel an existing OS schedule. Notification routing retains the practice request and injects an action to reopen/reuse the main window. |
| Statistics | Track daily/lifetime graded answers, self-rated recall, goals, weekly activity and recent difficult words. | Only grades count. Archived IDs are excluded from active due counts and difficult-word links. Local calendar days handle midnight/DST; Gregorian date keys remain stable when regional calendar settings change. Aggregate validation rejects overflow before statistics are computed. |

The interval ladder is centralized. Again uses one additional learning step or
ten minutes; Hard steps back, Good advances once and Easy twice, with bounded
stages. Existing exposure reminders continue to work until a word receives a
graded schedule. A learning step can be a new discovery card or a graded answer.

Practice-mode timelines no longer advance hidden discovery history or explored
counts. An unanswered question remains stable across refreshes. If Practice is
empty, its refresh policy uses the earliest active review date; a fresh snapshot
prepares a due question without recording an answer or advancing its interval.
The refresh preference still controls automatic updates, and manual checks work
when it is disabled. A regression covers idle refreshes and time-based resumption.
Practice reading regions and empty spaces use the same in-place refresh intent
as discovery, preserving the existing behavior that word/background clicks do
not open the app. Refresh-space presentation is shared between both modes.

## Different sizes, appearances and devices

The first compact Practice layout placed grading after all dictionary details
and examples. The final view puts grading directly below the revealed answer
and keeps details in a disclosure section. The original reminder time picker
widths truncated values; the final controls display their numeric values.
Sidebar spacing accommodates all six sections at the existing minimum window
size. Pages scroll, cap their content width and retain centered pane margins.

Native fixtures cover 18 app states at 780×590, 900×690 and 1200×800 points:
empty/saved/search/detail library states, long nouns, translated Today,
hidden/revealed Practice, empty/populated Progress and enabled/disabled reminder
settings. Widget fixtures cover 36 states across small, medium and large, with
hidden/revealed Practice, full color/accented/vibrant modes, long words,
translations, load errors, asymmetric margins and 1×/2× scales. Compact widgets
intentionally limit clue/example lines to leave the controls usable.

The signed Release app contains both arm64 and x86_64 executables and targets
macOS 14. GitHub Actions also builds, tests and renders the production views on
macOS 15 Apple Silicon and Intel runners. Renderers use fixture repositories and
preview services, without real progress, speech or notification side effects.

## Architecture and maintainability

The learning state and grading rules remain independent of SwiftUI, file access
and platform services. `LearningStore` owns migration, locking, validation and
atomic persistence. `LearningRepository` is the app model's replaceable storage
boundary. `ProgressSummary` computes statistics separately from the view.

`ReminderModel` owns opt-in/reconciliation behavior through the injectable
`ReminderScheduling` protocol. `MacReminderScheduler` implements OS permission,
calendar requests and delivery callbacks. The window-opening action is injected
by the view rather than implemented in the learning model. `SpeechController`
owns one retained synthesizer and its playback lifecycle.

Practice, Progress, Settings and dictionary details each have a dedicated view.
`WordDetailsView` and pronunciation controls serve Today and library details,
including the optional expanded Practice details. Widget intents share one
store/action/reload helper and use the same grading policy and persistence as
the app. The extension excludes app presentation/platform services. Dictionary
rebuilds use a saved metadata index with recorded provenance and fail for missing
active IDs instead of silently installing an incomplete dictionary.

These boundaries apply single responsibility and dependency inversion where
substitution is useful. Shared scheduling tables, ordering, word details,
pronunciation controls and intent execution avoid duplicated behavior. Further
practice policies or platform services can be added without replacing storage
or rewriting the UI. Protocols are not added to every small value/view solely
to increase abstraction.

The first CI run caught a chained difficult-word sorting expression that older
Swift compilers could not type-check within their limit. Explicit intermediate
values and a simple comparator remove that compiler dependency; regression
assertions cover the resulting scores and stable tie ordering.

Intel CI also exposed a Swift Charts Metal assertion in the virtual GPU used
for offscreen Progress previews. The seven-day activity chart now uses ordinary
SwiftUI shapes with explicit counts and accessible day labels in production,
avoiding a GPU-dependent chart renderer rather than skipping that layout check.

## Verification

- **41 Swift tests pass locally**, including the original 24 regressions and
  grading/idempotency, concurrent writers, migration backup, interval bounds,
  dictionary clues/forms, notification opt-in/denial/cancellation/save failures,
  window-routing callbacks, graded-only statistics, midnight/DST/calendar
  changes and aggregate overflow.
- **15 Python tests pass**, including full-deck example diversity, practical
  lemmas/exclusions, article checks, dictionary coverage/identity preservation,
  nominative plurals and sense-matched translations.
- The universal Release build succeeds. Both installed targets pass strict
  signature verification, and the canonical widget is registered as **1.1.0**.
- All **54 native layout fixtures render successfully**; widget captures reject
  empty reading areas. Representative compact/wide views were visually checked
  and the README screenshots were updated from fixture renders.
- The actual installed app was checked for dictionary display, Practice reveal
  controls, Progress and disabled reminder settings. Normal and slow speech
  start playback; the widget's pronunciation URL also opens the app and starts
  speech after closing its window. OS logs confirm successful widget timeline
  loads. No notification permission was requested for these checks.
- Migration on the local installation preserved existing learning data. The
  scratch revealed question used for the UI check was removed under the store's
  lock while retaining the original progress/preferences. No test answer or
  invented recall history was added to the user's statistics.

## Coverage limits

Notification scheduling failure/permission branches and routing are tested with
an injected scheduler. Real permission granting, scheduled banner delivery and
notification clicks under Focus were not exercised on this Mac; reminders remain
off until the user opts in. Widget timeline loading is observed, but physical
reveal/grade clicks in the complete desktop host still need smoke testing across
supported macOS versions and accessibility configurations.

No macOS 14 runtime was available locally. Deployment compatibility, local
universal builds and the macOS 15 CI matrix do not prove behavior on every
display, OS or installed voice. Native fixtures cover representative layouts;
they cannot reproduce every WidgetKit rendering transformation or refresh delay.

Definitions can be technical and polysemous; a clue is not a unique translation.
Difficulty remains an editorial B1–C2 estimate. Some forms and English glosses
are absent in the source; usage notes cover selected constructions, not an
exhaustive grammar dictionary. Recall percentages are user ratings, not objective
test scores. Locally signed builds retain the existing shared-folder entitlement;
a public binary release still needs the documented team signing/App Group setup.
