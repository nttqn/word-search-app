import '../models/level.dart';
import 'safe_prefs.dart';

/// Persists each level's best score locally via shared_preferences, one key
/// per [VocabLevel] since puzzles differ in size/word count across levels.
class ScoreService {
  ScoreService._();
  static final ScoreService instance = ScoreService._();

  String _key(VocabLevel level) => 'best_score_${level.name}';

  Future<int> loadBest(VocabLevel level) async {
    final prefs = await safeSharedPrefs();
    if (prefs == null) return 0;
    return prefs.getInt(_key(level)) ?? 0;
  }

  Future<void> saveBest(VocabLevel level, int value) async {
    final prefs = await safeSharedPrefs();
    if (prefs == null) return;
    final current = prefs.getInt(_key(level)) ?? 0;
    if (value > current) {
      await prefs.setInt(_key(level), value);
    }
  }
}
