import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'daily_challenge_service.dart';
import 'review_service.dart';
import 'safe_prefs.dart';

class ReminderContent {
  final String title;
  final String body;
  const ReminderContent(this.title, this.body);
}

/// Evening "come back and play" notifications for the daily challenge and
/// the review queue.
///
/// There's no server, so these are local one-shot notifications for the
/// next few evenings, rebuilt from scratch every time the home screen
/// refreshes ([reschedule]). Their text is computed at scheduling time —
/// "Giữ chuỗi 5 ngày 🔥", "8 từ cần ôn" — which a single repeating daily
/// notification couldn't do. Scheduling only a few days ahead also means a
/// player who stops opening the app stops getting nagged after that.
///
/// Off until the player opts in (the home screen asks once, after they've
/// played at least one puzzle, and the bell button toggles it after that).
/// Every entry point is best-effort and a no-op on web — a notification
/// failing to schedule must never break the screen that asked for it.
class ReminderService {
  ReminderService._();
  static final ReminderService instance = ReminderService._();

  static const _enabledKey = 'reminders_enabled';
  static const _askedKey = 'reminders_asked';
  static const int reminderHour = 19;
  static const int _daysAhead = 3;
  static const int _baseId = 100;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminder',
      'Nhắc học hằng ngày',
      channelDescription: 'Nhắc thử thách hôm nay và các từ cần ôn tập',
      icon: 'ic_stat_wordhunt',
    ),
    iOS: DarwinNotificationDetails(),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  Future<bool>? _initialized;

  /// Mirrors the stored opt-in so the bell button can rebuild instantly.
  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);

  bool get _supported => !kIsWeb;

  Future<bool> _init() async {
    try {
      await _plugin
          .initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('ic_stat_wordhunt'),
              // Never prompt as a side effect of initializing — the prompt
              // belongs to the explicit opt-in in [setEnabled].
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
            ),
          )
          .timeout(const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _ensureInit() => _initialized ??= _init();

  Future<void> loadEnabled() async {
    final prefs = await safeSharedPrefs();
    enabledNotifier.value = prefs?.getBool(_enabledKey) ?? false;
  }

  /// Whether the home screen should show its one-time "turn on reminders?"
  /// prompt: never shown before, not already on, and supported here.
  Future<bool> shouldOfferOptIn() async {
    if (!_supported) return false;
    final prefs = await safeSharedPrefs();
    if (prefs == null) return false;
    return !(prefs.getBool(_askedKey) ?? false) &&
        !(prefs.getBool(_enabledKey) ?? false);
  }

  Future<void> markOptInOffered() async {
    final prefs = await safeSharedPrefs();
    await prefs?.setBool(_askedKey, true);
  }

  /// Turns reminders on (asking the OS for permission) or off. Returns the
  /// resulting state — `false` if the player denied the OS prompt.
  Future<bool> setEnabled(bool enabled) async {
    if (!_supported) return false;
    var granted = false;
    if (enabled && await _ensureInit()) {
      granted = await _requestPermission();
    }
    enabledNotifier.value = granted;
    final prefs = await safeSharedPrefs();
    await prefs?.setBool(_enabledKey, granted);
    await prefs?.setBool(_askedKey, true);
    await reschedule();
    return granted;
  }

  Future<bool> _requestPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Below Android 13 there's no runtime permission; the plugin
        // returns true there.
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Cancels and rebuilds the next few evenings' reminders from current
  /// progress. Cheap enough to call on every return to the home screen.
  Future<void> reschedule() async {
    if (!_supported || !await _ensureInit()) return;
    try {
      for (var i = 0; i <= _daysAhead; i++) {
        await _plugin.cancel(id: _baseId + i);
      }
      if (!enabledNotifier.value) return;

      final now = DateTime.now();
      final doneToday = await DailyChallengeService.instance.isCompletedToday();
      final streak = await DailyChallengeService.instance.currentStreak();
      for (var i = 0; i <= _daysAhead; i++) {
        final at = DateTime(now.year, now.month, now.day + i, reminderHour);
        if (!at.isAfter(now)) continue;
        // Nothing to nudge about tonight if today's challenge is done.
        if (i == 0 && doneToday) continue;
        final content = contentFor(
          // The streak is only still alive on the first evening the next
          // daily is owed: tonight if today's isn't done yet, otherwise
          // tomorrow. Any later reminder only fires if that one was
          // ignored, by which point the streak has already lapsed.
          streak: (i == 0 && !doneToday) || (i == 1 && doneToday) ? streak : 0,
          dueCount: await ReviewService.instance.dueCountAt(at),
        );
        await _plugin.zonedSchedule(
          id: _baseId + i,
          title: content.title,
          body: content.body,
          // UTC is enough for a one-shot at an absolute instant (no repeat
          // matching, so no DST/zone-name lookup), and avoids needing a
          // plugin just to read the device's IANA zone name.
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: _details,
          // Inexact needs no SCHEDULE_EXACT_ALARM permission; a reminder
          // landing a few minutes late doesn't matter.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // Best-effort — see class doc.
    }
  }

  /// The text for one evening's reminder, most motivating reason first.
  @visibleForTesting
  static ReminderContent contentFor({
    required int streak,
    required int dueCount,
  }) {
    if (streak > 0) {
      return ReminderContent(
        'Giữ chuỗi $streak ngày 🔥',
        dueCount > 0
            ? 'Thử thách hôm nay đang chờ bạn, cùng $dueCount từ cần ôn.'
            : 'Thử thách hôm nay đang chờ bạn — đừng để mất chuỗi nhé!',
      );
    }
    if (dueCount > 0) {
      return ReminderContent(
        'Đến giờ ôn từ vựng 📚',
        'Bạn có $dueCount từ cần ôn tập — chỉ mất vài phút thôi!',
      );
    }
    return const ReminderContent(
      'Thử thách hôm nay đã sẵn sàng',
      'Mỗi ngày một puzzle mới — vào tìm từ thôi!',
    );
  }
}
