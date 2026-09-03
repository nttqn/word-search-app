import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps AdMob banner + interstitial ads. Uses Google's public **test** ad
/// unit IDs for now (this project has no AdMob account of its own yet) —
/// swap these for real ones the same way block-puzzle-app did once one
/// exists. The `ADMOB_APP_ID` GitHub secret (manifest-level Application ID)
/// is a separate value, patched in by build-apk.yml.
///
/// `google_mobile_ads` only supports Android/iOS, so every entry point here
/// is a no-op on web/desktop — keeps `flutter run -d chrome` usable for
/// previewing gameplay without a phone.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  InterstitialAd? _interstitialAd;
  int _puzzlesSinceInterstitial = 0;

  Future<void> initialize() async {
    if (kIsWeb) return;
    await MobileAds.instance.initialize();
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
