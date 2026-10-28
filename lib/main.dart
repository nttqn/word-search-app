import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/ads_service.dart';
import 'services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.instance.initialize();
  // Fired unawaited, not awaited before runApp(): a missing/broken audio
  // asset can leave AudioPool.create()'s Future never resolving on web,
  // which would otherwise hang the whole app before its first frame.
  unawaited(SoundService.instance.init());
  runApp(const WordSearchApp());
}

class WordSearchApp extends StatelessWidget {
  /// Overridable only for lib/shots.dart's store screenshots.
  final Widget home;

  const WordSearchApp({super.key, this.home = const HomeScreen()});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WordHunt - Tra Từ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3D8BFD),
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B2436),
      ),
      home: home,
    );
  }
}
