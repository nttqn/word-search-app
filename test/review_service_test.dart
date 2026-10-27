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

    test(
      'a word already due is promoted to a longer interval when found again',
      () async {
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
      },
    );

    test(
      'finding a word before it is due does not change its schedule',
      () async {
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
      },
    );

    test('dueCount matches dueWords for a small due set', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'review_words_v1':
            '{"APPLE": {"box": 1, "due": "${yesterday.toIso8601String()}"}}',
      });

      expect(await ReviewService.instance.dueCount(), 1);
    });

    test(
      'onWordsFound records every word from a single batched write',
      () async {
        const cloud = VocabWord('cloud', 'đám mây');
        const storm = VocabWord('storm', 'cơn bão');

        await ReviewService.instance.onWordsFound([apple, cloud, storm]);

        // None due yet (just entered box 1), but all three must have actually
        // been written — reload via a fresh cache to prove it persisted
        // rather than only living in this instance's in-memory map.
        ReviewService.instance.resetCacheForTesting();
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('review_words_v1')!;
        expect(raw, contains('APPLE'));
        expect(raw, contains('CLOUD'));
        expect(raw, contains('STORM'));
      },
    );

    test(
      'onWordsFound promotes already-due words the same as onWordFound',
      () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        SharedPreferences.setMockInitialValues({
          'review_words_v1':
              '{"APPLE": {"box": 1, "due": "${yesterday.toIso8601String()}"}}',
        });

        await ReviewService.instance.onWordsFound([apple]);
        final due = await ReviewService.instance.dueWords();

        expect(due, isEmpty);
      },
    );
    test('dueCountAt counts words that will have come due by then', () async {
      await ReviewService.instance.onWordFound(apple);

      expect(await ReviewService.instance.dueCount(), 0);
      // Box 1 = due one day after being found.
      final tomorrowEvening = DateTime.now().add(
        const Duration(days: 1, hours: 1),
      );
      expect(await ReviewService.instance.dueCountAt(tomorrowEvening), 1);
    });

    test('allWords exposes each tracked word with its box', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'review_words_v1':
            '{"APPLE": {"box": 4, "due": "${yesterday.toIso8601String()}"},'
            ' "NOT_A_BANK_WORD": {"box": 1, "due": "${yesterday.toIso8601String()}"}}',
      });

      final words = await ReviewService.instance.allWords();

      // Unknown keys (removed from the banks later) are skipped.
      expect(words, hasLength(1));
      expect(words.single.word.upper, 'APPLE');
      expect(words.single.box, 4);
      expect(words.single.isMastered, isTrue);
      expect(words.single.isDueAt(DateTime.now()), isTrue);
    });
  });
}
