/// The four difficulty tiers. Each carries its own grid size, word count,
/// allowed placement directions, and (via [VocabLevelConfig] in
/// word_banks.dart) its own curated word bank.
enum VocabLevel { basic, intermediate, advanced, expert }

extension VocabLevelInfo on VocabLevel {
  String get label {
    switch (this) {
      case VocabLevel.basic:
        return 'Cơ bản';
      case VocabLevel.intermediate:
        return 'Trung cấp';
      case VocabLevel.advanced:
        return 'Nâng cao';
      case VocabLevel.expert:
        return 'Chuyên sâu';
    }
  }

  String get description {
    switch (this) {
      case VocabLevel.basic:
        return 'Từ vựng thông dụng, 3-6 chữ cái';
      case VocabLevel.intermediate:
        return 'Từ vựng hàng ngày, 5-8 chữ cái';
      case VocabLevel.advanced:
        return 'Từ vựng học thuật, 7-10 chữ cái';
      case VocabLevel.expert:
        return 'Từ vựng nâng cao, 9-13 chữ cái';
    }
  }

  /// Grid is [gridSize] x [gridSize].
  int get gridSize {
    switch (this) {
      case VocabLevel.basic:
        return 10;
      case VocabLevel.intermediate:
        return 12;
      case VocabLevel.advanced:
        return 13;
      case VocabLevel.expert:
        return 15;
    }
  }

  int get wordsPerPuzzle {
    switch (this) {
      case VocabLevel.basic:
        return 6;
      case VocabLevel.intermediate:
        return 8;
      case VocabLevel.advanced:
        return 10;
      case VocabLevel.expert:
        return 12;
    }
  }

  /// Basic only allows the 4 orthogonal directions (→ ← ↓ ↑, i.e. both
  /// reading directions on each axis) so early puzzles stay easy to scan.
  /// Every other level allows the full 8 directions (orthogonal + all 4
  /// diagonals, each usable in both directions along its axis).
  bool get allowDiagonals => this != VocabLevel.basic;
}
