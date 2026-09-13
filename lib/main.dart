import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/ads_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdsService.instance.initialize();
  runApp(const WordSearchApp());
}

class WordSearchApp extends StatelessWidget {
  const WordSearchApp({super.key});

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
      home: const HomeScreen(),
    );
  }
}
