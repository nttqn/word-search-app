# Word Search - Học Từ Vựng

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
3. **App icon**: done — `assets/icon/icon.png` is a placeholder drawn with
   PowerShell + System.Drawing (no source photo/logo was supplied);
   `flutter_launcher_icons` regenerates every mipmap size in CI. Swap for
   real branded art whenever one is available.
4. **Privacy policy**: not yet drafted — needed before a Play Store listing
   can go live (this app stores local scores/settings via
   `shared_preferences` and serves AdMob ads once real ad units are wired
   in).
