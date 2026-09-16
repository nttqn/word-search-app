# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## What this is

A Flutter word-search game (`WordHunt - Tra Từ`), Android + iOS (iOS added
2026-09-14, see "iOS" below), Vietnamese UI,
built as an English vocabulary trainer for Vietnamese learners rather than a
generic puzzle: finding a word in the grid reveals its Vietnamese meaning right
underneath it in the clue list. AdMob banner + interstitial ads are wired in
with real ad unit IDs from the user's own AdMob account (set 2026-09-13). A
Play Games Services leaderboard
(one per level) is wired in code — see "Leaderboard" below — with real,
functional leaderboard IDs from a Play Console project the user created
2026-09-13. Sound effects (see "Sound" below) were
added 2026-09-13 once the user supplied real WAV/MP3 files — v1 originally
shipped without any, unlike its siblings.

Dart package name: `wordhunt` (every `package:wordhunt/...` import in
`test/`; `lib/` itself only ever used relative imports, so none of those
needed touching). Android application ID: `com.trungsmail.wordhunt`
(from `--org com.trungsmail --project-name wordhunt` in `build-apk.yml`'s
`flutter create` step). **Renamed 2026-09-13** from `word_search_vocab` /
`com.trungsmail.word_search_vocab` — initially deliberately left unrenamed
when the display name changed (same precedent as block-puzzle-app's
package-name-vs-display-name split: those are internal identifiers, not the
user-visible name), but the user later asked for this rename explicitly, and
doing it now — before any Play Store listing exists under the old ID — is
the safe time to do it; doing it *after* a real listing exists would create
an entirely different app rather than update the existing one. The Dart
class name `WordSearchApp` (`lib/main.dart`) was **not** renamed to match —
same reasoning as before, it's an internal identifier the user didn't ask
about, not the package name itself. The display name ("WordHunt - Tra Từ",
a separate thing from either identifier above) lives in three places, all
kept in sync: `MaterialApp.title` (`lib/main.dart`), the home screen's title
image (`assets/title/title.png`, via `lib/screens/home_screen.dart`), and
the Android `android:label` patched in by `build-apk.yml`. iOS bundle ID:
`com.trungsmail.wordhunt` (same string as the Android application ID, by
choice — the two are unrelated identifiers on different platforms, but
matching them avoids confusion).

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

## iOS

Android-only until 2026-09-14, when the user asked for an iOS build. This
machine is Windows with no Mac anywhere, so everything iOS happens through
CI on a `macos-latest` GitHub Actions runner (`build-ios` in
`build-apk.yml`), including signing — no local Keychain Access. **Recipe
copied verbatim from `[[project_number99_app]]`'s `build-ios` job**
(confirmed working end-to-end there, TestFlight upload included, after 5
rounds of CI-log-driven debugging) rather than re-deriving it — see that
project's own CLAUDE.md "iOS" section for the full failure-by-failure trail
(automatic signing's Development-vs-Distribution confusion, the Swift
Package Manager module-map issue, the "xcodebuild command-line overrides
apply to every target" root cause) if something here needs deeper context.

**Signing certificate is reused, not freshly generated**: Apple Distribution
certificates are scoped to the whole Developer Team, not to an individual
app, so the same certificate already created for `[[project_lunar_calendar_app]]`
(`amlich-distribution.p12`, Team ID `WGZYDZH4KR`) was copied into this
project as `wordhunt-distribution.p12` and reused directly — confirmed still
valid (`openssl pkcs12 -info`, expires 2027-09-08) before trusting it. Only
a **new App Store provisioning profile** was needed (per-app, unlike the
cert): App ID `com.trungsmail.wordhunt` + the same Distribution cert, named
"WordHunt App Store" in the portal, downloaded as
`WordHunt_App_Store.mobileprovision` and sanity-checked locally (`openssl
smime -inform DER -verify -noverify`) — confirmed `application-identifier`
= `WGZYDZH4KR.com.trungsmail.wordhunt`, `Name` = "WordHunt App Store", and
critically **no** `ProvisionedDevices` key (its presence would mean
Ad Hoc/Development, not App Store).

4 secrets drive signing: `IOS_DIST_P12_BASE64` (base64 of the `.p12`),
`IOS_DIST_P12_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64` (base64 of the
`.mobileprovision`), `APPSTORE_TEAM_ID` (`WGZYDZH4KR`). `build-ios`'s
`Import signing certificate` step checks the first two + the profile secret
early and sets a `configured` step output — every step after (cert install,
profile install, archive/export, TestFlight upload) is gated on it, so the
job cleanly degrades to compile-check-only (proves `google_mobile_ads`,
`games_services`, `flame_audio` all actually build for iOS) if they're ever
unset. The archive step uses `CODE_SIGN_STYLE=Manual`,
`CODE_SIGN_IDENTITY="Apple Distribution"`,
`PROVISIONING_PROFILE_SPECIFIER="WordHunt App Store"` (the profile's exact
name, not a UUID) plus `DEVELOPMENT_TEAM` — **all set via
`ios/Flutter/Release.xcconfig`, never as `xcodebuild` command-line
overrides**: a command-line override applies to *every* target the build
touches (every CocoaPods pod target too — `google_mobile_ads`,
`audioplayers_darwin`, `games_services`, `Pods-Runner`), and those targets
categorically don't support having a provisioning profile at all, so a
command-line override fails the whole archive with "does not support
provisioning profiles". `Release.xcconfig` is the *Runner app target's own*
`baseConfigurationReference`, which CocoaPods' generated pod xcconfigs never
reference — so only Runner sees these settings. `flutter config
--no-enable-swift-package-manager` (a Flutter **tool**-level setting, reset
every fresh runner) forces plugin resolution to CocoaPods instead of Swift
Package Manager for the same underlying reason — SPM package targets have
the identical "can't hold a provisioning profile" limitation.

`google_mobile_ads` needs `CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES
= YES` set in **both** the `Podfile`'s `post_install` target loop (for pod
targets) **and** `ios/Flutter/Debug.xcconfig`/`Release.xcconfig` (for the
Runner app target) — both required together, confirmed by testing the
Podfile patch alone first and watching the identical "non-modular header"
error persist.

**Leaderboard is dual-platform as of 2026-09-17** (see "Leaderboard" below
for the full writeup) — Game Center support was added once the user
created iOS leaderboards in App Store Connect, mirroring block-puzzle-app's
dual-platform `LeaderboardService`. `Install Game Center entitlement`
copies `tool/Runner.entitlements` into `ios/Runner/Runner.entitlements` and
wires `CODE_SIGN_ENTITLEMENTS` into `Release.xcconfig` — via the
xcconfig-scoped-to-Runner trick (never an `xcodebuild` command-line
override), same reasoning as the module-map fix and the signing settings
above. The App ID already had the Game Center capability enabled when it
was created (confirmed by decoding the provisioning profile's own embedded
entitlements — `com.apple.developer.game-center: true` was already
present), so no provisioning-profile regeneration was needed for this
addition.

**AdMob on iOS**: real iOS app + banner/interstitial ad units created
2026-09-15, same AdMob account as Android (publisher `9078637596840810`), a
separate app entry since ad units are platform-specific.
`lib/services/ads_service.dart`'s `bannerAdUnitId`/`interstitialAdUnitId`
are platform-aware getters (`_isIOS ? ... : ...`), **not** shared constants —
reusing the Android ad unit IDs on iOS would silently fail to serve, a real
bug `[[project_number99_app]]` hit this exact way on its own first iOS
build. `ADMOB_APP_ID_IOS` (the iOS `GADApplicationIdentifier`, patched into
`Info.plist`) is the separate iOS equivalent of the `ADMOB_APP_ID` secret —
also set now (`ca-app-pub-9078637596840810~1124589335`).

**TestFlight upload** (`xcrun altool --upload-app`, inside CI since there's
no Mac to run Transporter locally) needs 3 secrets
(`APPSTORE_API_KEY_ID`/`APPSTORE_API_ISSUER_ID`/`APPSTORE_API_KEY_P8`, an
App Store Connect API key) — set 2026-09-15, **reusing**
`[[project_number99_app]]`'s existing key (`AuthKey_K5QF38DL8P.p8`, Key ID
`K5QF38DL8P`) rather than generating a new one, since App Store Connect API
keys are Team-scoped, not per-app, same reasoning as the reused Distribution
certificate above. Copied into this project's root as `AuthKey_K5QF38DL8P.p8`
(gitignored). It's opt-in either way (only runs on a manual "Run workflow"
trigger with the `upload_ios` checkbox checked, never on a plain push),
mirroring how the Android job never auto-uploads the `.aab` to Play
Console — submitting a build to App Store Connect should be a deliberate
action. An App Store Connect app record for `com.trungsmail.wordhunt`
already existed (created by the user) before the first upload attempt —
needed for the upload to have somewhere to land.

**Launcher icon uses a separate config**, `flutter_launcher_icons_ios.yaml`
(not `pubspec.yaml`'s, which stays Android-only) — a shared config would
make `flutter_launcher_icons` try to write iOS icons into the Android job's
run (no `ios/` there) and vice versa, breaking both jobs at once. Same
`assets/icon/icon.png` source as Android; `remove_alpha_ios: true` handles
flattening the alpha channel iOS/App Store requires but the Android icon
pipeline doesn't need.

**Confirmed working end-to-end 2026-09-15**: `build-ios` produces a real
signed `wordhunt-release-ipa` artifact. The App Store Connect app record for
`com.trungsmail.wordhunt` was created by the user ahead of time.

**TestFlight upload gotcha**: App Store Connect rejects a re-upload of a
build whose `CFBundleVersion` (`pubspec.yaml`'s `+N` build-number suffix)
was ever accepted before, even if that upload came from a run that
otherwise looked unrelated — `altool` fails with `ENTITY_ERROR.ATTRIBUTE
.INVALID.DUPLICATE` / "The bundle version must be higher than the
previously uploaded version". Hit this on build `2` (`1.0.0+2`) after what
looked like the first `upload_ios: true` run — most likely two
`workflow_dispatch` runs were triggered close together and one succeeded
silently before the failing one's error was seen. **Fix is always the
same**: bump `pubspec.yaml`'s build number (the part after `+`) and push/
retry — there is no way to re-use a build number once App Store Connect has
accepted it, even after a failed follow-up attempt with that same number.

**A real failure on the first live attempt (2026-09-14)**: archive failed
with `error: Provisioning profile "WordHunt App Store" doesn't include
signing certificate "Apple Distribution: Ngo Thanh Trung (...)"` — exit code
65, no further detail from the GitHub API's check-run annotations (just the
generic exit code; the actual `error:` line had to come from the user
pasting the expanded step log manually, since this session has no
authenticated access to raw Actions logs). Root cause, confirmed by
comparing certificate serials with `openssl x509 -noout -serial
-fingerprint -sha1`: **two different certificates both displayed as "Apple
Distribution: Ngo Thanh Trung (WGZYDZH4KR)"** existed on the account — the
provisioning profile had been created against an orphaned one (likely from
an abandoned CSR generated earlier in this same session, before the user
said to reuse the existing lunar-calendar-app certificate instead; that
orphaned cert's private key was never saved), not the one in
`IOS_DIST_P12_BASE64`. The two were only distinguishable by expiration date
(2027-09-08 for the correct one vs. 2027-09-07 for the wrong one) since
both shared the exact same display name. Fixed by having the user
regenerate the provisioning profile against the correct certificate,
verifying the new profile's embedded cert serial matched the `.p12`'s
before updating the `IOS_PROVISIONING_PROFILE_BASE64` secret and retrying —
succeeded on the very next run. **Lesson for next time this comes up**: if
a provisioning-profile/certificate error occurs and there's any chance
multiple same-named Distribution certs exist on the account (e.g. an
abandoned CSR was ever uploaded), verify by comparing actual certificate
serials/fingerprints rather than assuming the display name alone identifies
the certificate uniquely.

**iPad**: `flutter create --platforms=ios` defaults to universal (iPhone +
iPad, `TARGETED_DEVICE_FAMILY` not restricted), which is why App Store
Connect asked for a 13" iPad display screenshot even though this UI was
only ever designed/tested at phone widths. A real screenshot at iPad Pro
13" resolution (2064×2752, rendered via the same Playwright/web-preview
technique used elsewhere in this project, **not** a real device/simulator —
this machine has no Mac) showed the phone-proportioned UI stretching
full-bleed: level cards/HUD/word list spanning the entire width, and —
worse — the letter grid's cells growing to match the available width while
`_CellView`'s font size stayed a flat constant, leaving tiny letters
lost in huge cells. **Fixed 2026-09-16** two ways, both in
`lib/screens/home_screen.dart` and `lib/screens/game_screen.dart`: (1)
wrap each screen's whole content in `Center(child: ConstrainedBox(
constraints: BoxConstraints(maxWidth: 480), ...))` — the same
"centered phone-width column on any screen size" pattern most simple
universal (non-tablet-redesigned) games use, rather than a true responsive
tablet layout; (2) `grid_widget.dart`'s `_CellView` now takes the actual
`cellSize` and derives its font size from it
(`(cellSize * 0.42).clamp(11.0, 22.0)`) instead of a flat `16`, so letters
stay proportionally legible regardless of how big the grid's cells end up
being. Verified via the same iPad-resolution screenshot technique
post-fix (properly centered content, readable grid letters) and a phone-size
screenshot re-check (420×850, pixel-identical to before the change, since
480 > any phone width the `ConstrainedBox` never actually constrains
anything there).

**Round 2 — "not broken" wasn't enough, user wanted it to actually look
bigger.** The maxWidth:480 fix above stopped the grid from being unreadable,
but on a real iPad canvas it now read as a small centered phone-width island
with huge empty margins either side — user flagged this directly from an
iPad-resolution screenshot ("nhỏ xíu nhìn xấu quá... làm to lên tương ứng
kích thước màn hình ipad được không?"). **Fixed 2026-09-16**, same two files:
raised the cap to `maxWidth: 760` and, inside the `ConstrainedBox`, added a
`LayoutBuilder` computing `scale = (constraints.maxWidth / 420).clamp(1.0,
1.8)` — a genuine proportional scale factor (1.0 on phone widths, up to 1.8
on the 760-wide iPad cap), not just a wider box around the same fixed font
sizes. `scale` is threaded through every font size, icon size, and
padding/spacing value in `home_screen.dart`'s `_LevelCard` and
`game_screen.dart`'s `_Hud`/`_Stat`, plus a new `scale` param on
`WordListWidget` (`word_list_widget.dart`) multiplying its icon/text sizes
and padding. `GridWidget` deliberately gets **no** `scale` param — it already
derives its own font size from actual cell size (round 1's fix), so simply
handing it more width via the wider cap makes it bigger correctly on its
own; threading `scale` into it too would double-scale it. Verified via
`flutter analyze` (clean) and `flutter test` (21/21), then re-confirmed
visually on both the home screen and the in-game screen at iPad resolution
(2064×2752) — title art, level cards, HUD stats, word list, and grid letters
all visibly larger and better-proportioned than round 1, with no layout
overflow. Note: the Column-based game screen still doesn't stretch to fill
the iPad's tall portrait height — the grid is width-bound (square, capped by
the 760 max width) and ends up vertically centered in the leftover
`Expanded` space between the word list and the hint button, so there's
still visible empty space above/below the grid on iPad. That's an expected
consequence of keeping the same single-column phone layout rather than
redesigning for tablet, not a bug. If a future change wants a true
tablet-optimized layout (e.g. a two-pane view putting the word list beside
the grid instead of above it, filling that vertical space), that's a bigger
redesign than either round of this fix — both rounds only make iPad *look
right*, neither makes the iPad layout *distinctive*.

## Scope decisions (v1)

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
as every sibling. Both ad unit IDs are now real (2026-09-13), from this
project's own app within publisher `9078637596840810` — the same AdMob
account block-puzzle-app uses, a separate app registered within it. The
`ADMOB_APP_ID` GitHub secret (manifest Application ID, a separate value from
either ad unit ID) is set, wired into `build-apk.yml`. Interstitial shows
roughly every other completed puzzle, not after every one.

**Target audience / ad content rating**: `initialize()` calls
`MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
maxAdContentRating: MaxAdContentRating.t))` right after `.initialize()`.
Chosen 2026-09-13 to match a **13+** Play Console "Target audience"
declaration (not child-directed) — declaring the app as directed at
children under 13 would pull it under Google Play's much stricter Families
policy (limits which ad formats/networks are even allowed, more review
scrutiny), which doesn't fit this app: it has no content designed
specifically for young children, and its Expert-level vocabulary is
adult-level. `ageRestrictedTreatment` is deliberately left unset (its
default, `unspecified`) rather than `.child`/`.teen` — those values actively
*signal* child/teen ad treatment to AdMob (which changes ad serving rules),
appropriate only for an app that actually targets under-18 users, not a
general/13+ one. Uses the modern `ageRestrictedTreatment` API, not the
deprecated `tagForChildDirectedTreatment`/`tagForUnderAgeOfConsent` ints
`google_mobile_ads` still exposes for backward compatibility. **This is a
code-level signal only** — still need to actually pick "13+" (or whatever is
decided) in the Play Console listing's own "Target audience and content"
section when that listing is created; the code doesn't set that for you.

**Leaderboard (`lib/services/leaderboard_service.dart`)**: Google Play
Games Services (Android) + Game Center (iOS), one leaderboard per
`VocabLevel` per platform (scores aren't comparable across levels —
different grid sizes/word counts — same reasoning `ScoreService` already
uses for tracking "best" per level; Play Games and Game Center also use
entirely separate leaderboard ID spaces for the same game). Dual-platform
since 2026-09-17, mirroring block-puzzle-app's version of this same class —
was Android-only from 2026-09-13 until the user created Game Center
leaderboards for iOS too.

All four `_androidLeaderboardIds` values are real (2026-09-13, from a
Play Console project the user created for this app: `CgkIqeuj6uoNEAIQAQ`
Basic, `...IQAg` Intermediate, `...IQAw` Advanced, `...IQBA` Expert) and the
`PLAY_GAMES_APP_ID` GitHub secret (`475353642409`) is set, patched into the
manifest by `build-apk.yml` same as `ADMOB_APP_ID`. All four
`_iosLeaderboardIds` values are also real (2026-09-17: `ldb1` Basic, `ldb2`
Intermediate, `ldb3` Advanced, `ldb4` Expert) — chosen directly by the user
when creating each Game Center leaderboard in App Store Connect, unlike
Play Console's opaque generated IDs. `_isConfigured`'s `REPLACE_` check is
kept as a guard anyway on both platforms — harmless once real IDs are set,
and still correct if they're ever reset. See the "iOS" section above for
the entitlement wiring Game Center needed on top of the leaderboard IDs
themselves (unlike Android, which just needed the manifest meta-data).
`GameScreen.initState()` calls
`LeaderboardService.signIn()` unawaited (mirrors block-puzzle-app's
`signIn()`-moved-out-of-the-engine precedent, for the same reason: keeps a
future engine-level test from ever triggering a real platform-channel call).
`_onPuzzleComplete()` calls `submitScore(level, score)` unawaited right next
to the existing `ScoreService.saveBest` call. Android release signing is
set up and confirmed working (see "Release signing" below) — Play Games
ties sign-in to the app's signing certificate, so this was a real
prerequisite, not just a nice-to-have. Neither platform's actual
sign-in/submit/show flow has been manually verified on a real device yet;
until then (or if either ever fails for any other reason — no
account signed in, no network, etc.) every leaderboard call still safely
times out/no-ops, and the trophy button falls back to its "Bảng xếp hạng
chưa khả dụng." SnackBar.

**Sound (`lib/services/sound_service.dart`)**: `flame_audio` + `AudioPool`,
same pattern as block-puzzle-app/`[[project_dino_egg_shooter]]` — `sound_src/`
holds every source file the user supplied (WAV/MP3), `assets/audio/` holds
the bundled copies actually declared in `pubspec.yaml` (keep both in sync if
a sound is ever added/replaced; no build step copies one to the other).
`SoundEffect` enum values map 1:1 to trigger points: `confirm` fires from
`HomeScreen._openLevel`/`_openLeaderboard` and the completion dialog's
"Puzzle mới" button; `back` fires from `GameScreen._onBackPressed` (the
AppBar back arrow itself) and both pause-dialog buttons ("Tiếp tục" *and*
"Về trang chủ" — grouped under the same effect per the user's own request)
and the completion dialog's "Về trang chủ"; `hint` fires from `_onHint`;
`correct`/`wrong` fire from `GridWidget._onEnd`, the same branch that
already tracked a match vs. a failed selection for the score popup /
red-flash effects, so no new state was needed to know which to play; `win`
fires from `_onPuzzleComplete`, right where the completion dialog is about
to show. **No `gameOver` effect** — unlike this series' other games,
`WordSearchEngine` has no lose condition at all (no timer that fails a
puzzle, no penalty for running out of hints), only a win. The user was
asked directly what a "gameover" sound should map to given that, and chose
to leave it out entirely rather than attach it to an event that isn't
really a failure (e.g. quitting mid-puzzle) — `m_failed.mp3` stays in
`sound_src/` unbundled, ready to wire up if a timed/lose mode is ever
added, but `SoundEffect` has no corresponding value for it today. `init()`
is fired **unawaited** from `main()`, each pool creation individually
wrapped in try/catch + `.timeout(5s)` — this exact pattern exists because of
a real incident in `[[project_number_master_app]]` where an unguarded
`FlameAudio.createPool()` Future never resolved on web, hanging the entire
app before its first frame; do not simplify this back to a bare `await`.
Every `play()` call is `_pools[effect]?.start()` — a safe no-op if that pool
never finished loading (or on `flutter test`, where no plugin is ever
registered at all, so `_pools` just stays empty — this is *why* the engine's
own unit tests never needed any audio mocking despite exercising
`trySelect`/`useHint` directly; check this stays true before adding new
sound trigger points inside engine-adjacent code). **Known web-only
limitation** (same as documented for block-puzzle-app): `flutter run -d
chrome` throws a console `MissingPluginException(...
audioplayers.global/events ...)` after `SoundService.init()` runs, because
`audioplayers`' web implementation doesn't support the global event channel
`flame_audio`'s `AudioPool` relies on internally — does not crash or block
anything, just means sound can only be verified for real on an actual
Android build, not the web preview used for the rest of this project's UI
verification.

**Sound toggle** (`lib/widgets/sound_toggle_button.dart`, a
`SoundToggleButton` shared by `HomeScreen` and `GameScreen`'s HUD):
reflects `SoundService.instance.enabledNotifier` via `ValueListenableBuilder`,
calls `.toggle()` (flips the notifier + persists to `shared_preferences`) on
tap. `HomeScreen` has no `AppBar` (the title is `assets/title/title.png`
sitting directly in a `Column`), so the toggle is placed via a `Positioned`
top-right corner over a `Stack` wrapping that `Column`, rather than in an
`actions:` list the way block-puzzle-app's `AppBar`-based screens do it.
`GameScreen` places it as the last child in its `_Hud` `Row`, after the
stats `Wrap`.

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
