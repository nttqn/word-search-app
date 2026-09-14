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
4. **Privacy policy**: drafted at `docs/privacy.html` (covers local score
   storage, Play Games Services sign-in, and AdMob). Enable GitHub Pages for
   this repo (Settings → Pages → Source: "Deploy from a branch" → branch
   `main`, folder `/docs`) to get a public URL — Play Console requires one
   before a listing can go live. Once enabled, it's
   `https://nttqn.github.io/word-search-app/privacy.html`.
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

1. **Signing**: done — `IOS_DIST_P12_BASE64`, `IOS_DIST_P12_PASSWORD`,
   `IOS_PROVISIONING_PROFILE_BASE64`, `APPSTORE_TEAM_ID` GitHub secrets are
   set, reusing an existing Team-wide Apple Distribution certificate (from
   `lunar-calendar-app`) plus a new App Store provisioning profile for this
   app's bundle ID. `wordhunt-distribution.p12` / `distribution.cer` /
   `WordHunt_App_Store.mobileprovision` are gitignored, live in the project
   root.
2. **AdMob (iOS)**: not yet set up — no iOS app/ad units exist in the AdMob
   account yet, so iOS builds serve Google's public test ads until a real
   iOS AdMob app is created and `ADMOB_APP_ID_IOS` is set (ad unit IDs are
   hardcoded per-platform in `lib/services/ads_service.dart`).
3. **Leaderboard (iOS)**: not implemented — Game Center support was never
   added (Android-only by choice, see `CLAUDE.md`). Skipped entirely on
   iOS, not a crash.
4. **TestFlight upload**: not yet set up — needs `APPSTORE_API_KEY_ID`,
   `APPSTORE_API_ISSUER_ID`, `APPSTORE_API_KEY_P8` (an App Store Connect
   API key). Until then, download the signed `.ipa` CI artifact and upload
   it manually (e.g. via Transporter) instead of using the `upload_ios`
   `workflow_dispatch` checkbox.
5. **App Store Connect app record**: not yet created — the user needs to
   create the app listing by hand in App Store Connect before a TestFlight
   build can show up for testers, separate from the upload itself
   succeeding.
