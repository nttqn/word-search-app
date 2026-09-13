# WordHunt - Tra Từ

A Flutter Android word-search puzzle game built as an English vocabulary
trainer for Vietnamese learners: find a word in the letter grid and its
Vietnamese meaning is revealed right in the clue list. Four difficulty tiers
(Cơ bản / Trung cấp / Nâng cao / Chuyên sâu), each with its own curated word
bank and grid size.

There is no Flutter/Android SDK installed by default in some dev
environments this project is developed in — see `CLAUDE.md` for the CI-only
Android build setup if that's the case for you. If Flutter *is* available
locally:

```
flutter pub get
flutter analyze
flutter test
flutter run -d chrome          # fastest way to iterate on gameplay/UI
flutter build apk --release    # debug-signed test APK
```

## Before publishing to the Play Store

1. **AdMob**: not yet set up. `lib/services/ads_service.dart` uses Google's
   public **test** ad unit IDs — this project has no AdMob account of its
   own yet. Create one, swap in the real banner/interstitial ad unit IDs,
   and set the `ADMOB_APP_ID` GitHub secret (manifest-level Application ID,
   a separate value) before publishing.
2. **Release signing**: not yet set up. Set the `KEYSTORE_BASE64`,
   `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` GitHub secrets so CI
   produces a real Play-Store-signable APK/AAB instead of a debug-signed
   test build.
3. **App icon & title art**: done — `assets/icon/icon.png` and
   `assets/title/title.png` are the real "WordHunt - Tra Từ" branded art;
   `flutter_launcher_icons` regenerates every mipmap size in CI.
4. **Privacy policy**: drafted at `docs/privacy.html` (covers local score
   storage, Play Games Services sign-in, and AdMob). Enable GitHub Pages for
   this repo (Settings → Pages → Source: "Deploy from a branch" → branch
   `main`, folder `/docs`) to get a public URL — Play Console requires one
   before a listing can go live. Once enabled, it's
   `https://nttqn.github.io/word-search-app/privacy.html`.
5. **Leaderboard**: not yet functional. `lib/services/leaderboard_service.dart`
   is wired for Google Play Games Services (one leaderboard per difficulty
   level), but the leaderboard IDs are still placeholders — create a Play
   Console project for this app, create 4 leaderboards there, paste the
   generated IDs into `_androidLeaderboardIds`, and set the
   `PLAY_GAMES_APP_ID` GitHub secret. Until then the trophy button on each
   level card just shows "not available yet" — the game itself is unaffected.
6. **Target audience**: code-side done — `AdsService.initialize()` sets
   `maxAdContentRating: MaxAdContentRating.t` to match a **13+** audience
   (not child-directed, avoiding Google Play's stricter Families policy).
   Still need to actually select "13+" in the Play Console listing's own
   "Target audience and content" section when that listing is created —
   the code doesn't set that for you.
