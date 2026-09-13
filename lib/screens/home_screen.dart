import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/level.dart';
import '../services/ads_service.dart';
import '../services/leaderboard_service.dart';
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

  Future<void> _openLeaderboard(VocabLevel level) async {
    final opened = await LeaderboardService.showLeaderboard(level);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bảng xếp hạng chưa khả dụng.')),
      );
    }
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
                        onLeaderboardTap: () => _openLeaderboard(level),
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
  final VoidCallback onLeaderboardTap;

  const _LevelCard({
    required this.level,
    required this.bestScore,
    required this.onTap,
    required this.onLeaderboardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          // The leaderboard button is a Row *sibling* of this InkWell, not
          // nested inside it — nesting two tappables at the same point both
          // fire in Flutter (they don't stop each other's hit-testing the
          // way a DOM click would), which would open the level *and* the
          // leaderboard on one tap. Matches block-puzzle-app's
          // `_ModeButton` + trophy `IconButton` sibling layout.
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
          ),
          IconButton(
            onPressed: onLeaderboardTap,
            icon: const Icon(Icons.leaderboard, color: Colors.amberAccent),
            tooltip: 'Bảng xếp hạng ${level.label}',
          ),
        ],
      ),
    );
  }
}
