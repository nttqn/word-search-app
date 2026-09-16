import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/level.dart';
import '../services/ads_service.dart';
import '../services/leaderboard_service.dart';
import '../services/score_service.dart';
import '../services/sound_service.dart';
import '../widgets/app_background.dart';
import '../widgets/sound_toggle_button.dart';
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
    SoundService.instance.play(SoundEffect.confirm);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(level: level)),
    );
    _loadBestScores();
  }

  Future<void> _openLeaderboard(VocabLevel level) async {
    SoundService.instance.play(SoundEffect.confirm);
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
          // Phone-proportioned UI, never designed for a tablet-size canvas —
          // rather than letting everything stretch full-bleed (huge dead
          // space below content, oversized cards), cap the whole screen's
          // content at a phone-like width and center it. This is the same
          // "centered phone UI with side margins" pattern most simple
          // universal (iPhone+iPad) games use rather than a true tablet
          // redesign — see CLAUDE.md's "iPad" section for the screenshot
          // that showed why this was needed.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Stack(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      Image.asset('assets/title/title.png', width: 320),
                      const SizedBox(height: 8),
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
                  const Positioned(
                    top: 4,
                    right: 4,
                    child: SoundToggleButton(),
                  ),
                ],
              ),
            ),
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
