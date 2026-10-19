import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/word_banks.dart';
import '../models/vocab_word.dart';
import 'safe_prefs.dart';

/// One tracked word's spaced-repetition state: which "box" it's in (a
/// Leitner-style scheme — found again on schedule promotes it to a longer
/// interval) and when it next becomes due.
class _ReviewEntry {
  final int box;
  final DateTime due;
  const _ReviewEntry(this.box, this.due);

  Map<String, dynamic> toJson() => {'box': box, 'due': due.toIso8601String()};

  factory _ReviewEntry.fromJson(Map<String, dynamic> json) =>
      _ReviewEntry(json['box'] as int, DateTime.parse(json['due'] as String));
}

/// Tracks every word the player has ever found, on a Leitner-style spaced
/// repetition schedule, so "Ôn tập" (review mode) can resurface words that
/// are actually due to be forgotten instead of ones found five minutes ago.
///
/// A word enters the schedule in box 1 the first time it's found anywhere
/// (a normal level, review, or daily). Finding it again *while it's due*
/// promotes it to the next box (a longer interval); finding it again before
/// it's due doesn't change anything — otherwise replaying a level you just
/// finished would keep pushing its words further out for no reason, the
/// exact thing spaced repetition is supposed to prevent.
class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  static const _prefsKey = 'review_words_v1';

  // Days until next review at each box, 1-indexed; stays at the last value
  // once a word reaches the top box rather than growing unboundedly.
  static const List<int> _intervalDays = [1, 2, 4, 7, 14, 30];
  static const int _firstBoxDays = 1;

  Map<String, _ReviewEntry>? _cache;

  /// The in-memory cache is only ever written by this service, so it never
  /// goes stale during normal app use — but tests reseed
  /// shared_preferences's mock store between cases and need the next call
  /// to actually re-read it instead of returning a previous test's cache.
  @visibleForTesting
  void resetCacheForTesting() => _cache = null;

  Future<Map<String, _ReviewEntry>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final map = <String, _ReviewEntry>{};
    final prefs = await safeSharedPrefs();
    final raw = prefs?.getString(_prefsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        map[entry.key] = _ReviewEntry.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    _cache = map;
    return map;
  }

  Future<void> _save(Map<String, _ReviewEntry> map) async {
    final prefs = await safeSharedPrefs();
    if (prefs == null) return;
    final encoded = jsonEncode({
      for (final entry in map.entries) entry.key: entry.value.toJson(),
    });
    await prefs.setString(_prefsKey, encoded);
  }

  void _applyFound(Map<String, _ReviewEntry> map, VocabWord word, DateTime now) {
    final key = word.upper;
    final existing = map[key];
    if (existing == null) {
      map[key] = _ReviewEntry(1, now.add(const Duration(days: _firstBoxDays)));
    } else if (!now.isBefore(existing.due)) {
      final nextBox = min(existing.box + 1, _intervalDays.length);
      map[key] = _ReviewEntry(
        nextBox,
        now.add(Duration(days: _intervalDays[nextBox - 1])),
      );
    }
  }

  /// Adds/promotes a single word and persists immediately. Prefer
  /// [onWordsFound] when recording more than one word at once (e.g. a
  /// finished puzzle) — this one still exists for callers that genuinely
  /// only have one word at a time, and for tests.
  Future<void> onWordFound(VocabWord word) async {
    final map = await _load();
    _applyFound(map, word, DateTime.now());
    await _save(map);
  }

  /// Adds/promotes every word in one shot with a single shared_preferences
  /// write, instead of one write per word. `GameScreen` used to call
  /// [onWordFound] once per word *as it was found*, unawaited — for a
  /// 12-word Expert puzzle that's up to 12 concurrent, un-sequenced
  /// shared_preferences read-then-write round trips firing in quick
  /// succession, right as the far more important score-save call for the
  /// same puzzle was also trying to go through. A real-device report (score
  /// no longer saving after this feature shipped, not present in the build
  /// before it) matches that shape closely enough that `GameScreen` now
  /// batches every found word from a session into one call here, fired
  /// from `dispose()` — after the completion dialog has already resolved,
  /// so this can never compete with anything time-sensitive again.
  Future<void> onWordsFound(Iterable<VocabWord> words) async {
    if (words.isEmpty) return;
    final map = await _load();
    final now = DateTime.now();
    for (final word in words) {
      _applyFound(map, word, now);
    }
    await _save(map);
  }

  /// Up to [limit] words that are due for review right now, most-overdue
  /// first. Words whose text no longer matches any current bank entry (a
  /// future content edit) are silently skipped rather than crashing.
  Future<List<VocabWord>> dueWords({int limit = 12}) async {
    final map = await _load();
    final now = DateTime.now();
    final due = map.entries.where((e) => !now.isBefore(e.value.due)).toList()
      ..sort((a, b) => a.value.due.compareTo(b.value.due));
    return due
        .take(limit)
        .map((e) => WordBanks.allByUpper[e.key])
        .whereType<VocabWord>()
        .toList();
  }

  Future<int> dueCount() async {
    final map = await _load();
    final now = DateTime.now();
    return map.values.where((e) => !now.isBefore(e.due)).length;
  }
}
