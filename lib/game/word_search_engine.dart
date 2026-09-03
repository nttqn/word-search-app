import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/level.dart';
import '../models/vocab_word.dart';
import 'grid_generator.dart';

/// Whole-puzzle game state for one level. Deliberately Flutter-widget-free
/// (only `ChangeNotifier`/`kDebugMode`-style foundation imports) so it stays
/// unit-testable without pumping any widgets — same split as
/// block-puzzle-app's `GameEngine`.
class WordSearchEngine extends ChangeNotifier {
  // A required named param can't directly initialize a private field
  // (`this._bank`) since callers outside this library can't reference a
  // private named parameter — hence the public `bank` param assigned to
  // `_bank` below instead.
  WordSearchEngine({
    required this.level,
    required List<VocabWord> bank,
    Random? random,
  }) : _bank = bank, // ignore: prefer_initializing_formals
       _random = random ?? Random();

  final VocabLevel level;
  final List<VocabWord> _bank;
  final Random _random;

  static const int maxHints = 3;

  late WordSearchGrid grid;
  final Set<PlacedWord> foundWords = {};
  int score = 0;
  int elapsedSeconds = 0;
  int hintsRemaining = maxHints;
  List<Cell>? highlightedHintCells;
  bool paused = false;
  bool _started = false;

  Timer? _ticker;

  bool get isComplete =>
      _started && foundWords.length == grid.placedWords.length;

  /// Generates a fresh grid and resets score/time/hints. Call once per
  /// puzzle attempt (initial start, or "new puzzle" from the completion
  /// dialog).
  void start() {
    _ticker?.cancel();
    grid = GridGenerator.generate(level: level, bank: _bank, random: _random);
    foundWords.clear();
    score = 0;
    elapsedSeconds = 0;
    hintsRemaining = maxHints;
    highlightedHintCells = null;
    paused = false;
    _started = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
    notifyListeners();
  }

  void _tick(Timer timer) {
    if (paused || isComplete) return;
    elapsedSeconds++;
    notifyListeners();
  }

  void pause() {
    if (paused || isComplete) return;
    paused = true;
    notifyListeners();
  }

  void resume() {
    if (!paused) return;
    paused = false;
    notifyListeners();
  }

  /// Checks a dragged cell path against every unfound word (matching either
  /// reading direction, so the player can drag from either end). Returns the
  /// matched word, or `null` if the path doesn't spell any remaining word.
  PlacedWord? trySelect(List<Cell> path) {
    if (paused || isComplete || path.length < 2) return null;
    for (final candidate in grid.placedWords) {
      if (foundWords.contains(candidate)) continue;
      if (_sameCells(candidate.cells, path) ||
          _sameCells(candidate.cells.reversed.toList(), path)) {
        foundWords.add(candidate);
        score += candidate.word.upper.length * 10;
        if (isComplete) {
          _ticker?.cancel();
          final timeBonus = max(0, 300 - elapsedSeconds) ~/ 5;
          score += timeBonus;
        }
        notifyListeners();
        return candidate;
      }
    }
    return null;
  }

  bool _sameCells(List<Cell> a, List<Cell> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Reveals a random unfound word's cells for a couple of seconds (cleared
  /// by the caller via [clearHint], mirroring how [GameScreen] owns the
  /// `Future.delayed` for its other transient UI effects).
  void useHint() {
    if (hintsRemaining <= 0 || paused || isComplete) return;
    final unfound = grid.placedWords
        .where((w) => !foundWords.contains(w))
        .toList();
    if (unfound.isEmpty) return;
    hintsRemaining--;
    highlightedHintCells = unfound[_random.nextInt(unfound.length)].cells;
    notifyListeners();
  }

  void clearHint() {
    if (highlightedHintCells == null) return;
    highlightedHintCells = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
