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
          // Phone-designed UI, never built for a tablet-size canvas. Just
          // capping the content at a fixed phone width (the original fix)
          // avoided the "tiny letters in huge cells" bug but overcorrected
          // into "the whole app looks small and lost" on a real iPad
          // screen — flagged by the user from an actual iPad-resolution
          // screenshot. This still caps width (so it never regresses back
          // to the original full-bleed-stretch bug) but now also scales
          // every size in the level list proportionally to how much extra
          // width is actually available, via `scale` — not just a wider
          // box with the same small fixed font sizes. See CLAUDE.md's
          // "iPad" section for both rounds of this fix.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 420).clamp(1.0, 1.8);
                  return Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          Image.asset('assets/title/title.png', width: 320 * scale),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20 * scale,
                                vertical: 8,
                              ),
                              children: [
                                for (final level in VocabLevel.values)
                                  _LevelCard(
                                    level: level,
                                    bestScore: _bestScores[level] ?? 0,
                                    scale: scale,
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
                  );
                },
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
  final double scale;
  final VoidCallback onTap;
  final VoidCallback onLeaderboardTap;

  const _LevelCard({
    required this.level,
    required this.bestScore,
    required this.scale,
    required this.onTap,
    required this.onLeaderboardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      margin: EdgeInsets.only(bottom: 12 * scale),
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
                padding: EdgeInsets.symmetric(
                  horizontal: 16 * scale,
                  vertical: 14 * scale,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48 * scale,
                      height: 48 * scale,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D8BFD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${level.gridSize}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16 * scale,
                        ),
                      ),
                    ),
                    SizedBox(width: 14 * scale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            level.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17 * scale,
                            ),
                          ),
                          Text(
                            level.description,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12 * scale,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            'Điểm cao: $bestScore',
                            style: TextStyle(
                              color: const Color(0xFFFFD54F),
                              fontSize: 12 * scale,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white54, size: 24 * scale),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onLeaderboardTap,
            icon: Icon(Icons.leaderboard, color: Colors.amberAccent, size: 24 * scale),
            tooltip: 'Bảng xếp hạng ${level.label}',
          ),
        ],
      ),
    );
  }
}
