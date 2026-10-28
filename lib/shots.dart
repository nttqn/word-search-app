import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/word_banks.dart';
import 'game/word_search_engine.dart';
import 'main.dart';
import 'models/game_session.dart';
import 'models/level.dart';
import 'screens/game_screen.dart';
import 'screens/home_screen.dart';
import 'screens/word_book_screen.dart';
import 'services/daily_challenge_service.dart';

/// Store-screenshot entry point: `?s=NN` picks a fixed scene, with seeded
/// progress and seeded puzzles so every device size shows the same thing.
/// Driven by tool/store_shots.js — never shipped (the app builds main.dart).
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final scene = Uri.base.queryParameters['s'] ?? '01';
  // In-memory prefs seeded per scene; fine outside tests for a shots build.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(_seedPrefs(scene));
  runApp(WordSearchApp(home: _home(scene)));
}

String _day(int offset) {
  final d = DateTime.now().add(Duration(days: offset));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

Map<String, Object> _seedPrefs(String scene) {
  final now = DateTime.now();
  // A learner a couple of weeks in: words spread over every box, 8 due.
  final words = <String, Object>{};
  var i = 0;
  for (final level in VocabLevel.values) {
    for (final w in WordBanks.byLevel[level]!.take(level.index < 2 ? 9 : 6)) {
      final box = 1 + (i * 7) % 6;
      final dueInDays = i % 4 == 0 ? -1 : 1 + (i % 9);
      words[w.upper] = {
        'box': box,
        'due': now.add(Duration(days: dueInDays, hours: -2)).toIso8601String(),
      };
      i++;
    }
  }
  return {
    'review_words_v1': jsonEncode(words),
    'best_score_basic': 412,
    'best_score_intermediate': 655,
    'best_score_advanced': 870,
    'best_score_expert': 1140,
    // Scene 06 completes today's daily, so the streak ticks 5 -> 6 there.
    'daily_last_completed_date': _day(scene == '06' ? -1 : 0),
    'daily_streak_current': 5,
    'daily_streak_longest': 9,
    'reminders_asked': true,
  };
}

/// Finds the first [count] placed words, as if dragged by the player.
void Function(WordSearchEngine) _find(
  int count, {
  int elapsed = 0,
  bool hint = false,
}) => (engine) {
  engine.elapsedSeconds = elapsed;
  for (final w in engine.grid.placedWords.take(count)) {
    engine.trySelect(w.cells);
  }
  if (hint) engine.useHint();
};

GameSession _seeded(GameSession s, int seed) => GameSession(
  mode: s.mode,
  title: s.title,
  shape: s.shape,
  bank: s.bank,
  level: s.level,
  random: Random(seed),
);

Widget _home(String scene) {
  switch (scene) {
    case '02':
      return GameScreen(
        session: _seeded(GameSession.level(VocabLevel.basic), 11),
        debugSetup: _find(3, elapsed: 42),
      );
    case '03':
      return GameScreen(
        session: _seeded(GameSession.level(VocabLevel.intermediate), 21),
        debugSetup: _find(2, elapsed: 75, hint: true),
      );
    case '04':
      return GameScreen(
        session: _seeded(GameSession.level(VocabLevel.advanced), 31),
        debugSetup: _find(99, elapsed: 128),
      );
    case '05':
      final due = [
        for (final level in VocabLevel.values)
          ...WordBanks.byLevel[level]!.skip(10).take(2),
      ];
      return GameScreen(
        session: _seeded(GameSession.review(due), 41),
        debugSetup: _find(4, elapsed: 63),
      );
    case '06':
      return GameScreen(
        session: DailyChallengeService.instance.buildTodaySession(),
        debugSetup: _find(99, elapsed: 96),
      );
    case '07':
      return const WordBookScreen();
    case '08':
      return GameScreen(
        session: _seeded(GameSession.level(VocabLevel.expert), 51),
        debugSetup: _find(5, elapsed: 214),
      );
    default:
      return const HomeScreen();
  }
}
