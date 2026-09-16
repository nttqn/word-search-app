# WordHunt - Tra Từ

A Flutter word-search puzzle game (Android + iOS) built as an English
vocabulary trainer for Vietnamese learners: find a word in the letter grid
and its Vietnamese meaning is revealed right in the clue list. Four
difficulty tiers (Cơ bản / Trung cấp / Nâng cao / Chuyên sâu), each with its
own curated word bank and grid size.

There is no Flutter/Android SDK (and no Mac at all) installed by default in
some dev environments this project is developed in — see `CLAUDE.md` for
the CI-only Android/iOS build setup if that's the case for you. If Flutter
*is* available locally:

```
flutter pub get
flutter analyze
flutter test
flutter run -d chrome          # fastest way to iterate on gameplay/UI
flutter build apk --release    # debug-signed test APK
```

## Before publishing to the Play Store

1. **AdMob**: done — real banner/interstitial ad unit IDs are set in
   `lib/services/ads_service.dart`; the `ADMOB_APP_ID` GitHub secret (a
   separate value from the ad unit IDs) is also set.
2. **Release signing (Android)**: done — `KEYSTORE_BASE64`,
   `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` GitHub secrets are set;
   CI builds a real Play-Store-signable APK/AAB (confirmed on the
   2026-09-14 run). Keystore (`wordhunt-release.jks`) is gitignored, lives
   in the project root — **do not lose it**, there is no way to recover it
   or update the app under this identity again without it.
3. **App icon & title art**: done — `assets/icon/icon.png` and
   `assets/title/title.png` are the real "WordHunt - Tra Từ" branded art;
   `flutter_launcher_icons` regenerates every mipmap size in CI.
4. **Privacy policy / Support / Marketing URL**: done — GitHub Pages is
   enabled for this repo (branch `main`, folder `/docs`), serving:
   - Privacy Policy: `https://nttqn.github.io/word-search-app/privacy.html`
   - Support: `https://nttqn.github.io/word-search-app/support.html`
   - Marketing (optional field, a simple landing page):
     `https://nttqn.github.io/word-search-app/index.html`
5. **Leaderboard (Android)**: code + IDs + release signing all done now —
   real leaderboard IDs from the user's Play Console project are in
   `_androidLeaderboardIds`, and the `PLAY_GAMES_APP_ID` GitHub secret is
   set. Play Games sign-in is tied to the app's signing certificate, which
   is now a real release key (item 2) rather than debug-signed, so this
   should actually work — not yet manually verified on a real device.
6. **Target audience**: code-side done — `AdsService.initialize()` sets
   `maxAdContentRating: MaxAdContentRating.t` to match a **13+** audience
   (not child-directed, avoiding Google Play's stricter Families policy).
   Still need to actually select "13+" in the Play Console listing's own
   "Target audience and content" section when that listing is created —
   the code doesn't set that for you.

## Before publishing to the App Store (iOS)

iOS support was added 2026-09-14 (`build-ios` job in
`.github/workflows/build-apk.yml`) — see `CLAUDE.md`'s "iOS" section for
the full story.

1. **Signing**: done — confirmed working end-to-end 2026-09-15.
   `IOS_DIST_P12_BASE64`, `IOS_DIST_P12_PASSWORD`,
   `IOS_PROVISIONING_PROFILE_BASE64`, `APPSTORE_TEAM_ID` GitHub secrets are
   set, reusing an existing Team-wide Apple Distribution certificate (from
   `lunar-calendar-app`) plus an App Store provisioning profile for this
   app's bundle ID. `wordhunt-distribution.p12` / `distribution.cer` /
   `WordHunt_App_Store.mobileprovision` are gitignored, live in the project
   root.
2. **AdMob (iOS)**: done — real banner/interstitial ad unit IDs and
   `ADMOB_APP_ID_IOS` are set, same AdMob account as Android.
3. **Leaderboard (iOS)**: done — Game Center leaderboards created
   (`ldb1`-`ldb4`, one per level) and wired into
   `lib/services/leaderboard_service.dart`; `tool/Runner.entitlements` +
   the `Install Game Center entitlement` CI step add the required
   capability to the Runner target.
4. **TestFlight upload**: done — `APPSTORE_API_KEY_ID`,
   `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_KEY_P8` are set, reusing
   `number99-app`'s existing App Store Connect API key (Team-scoped, not
   per-app). Trigger via `workflow_dispatch` with the `upload_ios` checkbox
   ticked.
5. **App Store Connect app record**: done — created by the user for
   `com.trungsmail.wordhunt` before the first upload attempt.
