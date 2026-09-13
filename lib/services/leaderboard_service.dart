import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import '../models/level.dart';

/// Google Play Games Services leaderboard wiring — one leaderboard per
/// [VocabLevel], since scores aren't comparable across levels (different
/// grid sizes and word counts; same reasoning `ScoreService` already uses
/// for tracking "best" per level). Android-only: this project has no iOS
/// target (see CLAUDE.md), unlike block-puzzle-app's dual-platform version
/// of this same class, which this file is otherwise modeled on.
///
/// The IDs below are **placeholders** — no Play Console project exists for
/// this app yet. `_isConfigured` gates every real call on them having been
/// replaced with real Play-Console-generated IDs, so shipping with
/// placeholders is safe: sign-in/submit/show all silently no-op instead of
/// failing loudly, exactly like a failed ad load never blocks gameplay in
/// `AdsService`. Every call is also wrapped in try/catch + a `.timeout(...)`
/// — `GameAuth.signIn()` is a plain `MethodChannel.invokeMethod` that never
/// completes (not even with an error) when no native handler is attached,
/// so an unguarded call could hang the caller forever; `Future.timeout` uses
/// a real `Timer`, which `flutter_test`'s fake clock can resolve
/// deterministically if a future test ever exercises this from a widget.
class LeaderboardService {
  static const Map<VocabLevel, String> _androidLeaderboardIds = {
    VocabLevel.basic: 'REPLACE_WITH_BASIC_LEADERBOARD_ID',
    VocabLevel.intermediate: 'REPLACE_WITH_INTERMEDIATE_LEADERBOARD_ID',
    VocabLevel.advanced: 'REPLACE_WITH_ADVANCED_LEADERBOARD_ID',
    VocabLevel.expert: 'REPLACE_WITH_EXPERT_LEADERBOARD_ID',
  };

  static const _timeout = Duration(seconds: 5);

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool _isConfigured(VocabLevel level) =>
      !(_androidLeaderboardIds[level]?.startsWith('REPLACE_') ?? true);

  /// Silent sign-in, best attempted once at game-screen startup. Play Games
  /// Services v2 also auto-prompts sign-in on its own, but the plugin docs
  /// say this must still be called before submitScore/showLeaderboards.
  static Future<void> signIn() async {
    if (!_isSupported) return;
    try {
      await GameAuth.signIn().timeout(_timeout);
    } catch (_) {
      // No Google account signed in, Play Games not set up yet, no network,
      // a hung platform channel (see class doc), etc. — the game must stay
      // fully playable without a leaderboard.
    }
  }

  static Future<void> submitScore(VocabLevel level, int score) async {
    if (!_isSupported || !_isConfigured(level)) return;
    try {
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: _androidLeaderboardIds[level]!,
          value: score,
        ),
      ).timeout(_timeout);
    } catch (_) {
      // Fire-and-forget — a failed submit must never interrupt the
      // completion dialog the player is looking at.
    }
  }

  /// Opens Play Games' own leaderboard UI for [level]. Returns whether it
  /// could — the caller can use this to show a "not available" message
  /// instead of silently doing nothing when the user explicitly tapped a
  /// button for it.
  static Future<bool> showLeaderboard(VocabLevel level) async {
    if (!_isSupported || !_isConfigured(level)) return false;
    try {
      await GameAuth.signIn().timeout(_timeout);
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: _androidLeaderboardIds[level]!,
      ).timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}
