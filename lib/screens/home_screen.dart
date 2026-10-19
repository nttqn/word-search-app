import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/game_session.dart';
import '../models/level.dart';
import '../services/ads_service.dart';
import '../services/daily_challenge_service.dart';
import '../services/leaderboard_service.dart';
import '../services/review_service.dart';
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
  int _dueCount = 0;
  int _dailyStreak = 0;
  bool _dailyCompletedToday = false;

  @override
  void initState() {
    super.initState();
    _loadBanner();
    _refreshProgress();
  }

  void _loadBanner() {
    final banner = AdsService.instance.createBannerAd(
      onLoaded: () => mounted ? setState(() {}) : null,
    );
    _banner = banner;
  }

  Future<void> _refreshProgress() async {
    final scores = <VocabLevel, int>{};
    for (final level in VocabLevel.values) {
      scores[level] = await ScoreService.instance.loadBest(level);
    }
    final dueCount = await ReviewService.instance.dueCount();
    final streak = await DailyChallengeService.instance.currentStreak();
    final completedToday = await DailyChallengeService.instance
        .isCompletedToday();
    if (!mounted) return;
    setState(() {
      _bestScores = scores;
      _dueCount = dueCount;
      _dailyStreak = streak;
      _dailyCompletedToday = completedToday;
    });
  }

  Future<void> _openLevel(VocabLevel level) async {
    SoundService.instance.play(SoundEffect.confirm);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(session: GameSession.level(level))),
    );
    _refreshProgress();
  }

  Future<void> _openReview() async {
    SoundService.instance.play(SoundEffect.confirm);
    final words = await ReviewService.instance.dueWords();
    if (!mounted) return;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có từ nào cần ôn tập — chơi thêm vài cấp độ nhé!'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(session: GameSession.review(words)),
      ),
    );
    _refreshProgress();
  }

  Future<void> _openDaily() async {
    SoundService.instance.play(SoundEffect.confirm);
    // Without this check, re-entering after already finishing today's
    // challenge silently rebuilt the exact same puzzle from scratch (0
    // found words, 0 score, timer restarted) — indistinguishable from the
    // player's progress having been lost, even though the streak itself
    // was unaffected underneath. A daily challenge only makes sense as a
    // one-shot per day, so block re-entry instead of quietly replaying it.
    final completedToday = await DailyChallengeService.instance.isCompletedToday();
    if (!mounted) return;
    if (completedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã hoàn thành thử thách hôm nay rồi — quay lại vào ngày mai nhé! 🔥'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          session: DailyChallengeService.instance.buildTodaySession(),
        ),
      ),
    );
    _refreshProgress();
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActionCard(
                                        icon: Icons.refresh,
                                        iconColor: const Color(0xFF9C6DE8),
                                        title: 'Ôn tập',
                                        subtitle: _dueCount > 0
                                            ? '$_dueCount từ cần ôn'
                                            : 'Chưa có từ cần ôn',
                                        badge: _dueCount > 0 ? '$_dueCount' : null,
                                        scale: scale,
                                        onTap: _openReview,
                                      ),
                                    ),
                                    SizedBox(width: 10 * scale),
                                    Expanded(
                                      child: _ActionCard(
                                        icon: _dailyCompletedToday
                                            ? Icons.check_circle
                                            : Icons.local_fire_department,
                                        iconColor: const Color(0xFFFF8A3D),
                                        title: 'Thử thách hôm nay',
                                        subtitle: _dailyCompletedToday
                                            ? 'Đã hoàn thành hôm nay'
                                            : (_dailyStreak > 0
                                                  ? 'Chuỗi: $_dailyStreak ngày'
                                                  : 'Chơi ngay!'),
                                        badge: _dailyStreak > 0
                                            ? '$_dailyStreak🔥'
                                            : null,
                                        scale: scale,
                                        onTap: _openDaily,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8 * scale),
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

/// Compact entry point for a non-level mode (review queue, daily
/// challenge) — visually lighter than [_LevelCard] (no leaderboard button,
/// no grid-size badge) since it sits two-up in a [Row] above the level
/// list rather than full-width.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final double scale;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.scale,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 12 * scale,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: iconColor, size: 26 * scale),
                  SizedBox(height: 6 * scale),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5 * scale,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 11 * scale,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 7 * scale,
                      vertical: 2 * scale,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: const Color(0xFF1A2A3A),
                        fontWeight: FontWeight.bold,
                        fontSize: 11 * scale,
                      ),
                    ),
                  ),
                ),
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
