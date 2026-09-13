import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps AdMob banner + interstitial ads. Both ad unit IDs are now real
/// (2026-09-13, this project's own AdMob account, publisher
/// `9078637596840810` — same account as block-puzzle-app's, a separate app
/// within it). The `ADMOB_APP_ID` GitHub secret (manifest-level Application
/// ID) is a separate value, already set, patched in by build-apk.yml.
///
/// `google_mobile_ads` only supports Android/iOS, so every entry point here
/// is a no-op on web/desktop — keeps `flutter run -d chrome` usable for
/// previewing gameplay without a phone.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String bannerAdUnitId =
      'ca-app-pub-9078637596840810/8684680480';
  static const String interstitialAdUnitId =
      'ca-app-pub-9078637596840810/1161413688';

  InterstitialAd? _interstitialAd;
  int _puzzlesSinceInterstitial = 0;

  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
    // Matches the "13+" target audience chosen for this app's Play Console
    // listing (not child-directed): `maxAdContentRating: t` caps served ads
    // at "Teen"-suitable content. `ageRestrictedTreatment` is deliberately
    // left unset (its default, `unspecified`) rather than set to `.child` or
    // `.teen` — those values *signal* child/teen ad treatment to AdMob
    // (stricter serving rules), which is only correct for an app that
    // actually targets under-18 users; this app's audience is general/13+,
    // so no special age-restricted signal should be sent. Uses the modern
    // `ageRestrictedTreatment` API, not the deprecated
    // `tagForChildDirectedTreatment`/`tagForUnderAgeOfConsent` ints.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(maxAdContentRating: MaxAdContentRating.t),
    );
    _loadInterstitial();
  }

  BannerAd? createBannerAd({required void Function() onLoaded}) {
    if (kIsWeb) return null;
    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    banner.load();
    return banner;
  }

  void _loadInterstitial() {
    if (kIsWeb) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  /// Shows an interstitial roughly every other completed puzzle so ads never
  /// interrupt active play — call this once when a puzzle is completed.
  void maybeShowInterstitialAfterPuzzle() {
    if (kIsWeb) return;
    _puzzlesSinceInterstitial++;
    if (_puzzlesSinceInterstitial < 2 || _interstitialAd == null) {
      if (_interstitialAd == null) _loadInterstitial();
      return;
    }
    _puzzlesSinceInterstitial = 0;
    final ad = _interstitialAd!;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitial();
      },
    );
    ad.show();
  }
}
