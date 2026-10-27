import 'package:flutter_test/flutter_test.dart';
import 'package:wordhunt/services/reminder_service.dart';

void main() {
  group('ReminderService.contentFor', () {
    test('a live streak leads the message', () {
      final c = ReminderService.contentFor(streak: 5, dueCount: 8);
      expect(c.title, contains('5 ngày'));
      expect(c.body, contains('8 từ'));
    });

    test('a live streak with nothing due still nudges the daily', () {
      final c = ReminderService.contentFor(streak: 2, dueCount: 0);
      expect(c.title, contains('2 ngày'));
      expect(c.body, isNot(contains('từ cần ôn')));
    });

    test('no streak falls back to the review queue', () {
      final c = ReminderService.contentFor(streak: 0, dueCount: 3);
      expect(c.body, contains('3 từ'));
    });

    test('nothing at all still has a generic daily-challenge message', () {
      final c = ReminderService.contentFor(streak: 0, dueCount: 0);
      expect(c.title, isNotEmpty);
      expect(c.body, isNotEmpty);
    });
  });
}
