import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordhunt/data/word_banks.dart';
import 'package:wordhunt/game/grid_generator.dart';
import 'package:wordhunt/game/word_search_engine.dart';
import 'package:wordhunt/models/level.dart';

void main() {
  group('WordSearchEngine', () {
    late WordSearchEngine engine;

    setUp(() {
      engine = WordSearchEngine(
        level: VocabLevel.basic,
        bank: WordBanks.basic,
        random: Random(3),
      )..start();
    });

    tearDown(() => engine.dispose());

    test('start() generates the expected number of words and resets state', () {
      expect(engine.grid.placedWords.length, VocabLevel.basic.wordsPerPuzzle);
      expect(engine.foundWords, isEmpty);
      expect(engine.score, 0);
      expect(engine.hintsRemaining, WordSearchEngine.maxHints);
      expect(engine.isComplete, isFalse);
    });

    test('trySelect matches a word given forward cells and scores it', () {
      final target = engine.grid.placedWords.first;
      final match = engine.trySelect(target.cells);

      expect(match, target);
      expect(engine.foundWords, contains(target));
      expect(engine.score, target.word.upper.length * 10);
    });

    test('trySelect also matches the reversed cell path', () {
      final target = engine.grid.placedWords.first;
      final match = engine.trySelect(target.cells.reversed.toList());

      expect(match, target);
      expect(engine.foundWords, contains(target));
    });

    test('trySelect returns null and changes nothing for a path that spells no word', () {
      final bogusPath = [const Cell(0, 0)];
      final match = engine.trySelect(bogusPath);

      expect(match, isNull);
      expect(engine.foundWords, isEmpty);
      expect(engine.score, 0);
    });

    test('finding every word marks the puzzle complete and adds a time bonus', () {
      for (final placed in List.of(engine.grid.placedWords)) {
        engine.trySelect(placed.cells);
      }

      expect(engine.isComplete, isTrue);
      final baseScore = engine.grid.placedWords
          .map((w) => w.word.upper.length * 10)
          .reduce((a, b) => a + b);
      expect(engine.score, greaterThanOrEqualTo(baseScore));
    });

    test('useHint reveals an unfound word and consumes one hint', () {
      final before = engine.hintsRemaining;
      engine.useHint();

      expect(engine.hintsRemaining, before - 1);
      expect(engine.highlightedHintCells, isNotNull);
      expect(engine.highlightedHintCells!.isNotEmpty, isTrue);
    });

    test('useHint is a no-op once hints run out', () {
      for (var i = 0; i < WordSearchEngine.maxHints; i++) {
        engine.useHint();
      }
      expect(engine.hintsRemaining, 0);

      engine.clearHint();
      engine.useHint();

      expect(engine.hintsRemaining, 0);
      expect(engine.highlightedHintCells, isNull);
    });

    test('clearHint clears the highlighted cells', () {
      engine.useHint();
      expect(engine.highlightedHintCells, isNotNull);

      engine.clearHint();
      expect(engine.highlightedHintCells, isNull);
    });
  });
}
