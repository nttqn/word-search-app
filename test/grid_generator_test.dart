import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordhunt/game/grid_generator.dart';
import 'package:wordhunt/models/level.dart';
import 'package:wordhunt/data/word_banks.dart';

void main() {
  group('GridGenerator', () {
    for (final level in VocabLevel.values) {
      test('${level.name}: grid size and word count match the level config', () {
        final grid = GridGenerator.generate(
          level: level,
          bank: WordBanks.byLevel[level]!,
          random: Random(42),
        );

        expect(grid.size, level.gridSize);
        expect(grid.letters.length, level.gridSize);
        expect(grid.letters.every((row) => row.length == level.gridSize), isTrue);
        // The bank is large enough relative to wordsPerPuzzle that placement
        // should always succeed for every word attempted.
        expect(grid.placedWords.length, level.wordsPerPuzzle);
      });

      test('${level.name}: every placed word is actually spelled out in the grid', () {
        final grid = GridGenerator.generate(
          level: level,
          bank: WordBanks.byLevel[level]!,
          random: Random(7),
        );

        for (final placed in grid.placedWords) {
          expect(placed.cells.length, placed.word.upper.length);
          for (var i = 0; i < placed.cells.length; i++) {
            final cell = placed.cells[i];
            expect(grid.letters[cell.row][cell.col], placed.word.upper[i]);
          }
        }
      });

      test('${level.name}: no placed word uses a disallowed diagonal direction', () {
        final grid = GridGenerator.generate(
          level: level,
          bank: WordBanks.byLevel[level]!,
          random: Random(99),
        );

        for (final placed in grid.placedWords) {
          if (placed.cells.length < 2) continue;
          final dr = placed.cells[1].row - placed.cells[0].row;
          final dc = placed.cells[1].col - placed.cells[0].col;
          final isDiagonal = dr != 0 && dc != 0;
          if (!level.allowDiagonals) {
            expect(isDiagonal, isFalse,
                reason: '${level.name} should never place words diagonally');
          }
        }
      });
    }

    test('every grid cell is a single uppercase letter', () {
      final grid = GridGenerator.generate(
        level: VocabLevel.basic,
        bank: WordBanks.basic,
        random: Random(1),
      );
      final letterPattern = RegExp(r'^[A-Z]$');
      for (final row in grid.letters) {
        for (final letter in row) {
          expect(letterPattern.hasMatch(letter), isTrue);
        }
      }
    });
  });
}
