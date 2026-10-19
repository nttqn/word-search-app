import 'dart:math';

import '../data/word_banks.dart';
import '../models/game_session.dart';
import '../models/level.dart';
import 'safe_prefs.dart';

/// One daily challenge puzzle + the player's completion streak across days.
///
/// The puzzle itself is deterministic for a given calendar day (seeded by
/// the date, same as "Wordle"-style dailies): reopening it later the same
/// day — after backing out, or after the ad interstitial — must show the
/// exact same grid, not a fresh random one, so there's exactly one daily
/// challenge rather than infinite retries. The level rotates by weekday so
/// the daily isn't always the same size/difficulty.
class DailyChallengeService {
  DailyChallengeService._();
  static final DailyChallengeService instance = DailyChallengeService._();

  static const _lastCompletedKey = 'daily_last_completed_date';
  static const _streakKey = 'daily_streak_current';
  static const _longestStreakKey = 'daily_streak_longest';

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  VocabLevel _levelForDate(DateTime d) =>
      VocabLevel.values[d.weekday % VocabLevel.values.length];

  int _seedForDate(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  GameSession buildTodaySession() {
    final now = DateTime.now();
    final level = _levelForDate(now);
    return GameSession(
      mode: GameMode.daily,
      title: 'Thử thách hôm nay',
      shape: level.shape,
      bank: WordBanks.byLevel[level]!,
      random: Random(_seedForDate(now)),
    );
  }

  /// Defaults to "not completed" (`false`) when shared_preferences can't be
  /// read in time — letting a player open today's puzzle again is a far
  /// safer failure mode than a button that silently never responds, which
  /// is exactly what an unguarded read here caused on a real device.
  Future<bool> isCompletedToday() async {
    final prefs = await safeSharedPrefs();
    if (prefs == null) return false;
    return prefs.getString(_lastCompletedKey) == _dateKey(DateTime.now());
  }

  /// Current streak as of right now — 0 if the player missed a day (the
  /// stored counter itself resets lazily on the next completion, not here,
  /// so this re-derives "is it still alive" from the last-completed date
  /// without needing a separate background job), or if shared_preferences
  /// couldn't be read in time.
  Future<int> currentStreak() async {
    final prefs = await safeSharedPrefs();
    if (prefs == null) return 0;
    final last = prefs.getString(_lastCompletedKey);
    if (last == null) return 0;
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final lastDate = DateTime.parse(last);
    final stillAlive =
        _dateKey(lastDate) == _dateKey(today) ||
        _dateKey(lastDate) == _dateKey(yesterday);
    return stillAlive ? (prefs.getInt(_streakKey) ?? 0) : 0;
  }

  /// Call once the daily puzzle is fully solved. Returns the new streak
  /// count. Safe to call more than once on the same day — only the first
  /// completion of a given day advances the streak. Returns 1 (without
  /// persisting anything) if shared_preferences can't be read/written in
  /// time — the player still sees *a* streak number rather than the
  /// completion flow stalling on this write.
  Future<int> recordCompletion() async {
    final prefs = await safeSharedPrefs();
    if (prefs == null) return 1;
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final last = prefs.getString(_lastCompletedKey);
    if (last == todayKey) {
      return prefs.getInt(_streakKey) ?? 1;
    }

    var newStreak = 1;
    if (last != null) {
      final yesterday = today.subtract(const Duration(days: 1));
      if (_dateKey(DateTime.parse(last)) == _dateKey(yesterday)) {
        newStreak = (prefs.getInt(_streakKey) ?? 0) + 1;
      }
    }

    await prefs.setString(_lastCompletedKey, todayKey);
    await prefs.setInt(_streakKey, newStreak);
    final longest = prefs.getInt(_longestStreakKey) ?? 0;
    if (newStreak > longest) {
      await prefs.setInt(_longestStreakKey, newStreak);
    }
    return newStreak;
  }
}
