import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordhunt/models/vocab_word.dart';
import 'package:wordhunt/services/review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReviewService', () {
    const apple = VocabWord('apple', 'quả táo');

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ReviewService.instance.resetCacheForTesting();
    });

    test('a newly found word is not due immediately', () async {
      await ReviewService.instance.onWordFound(apple);
      final due = await ReviewService.instance.dueWords();

      expect(due, isEmpty);
    });

    test('a word already due is promoted to a longer interval when found again', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'review_words_v1':
            '{"APPLE": {"box": 1, "due": "${yesterday.toIso8601String()}"}}',
      });

      final dueBefore = await ReviewService.instance.dueWords();
      expect(dueBefore, hasLength(1));
      expect(dueBefore.first.upper, 'APPLE');

      await ReviewService.instance.onWordFound(apple);
      final dueAfter = await ReviewService.instance.dueWords();
      // Box 1 -> box 2 pushes the next due date to +2 days out, so it's no
      // longer due right after being reviewed.
      expect(dueAfter, isEmpty);
    });

    test('finding a word before it is due does not change its schedule', () async {
      final farFuture = DateTime.now().add(const Duration(days: 10));
      SharedPreferences.setMockInitialValues({
        'review_words_v1':
            '{"APPLE": {"box": 3, "due": "${farFuture.toIso8601String()}"}}',
      });

      await ReviewService.instance.onWordFound(apple);
      final due = await ReviewService.instance.dueWords();

      // Still not due — replaying a level with a not-yet-due word must not
      // let the player "cheat" it into a longer interval early.
      expect(due, isEmpty);
    });

    test('dueCount matches dueWords for a small due set', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'review_words_v1':
            '{"APPLE": {"box": 1, "due": "${yesterday.toIso8601String()}"}}',
      });

      expect(await ReviewService.instance.dueCount(), 1);
    });
  });
}
