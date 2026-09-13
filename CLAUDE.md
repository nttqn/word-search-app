# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What this is

A Flutter Android word-search game (`WordHunt - Tra Từ`), Vietnamese UI,
built as an English vocabulary trainer for Vietnamese learners rather than a
generic puzzle: finding a word in the grid reveals its Vietnamese meaning right
underneath it in the clue list. AdMob banner + interstitial ads are wired in
(currently Google's public **test** ad unit IDs — this project has no AdMob
account of its own yet, unlike its siblings). A Play Games Services leaderboard
(one per level) is wired in code — see "Leaderboard" below — but not yet
functional: the leaderboard IDs are still placeholders since no Play Console
project exists for this app yet. No sound — deliberately scoped out for v1
(see "Scope decisions" below).

Dart package name: `word_search_vocab`. Android application ID:
`com.trungsmail.word_search_vocab`. Both deliberately **not** renamed to
match the "WordHunt - Tra Từ" display name (chosen 2026-09-13, was
"Word Search - Học Từ Vựng") — those are internal identifiers, not the
user-visible name, and changing either is a much bigger/riskier operation
(every `package:word_search_vocab/...` import; the Play Store listing
identity, if this were ever published under the old ID) than the
display-name change that was actually asked for. Same precedent as
block-puzzle-app's own package-name-vs-display-name split. The display name
lives in three places, all kept in sync: `MaterialApp.title` (`lib/main.dart`),
the home screen's title `Text` (`lib/screens/home_screen.dart`), and the
Android `android:label` patched in by `build-apk.yml`.

There is no native `android/` (or `ios/`/`web/`) directory committed — see
"Android project is generated, not committed" below, same pattern as this
account's other games (chess-app, dino-egg-shooter, number99-app,
block-puzzle-app).

## Commands

```
flutter pub get
flutter analyze
flutter test                       # grid_generator + word_search_engine unit tests
flutter run -d chrome              # fastest way to eyeball gameplay changes
flutter build apk --release        # debug-signed test APK
flutter build appbundle --release  # AAB for Play Store upload (needs real signing config)
```

Real APK builds happen in CI: push to `main` (or `workflow_dispatch`) runs
`.github/workflows/build-apk.yml`.

## Android project is generated, not committed

Same pattern as this series' other games: `android/`, `web/`, etc. are
gitignored, and CI regenerates `android/` via `flutter create` then patches in
the AdMob App ID, INTERNET permission, app label, minSdk/compileSdk bump, R8
WorkManager keep rules, launcher icon, and (if secrets are set) release
signing. See `build-apk.yml`'s inline comments for the exact why on each
step — copied verbatim from the validated block-puzzle-app pattern, minus the
Play Games Services steps (not needed here).

**Gotcha that broke the very first CI run**: `flutter create .` also
(re)writes `test/widget_test.dart` whenever that file is missing from the
checkout, independent of the `--platforms` flag — its boilerplate `testWidgets`
references a `MyApp` widget that doesn't exist in this project (the real root
widget is `WordSearchApp`), so the regenerated file fails to compile and the
`flutter test` step fails, skipping the build/upload steps after it. Deleted
locally on 2026-09-03 but not guarded against in CI until the first push's
run actually failed this way. Fixed by `rm -f test/widget_test.dart`
immediately after the "Generate Android platform project" step. If a future
`flutter create` invocation is ever added/changed in this workflow, re-check
whether it still needs this same cleanup line.

## Scope decisions (v1)

- **No sound.** Every sibling game bundles WAV/MP3 sound effects, but those
  came from user-supplied audio or ffmpeg-based generation — neither is
  available for this project, and none was requested. Can be added later the
  same way block-puzzle-app added its leaderboard after the fact.
- **No bespoke background *image*.** `AppBackground` (see "Icon & title art"
  below) is still a plain gradient `Container`, not `Image.asset` — its
  colors are now sampled from the real title art, but a full illustrated
  background image itself would need ImageMagick/a real image tool this
  machine doesn't have (see `[[user_dev_machine_tooling]]`).

## Architecture

**`lib/models/level.dart`** (`VocabLevel` enum: basic/intermediate/advanced/
expert) is the single source of truth for each tier's grid size, words-per-
puzzle count, and whether diagonal placements are allowed (`basic` is
orthogonal-only — → ← ↓ ↑ — so the very first tier stays easy to scan; every
other tier allows all 8 directions, diagonals included in both reading
directions).

**`lib/data/word_banks.dart`** holds ~50 hand-authored `VocabWord{word,
meaningVi}` entries per level, difficulty-graded to roughly match that level's
word-length range. Each new puzzle (`GridGenerator.generate`) picks a random
subset sized to `level.wordsPerPuzzle`, so replaying a level surfaces
different words rather than the same fixed puzzle every time.

**`lib/game/grid_generator.dart`** (pure Dart, no Flutter imports — same
Flutter-free-engine split as block-puzzle-app's `GameEngine`, for unit-
testability without pumping widgets): places longest-first... actually
words are placed in whatever shuffled order the candidate list comes in
(not sorted by length) since with a ~50-word bank and 6-12 words needed per
puzzle there's enough room that placement order hasn't mattered in practice;
revisit this if a future denser bank/grid combination starts dropping words
often. Each word gets up to 60 random `(row, col, direction)` attempts;
letter-matching overlaps are allowed (so two words can cross), a word that
never fits within its attempt budget is silently dropped and the next
shuffled candidate is tried instead — this is why `WordBanks` needs
meaningfully more entries per level than `wordsPerPuzzle` actually requires,
so a few dropped attempts never starve a puzzle.

**`lib/game/word_search_engine.dart`** (`WordSearchEngine extends
ChangeNotifier`) owns one puzzle attempt's mutable state: the generated grid,
`foundWords`, `score`, `elapsedSeconds` (ticked by an internal
`Timer.periodic`, cancelled on completion/dispose/pause-aware no-op — same
`_tick` "no-op while paused" pattern as block-puzzle-app's bomb countdown),
and `hintsRemaining`/`highlightedHintCells`.
- `trySelect(List<Cell> path)` checks the dragged path against every
  **unfound** word's actual cell sequence, matching **either direction**
  (forward or `.reversed`) so a player can drag from either end of a word —
  returns the matched `PlacedWord` or `null`. Deliberately returns a value
  synchronously rather than using block-puzzle-app's `popupSeq`-style "new
  event" counter pattern: the call always originates directly from
  `GridWidget`'s own `onPointerUp` handler in the same frame, so there's no
  cross-rebuild event-detection problem to solve here the way there was for
  `GameEngine`'s independently-timed popups/explosions.
- `useHint()`/`clearHint()` are similarly synchronous and caller-driven —
  `GameScreen` (not the engine) owns the `Future.delayed(seconds: 2)` that
  calls `clearHint()`, matching the "call happens in direct response to a UI
  event, no seq-counter needed" reasoning above.
- Score: `+10 × word length` per word found, plus a one-time
  `max(0, 300 − elapsedSeconds) ~/ 5` time bonus added the moment the last
  word completes the puzzle (`isComplete` flips true and the ticker is
  cancelled in the same `trySelect` call).

**`lib/widgets/grid_widget.dart`**: a single `Listener` (not `GestureDetector`
— pointer down/move/up give direct control without a drag-recognizer's
slop/velocity heuristics fighting the deliberately snapped selection) over
the whole board converts pointer position → board-local cell coordinates via
`RenderBox.globalToLocal` + `(local / cellSize).floor()`, the same technique
proven in block-puzzle-app's `board_widget.dart`. `_straightLinePath` snaps
whatever cell the pointer is currently over to the nearest of the 8
directions from the drag's start cell (exact axis/diagonal match used
directly; an off-axis drag is snapped to whichever axis dominates by more
than 2:1, or to the diagonal if neither does) — this is what lets a slightly
wobbly real-finger drag still select a straight word instead of failing on
any pixel wobble. Found-word cells are colored per-word (cycling a 12-color
palette keyed by the word's index in `grid.placedWords`, recomputed each
build — cheap at ≤12 words, so no cached state needed); a wrong release
briefly flashes the dragged path red (250ms, self-clearing) before resetting.

**"+N" score popup** (`_GridWidgetState`, `_ScorePopup`/`_addScorePopup`/
`_buildPopup`): on a correct release, `_onEnd` diffs `engine.score` before
vs. after calling `trySelect` — rather than recomputing "word length × 10"
here too — specifically so the popup automatically includes the one-time
completion time-bonus when the match also happens to finish the puzzle,
without this widget needing to duplicate that formula (see the engine's
scoring note above). Each popup gets its **own** `AnimationController`
(`_GridWidgetState` uses `TickerProviderStateMixin`, not
`SingleTickerProviderStateMixin`, specifically so more than one can be
in flight — back-to-back fast finds each show their own rising "+N" instead
of one clobbering another, same reasoning as block-puzzle-app's
`_activePopups` list), rendered at the midpoint of the matched word's cells,
rising ~46px and fading out over the animation's last 40% before removing
itself from `_popups` in `whenComplete`.

**`lib/widgets/word_list_widget.dart`**: the actual teaching surface — the
English word is always visible as the clue (matching genre convention), and
finding it reveals `meaningVi` right underneath with a strikethrough on the
word itself, rather than hiding meanings behind a separate lookup step.

**Back button = pause, not exit**: `GameScreen` uses `PopScope(canPop: false,
onPopInvokedWithResult: ...)` — if the puzzle isn't complete, pauses the
engine (freezes the timer, blocks further `trySelect`/`useHint` calls) and
shows a pause dialog (Tiếp tục / Về trang chủ) instead of popping mid-puzzle;
mandatory rule for every game in this series (see
`[[feedback_back_button_pause]]`).

**Ads (`lib/services/ads_service.dart`)**: same singleton/no-op-on-web pattern
as every sibling, but with Google's public **test** ad unit IDs hardcoded
rather than real ones — there's no AdMob account for this project yet. Swap
in real IDs from this project's own AdMob account the same way block-
puzzle-app did once one exists; the `ADMOB_APP_ID` GitHub secret (manifest
Application ID) is a separate value already wired into `build-apk.yml`.
Interstitial shows roughly every other completed puzzle, not after every one.

**Leaderboard (`lib/services/leaderboard_service.dart`)**: Google Play Games
Services, one leaderboard per `VocabLevel` (scores aren't comparable across
levels — different grid sizes/word counts — same reasoning `ScoreService`
already uses for tracking "best" per level). Android-only, unlike
block-puzzle-app's dual-platform (Android + iOS/Game Center) version of this
same class, which this file is modeled on — this project has no iOS target.
All four `_androidLeaderboardIds` values are still `REPLACE_...` placeholders
(no Play Console project exists for this app yet); `_isConfigured` gates
every real call on them, so every call safely no-ops until real IDs are set —
the game stays fully playable, `ScoreService`'s local "Điểm cao: N" keeps
working exactly as before, and the trophy button on each level card falls
back to a "Bảng xếp hạng chưa khả dụng." SnackBar. `GameScreen.initState()`
calls `LeaderboardService.signIn()` unawaited (mirrors block-puzzle-app's
`signIn()`-moved-out-of-the-engine precedent, for the same reason: keeps a
future engine-level test from ever triggering a real platform-channel call).
`_onPuzzleComplete()` calls `submitScore(level, score)` unawaited right next
to the existing `ScoreService.saveBest` call. To make this functional: create
a Play Console project for this app, create 4 leaderboards (one per level),
paste their generated IDs into `_androidLeaderboardIds`, and set the
`PLAY_GAMES_APP_ID` GitHub secret (patched into the manifest by
`build-apk.yml`, same mechanism as `ADMOB_APP_ID`).

**Icon & title art** (`assets/icon/icon.png`, `assets/title/title.png`):
real user-supplied branded art, replacing the original PowerShell-drawn
magnifying-glass placeholder icon on 2026-09-13 — both are the letter-tile
"WordHunt / Tra Từ" logo (colorful cartoon alphabet blocks around a
magnifying-glass wordmark), the icon being the same art cropped to a square
with a baked-in gold rounded-corner border. Used directly with no editing
needed (no background removal / bounding-box crop, unlike the earlier
placeholder or the more involved icon-art pipelines documented in
`[[project_block_puzzle_app]]`) since both files arrived already
launcher/banner-ready. `title.png` is shown on `HomeScreen` via
`Image.asset('assets/title/title.png', width: 320)`, replacing the previous
plain-text "WordHunt" / "Tra Từ - Học Tiếng Anh" title+subtitle.

**`title.png`'s alpha channel fades toward its edges** (confirmed via a
PowerShell/System.Drawing pixel probe: corner alpha ~13-29, center-of-logo
alpha ~250) — it's a soft radial glow, not a hard-edged rectangle, so it's
designed to sit on a matching blue field rather than needing a transparent
background of its own. This is *why* `AppBackground`'s gradient was changed
from the original flat dark navy (`0xFF123B57`→`0xFF0B2436`) to colors
sampled from the art's own bright-center/darker-edge blue tones
(`0xFF3FB6F0`→`0xFF0B4E96`→`0xFF063867`, weighted mostly toward the darker
end via `stops: [0.0, 0.35, 1.0]` so white text elsewhere on the page —
word list, HUD, buttons — keeps enough contrast; only a bright accent
right at the top where the title sits) — without this change the image's
faded edges would blend into a mismatched dark background instead of the
bright sky-blue the art was actually drawn against.
