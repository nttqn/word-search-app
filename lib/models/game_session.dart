import 'dart:math';

import '../data/word_banks.dart';
import 'level.dart';
import 'vocab_word.dart';

/// What a [GameSession] is for, beyond just "run this puzzle" — `GameScreen`
/// uses this to decide which side effects a completed puzzle should have
/// (best-score/leaderboard for a level, streak for daily, nothing extra for
/// review beyond the per-word spaced-repetition update every mode already
/// gets).
enum GameMode { level, review, daily }

/// Everything `GameScreen` needs to run one puzzle, independent of whether
/// it came from picking a difficulty tier, the review queue, or today's
/// daily challenge. Replaces the old `GameScreen(level: VocabLevel)` — see
/// CLAUDE.md's "Review mode & daily challenge" section for why `VocabLevel`
/// alone stopped being enough once puzzles could be built from an arbitrary
/// word list instead of one level's curated bank.
class GameSession {
  final GameMode mode;
  final String title;
  final PuzzleShape shape;
  final List<VocabWord> bank;
  // Only set for [GameMode.level] — ScoreService/LeaderboardService are
  // keyed per VocabLevel and have no equivalent concept for review/daily.
  final VocabLevel? level;
  // Daily challenge seeds this so the same puzzle shows all day regardless
  // of how many times the player backs out and reopens it.
  final Random? random;

  const GameSession({
    required this.mode,
    required this.title,
    required this.shape,
    required this.bank,
    this.level,
    this.random,
  });

  factory GameSession.level(VocabLevel level) => GameSession(
    mode: GameMode.level,
    title: level.label,
    shape: level.shape,
    bank: WordBanks.byLevel[level]!,
    level: level,
  );

  /// Builds a review-mode session from whatever words are currently due
  /// (see `ReviewService.dueWords`). The grid is sized to the longest word
  /// in the set (clamped to the same 10-15 range normal levels use) rather
  /// than reusing one fixed level's shape, since due words can span every
  /// difficulty tier at once.
  factory GameSession.review(List<VocabWord> words) {
    final longest = words.fold<int>(
      3,
      (max, w) => w.upper.length > max ? w.upper.length : max,
    );
    final gridSize = (longest + 3).clamp(10, 15);
    return GameSession(
      mode: GameMode.review,
      title: 'Ôn tập',
      shape: PuzzleShape(
        gridSize: gridSize,
        wordsPerPuzzle: words.length,
        allowDiagonals: true,
      ),
      bank: words,
    );
  }
}
