import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/level.dart';
import '../services/ads_service.dart';
import '../services/score_service.dart';
import '../widgets/app_background.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BannerAd? _banner;
  Map<VocabLevel, int> _bestScores = const {};

  @override
  void initState() {
    super.initState();
    _loadBanner();
    _loadBestScores();
  }

  void _loadBanner() {
    final banner = AdsService.instance.createBannerAd(
      onLoaded: () => mounted ? setState(() {}) : null,
    );
    _banner = banner;
  }

  Future<void> _loadBestScores() async {
    final scores = <VocabLevel, int>{};
    for (final level in VocabLevel.values) {
      scores[level] = await ScoreService.instance.loadBest(level);
    }
    if (mounted) setState(() => _bestScores = scores);
  }

  Future<void> _openLevel(VocabLevel level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(level: level)),
    );
    _loadBestScores();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.search, color: Colors.white, size: 48),
              const SizedBox(height: 8),
              const Text(
                'Word Search',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Học Từ Vựng Tiếng Anh',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    for (final level in VocabLevel.values)
                      _LevelCard(
                        level: level,
                        bestScore: _bestScores[level] ?? 0,
                        onTap: () => _openLevel(level),
                      ),
                  ],
                ),
              ),
              if (_banner != null)
                SizedBox(
                  width: _banner!.size.width.toDouble(),
                  height: _banner!.size.height.toDouble(),
                  child: AdWidget(ad: _banner!),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final VocabLevel level;
  final int bestScore;
  final VoidCallback onTap;

  const _LevelCard({
    required this.level,
    required this.bestScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D8BFD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${level.gridSize}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      level.description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Điểm cao: $bestScore',
                      style: const TextStyle(
                        color: Color(0xFFFFD54F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
