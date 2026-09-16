import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import '../models/level.dart';

/// Google Play Games Services (Android) / Game Center (iOS) leaderboard
/// wiring — one leaderboard per [VocabLevel] per platform, since scores
/// aren't comparable across levels (different grid sizes and word counts;
/// same reasoning `ScoreService` already uses for tracking "best" per
/// level) and Play Games/Game Center use entirely separate leaderboard ID
/// spaces for the same game. Modeled directly on block-puzzle-app's
/// dual-platform version of this same class — this project's was
/// Android-only until 2026-09-17, when the user created Game Center
/// leaderboards for iOS too.
///
/// All eight leaderboard IDs (4 levels × 2 platforms) are real: Android's
/// from a Play Console project (opaque generated IDs, set 2026-09-13);
/// iOS's (`ldb1`-`ldb4`) chosen by the user directly when creating the
/// Game Center leaderboards in App Store Connect (unlike Play Console, App
/// Store Connect lets you pick the ID string yourself). `_isConfigured`'s
/// `REPLACE_` check always passes now but is kept as-is rather than
/// removed — still the correct guard if IDs are ever reset/cleared, and
/// costs nothing to leave in place.
///
/// Every call is wrapped in try/catch + a `.timeout(...)` —
/// `GameAuth.signIn()` is a plain `MethodChannel.invokeMethod` that never
/// completes (not even with an error) when no native handler is attached,
/// so an unguarded call could hang the caller forever; `Future.timeout`
/// uses a real `Timer`, which `flutter_test`'s fake clock can resolve
/// deterministically if a future test ever exercises this from a widget.
class LeaderboardService {
  static const Map<VocabLevel, String> _androidLeaderboardIds = {
    VocabLevel.basic: 'CgkIqeuj6uoNEAIQAQ',
    VocabLevel.intermediate: 'CgkIqeuj6uoNEAIQAg',
    VocabLevel.advanced: 'CgkIqeuj6uoNEAIQAw',
    VocabLevel.expert: 'CgkIqeuj6uoNEAIQBA',
  };

  static const Map<VocabLevel, String> _iosLeaderboardIds = {
    VocabLevel.basic: 'ldb1',
    VocabLevel.intermediate: 'ldb2',
    VocabLevel.advanced: 'ldb3',
    VocabLevel.expert: 'ldb4',
  };

  static const _timeout = Duration(seconds: 5);

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  static bool get _isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || _isIOS);

  static String? _leaderboardIdForCurrentPlatform(VocabLevel level) =>
      _isIOS ? _iosLeaderboardIds[level] : _androidLeaderboardIds[level];

  static bool _isConfigured(VocabLevel level) =>
      !(_leaderboardIdForCurrentPlatform(level)?.startsWith('REPLACE_') ??
          true);

  /// Silent sign-in, best attempted once at game-screen startup. Play Games
  /// Services v2 also auto-prompts sign-in on its own, but the plugin docs
  /// say this must still be called before submitScore/showLeaderboards.
  static Future<void> signIn() async {
    if (!_isSupported) return;
    try {
      await GameAuth.signIn().timeout(_timeout);
    } catch (_) {
      // No Google/Game Center account signed in, not set up yet, no
      // network, a hung platform channel (see class doc), etc. — the game
      // must stay fully playable without a leaderboard.
    }
  }

  static Future<void> submitScore(VocabLevel level, int score) async {
    if (!_isSupported || !_isConfigured(level)) return;
    try {
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: _androidLeaderboardIds[level]!,
          iOSLeaderboardID: _iosLeaderboardIds[level]!,
          value: score,
        ),
      ).timeout(_timeout);
    } catch (_) {
      // Fire-and-forget — a failed submit must never interrupt the
      // completion dialog the player is looking at.
    }
  }

  /// Opens Play Games'/Game Center's own leaderboard UI for [level].
  /// Returns whether it could — the caller can use this to show a "not
  /// available" message instead of silently doing nothing when the user
  /// explicitly tapped a button for it.
  static Future<bool> showLeaderboard(VocabLevel level) async {
    if (!_isSupported || !_isConfigured(level)) return false;
    try {
      await GameAuth.signIn().timeout(_timeout);
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: _androidLeaderboardIds[level]!,
        iOSLeaderboardID: _iosLeaderboardIds[level]!,
      ).timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}
