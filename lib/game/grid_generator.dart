import 'dart:math';

import '../models/level.dart';
import '../models/vocab_word.dart';

/// A single grid coordinate. Deliberately Flutter-free (no `Offset`) so this
/// whole file stays plain-Dart and unit-testable without pumping widgets.
class Cell {
  final int row;
  final int col;
  const Cell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

/// One word successfully placed in the grid, in reading order (index 0 is
/// where a player must start dragging, last index is where they release —
/// though [WordSearchEngine] also accepts the reverse drag direction).
class PlacedWord {
  final VocabWord word;
  final List<Cell> cells;
  const PlacedWord(this.word, this.cells);
}

class WordSearchGrid {
  final int size;
  final List<List<String>> letters;
  final List<PlacedWord> placedWords;
  const WordSearchGrid(this.size, this.letters, this.placedWords);
}

/// The 8 possible unit direction vectors a word can be placed along.
/// Basic-level puzzles only use the first 4 (pure orthogonal); every other
/// level uses all 8.
const List<Cell> _orthogonalDirections = [
  Cell(0, 1), // East
  Cell(0, -1), // West
  Cell(1, 0), // South
  Cell(-1, 0), // North
];

const List<Cell> _diagonalDirections = [
  Cell(1, 1), // South-East
  Cell(1, -1), // South-West
  Cell(-1, 1), // North-East
  Cell(-1, -1), // North-West
];

class GridGenerator {
  GridGenerator._();

  static const int _maxAttemptsPerWord = 60;

  /// Builds a fresh puzzle: picks [level.wordsPerPuzzle] random words from
  /// [bank] (skipping any longer than the grid), places each one (retrying
  /// random position/direction up to [_maxAttemptsPerWord] times; a word
  /// that never fits is dropped and backfilled from the remaining bank), then
  /// fills every empty cell with a random letter.
  static WordSearchGrid generate({
    required VocabLevel level,
    required List<VocabWord> bank,
    Random? random,
  }) {
    final rng = random ?? Random();
    final size = level.gridSize;
    final directions = [
      ..._orthogonalDirections,
      if (level.allowDiagonals) ..._diagonalDirections,
    ];

    final candidates = bank.where((w) => w.upper.length <= size).toList()
      ..shuffle(rng);

    final grid = List.generate(size, (_) => List<String?>.filled(size, null));
    final placed = <PlacedWord>[];

    var i = 0;
    while (placed.length < level.wordsPerPuzzle && i < candidates.length) {
      final word = candidates[i++];
      final cells = _tryPlace(grid, word.upper, size, directions, rng);
      if (cells != null) {
        placed.add(PlacedWord(word, cells));
      }
    }

    final letters = List.generate(
      size,
      (r) => List.generate(
        size,
        (c) => grid[r][c] ?? _randomLetter(rng),
      ),
    );

    return WordSearchGrid(size, letters, placed);
  }

  static List<Cell>? _tryPlace(
    List<List<String?>> grid,
    String word,
    int size,
    List<Cell> directions,
    Random rng,
  ) {
    for (var attempt = 0; attempt < _maxAttemptsPerWord; attempt++) {
      final dir = directions[rng.nextInt(directions.length)];
      final startRow = rng.nextInt(size);
      final startCol = rng.nextInt(size);
      final endRow = startRow + dir.row * (word.length - 1);
      final endCol = startCol + dir.col * (word.length - 1);
      if (endRow < 0 || endRow >= size || endCol < 0 || endCol >= size) {
        continue;
      }

      final cells = List.generate(
        word.length,
        (k) => Cell(startRow + dir.row * k, startCol + dir.col * k),
      );

      final fits = cells.indexed.every((entry) {
        final (k, cell) = entry;
        final existing = grid[cell.row][cell.col];
        return existing == null || existing == word[k];
      });
      if (!fits) continue;

      for (final entry in cells.indexed) {
        final (k, cell) = entry;
        grid[cell.row][cell.col] = word[k];
      }
      return cells;
    }
    return null;
  }

  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static String _randomLetter(Random rng) =>
      _alphabet[rng.nextInt(_alphabet.length)];
}
