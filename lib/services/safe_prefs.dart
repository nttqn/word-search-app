import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences.getInstance()` wrapped so it can never leave a caller
/// hanging — a real-device report showed it taking long enough (or never
/// resolving at all) to make "Hoàn thành" dialogs, high-score saves, and
/// the daily-challenge button all read as broken/unresponsive, each in a
/// different service that called the plugin directly with no timeout.
/// Every shared_preferences access in this app should go through this
/// instead of calling `SharedPreferences.getInstance()` itself — returns
/// `null` on timeout or any error rather than throwing, so callers always
/// have a safe, explicit "couldn't read/write this time" case to fall back
/// on instead of silently hanging forever.
Future<SharedPreferences?> safeSharedPrefs({
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    return await SharedPreferences.getInstance().timeout(timeout);
  } catch (_) {
    return null;
  }
}
