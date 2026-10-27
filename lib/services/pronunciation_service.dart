import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'sound_service.dart';

/// Reads English words aloud with the device's own text-to-speech engine —
/// no bundled audio per word, so every word in every bank (and any added
/// later) gets a pronunciation for free.
///
/// Automatic read-outs follow the sound toggle (see [speak]). Every call is
/// best-effort — a phone with no English TTS voice installed, or an engine
/// that never answers, just stays silent rather than throwing into the
/// game loop. Setup is bounded by a timeout for the same reason
/// `safeSharedPrefs` exists: a platform call that never completes must not
/// leave the caller hanging.
class PronunciationService {
  PronunciationService._();
  static final PronunciationService instance = PronunciationService._();

  final FlutterTts _tts = FlutterTts();
  Future<bool>? _ready;

  Future<bool> _setUp() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        // Without this iOS speaks through the "ambient" category, which the
        // ring/silent switch mutes — and mixWithOthers keeps it from
        // stopping flame_audio's sound effects mid-play.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      }
      await _tts.setLanguage('en-US');
      // 0.5 is "normal" on both platforms in flutter_tts; slightly slower
      // suits learners hearing a word for the first time.
      await _tts.setSpeechRate(0.42);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// [onDemand] is for an explicit tap on a speaker button: that plays even
  /// with game sound muted, since the player just asked for it. Automatic
  /// read-outs (a word just found) respect the mute.
  Future<void> speak(String word, {bool onDemand = false}) async {
    if (!onDemand && !SoundService.instance.enabledNotifier.value) return;
    try {
      final ready = await (_ready ??= _setUp()).timeout(
        const Duration(seconds: 3),
      );
      if (!ready) return;
      await _tts.stop();
      // Banks store words uppercase; spoken as-is, many engines spell an
      // all-caps word out letter by letter like an acronym.
      await _tts.speak(word.toLowerCase());
    } catch (_) {
      // Silent — pronunciation is a nice-to-have, never a failure path.
    }
  }
}
