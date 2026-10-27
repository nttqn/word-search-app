import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordhunt/game/grid_generator.dart';
import 'package:wordhunt/services/daily_challenge_service.dart';

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DailyChallengeService', () {
    final service = DailyChallengeService.instance;

    test('first-ever completion starts a streak of 1', () async {
      SharedPreferences.setMockInitialValues({});

      final streak = await service.recordCompletion();

      expect(streak, 1);
      expect(await service.isCompletedToday(), isTrue);
    });

    test(
      'completing again the same day does not double-count the streak',
      () async {
        SharedPreferences.setMockInitialValues({});
        await service.recordCompletion();

        final streak = await service.recordCompletion();

        expect(streak, 1);
      },
    );

    test('completing on the very next day extends the streak', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'daily_last_completed_date': _dateKey(yesterday),
        'daily_streak_current': 4,
      });

      final streak = await service.recordCompletion();

      expect(streak, 5);
    });

    test('missing a day resets the streak back to 1', () async {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      SharedPreferences.setMockInitialValues({
        'daily_last_completed_date': _dateKey(twoDaysAgo),
        'daily_streak_current': 4,
      });

      final streak = await service.recordCompletion();

      expect(streak, 1);
    });

    test('currentStreak reports 0 once a day has been missed', () async {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      SharedPreferences.setMockInitialValues({
        'daily_last_completed_date': _dateKey(twoDaysAgo),
        'daily_streak_current': 4,
      });

      expect(await service.currentStreak(), 0);
    });

    test(
      'currentStreak still counts a streak completed yesterday as alive',
      () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        SharedPreferences.setMockInitialValues({
          'daily_last_completed_date': _dateKey(yesterday),
          'daily_streak_current': 4,
        });

        expect(await service.currentStreak(), 4);
      },
    );

    test(
      'buildTodaySession is seeded so the actual generated grid is identical across calls',
      () {
        final a = service.buildTodaySession();
        final b = service.buildTodaySession();
        expect(a.shape.gridSize, b.shape.gridSize);

        final gridA = GridGenerator.generate(
          shape: a.shape,
          bank: a.bank,
          random: a.random,
        );
        final gridB = GridGenerator.generate(
          shape: b.shape,
          bank: b.bank,
          random: b.random,
        );

        expect(gridA.letters, gridB.letters);
        expect(
          gridA.placedWords.map((w) => w.word.upper),
          gridB.placedWords.map((w) => w.word.upper),
        );
      },
    );
  });
}
