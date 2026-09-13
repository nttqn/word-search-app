import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/word_banks.dart';
import '../game/grid_generator.dart';
import '../game/word_search_engine.dart';
import '../models/level.dart';
import '../services/ads_service.dart';
import '../services/leaderboard_service.dart';
import '../services/score_service.dart';
import '../services/sound_service.dart';
import '../widgets/app_background.dart';
import '../widgets/grid_widget.dart';
import '../widgets/sound_toggle_button.dart';
import '../widgets/word_list_widget.dart';

class GameScreen extends StatefulWidget {
  final VocabLevel level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WordSearchEngine _engine;
  BannerAd? _banner;

  @override
  void initState() {
    super.initState();
    _engine = WordSearchEngine(
      level: widget.level,
      bank: WordBanks.byLevel[widget.level]!,
    )..start();
    _loadBanner();
    unawaited(LeaderboardService.signIn());
  }

  void _loadBanner() {
    final banner = AdsService.instance.createBannerAd(
      onLoaded: () => mounted ? setState(() {}) : null,
    );
    _banner = banner;
  }

  @override
  void dispose() {
    _engine.dispose();
    _banner?.dispose();
    super.dispose();
  }

  void _onWordFound(PlacedWord word) {
    if (_engine.isComplete) {
      _onPuzzleComplete();
    }
  }

  Future<void> _onPuzzleComplete() async {
    SoundService.instance.play(SoundEffect.win);
    await ScoreService.instance.saveBest(widget.level, _engine.score);
    unawaited(LeaderboardService.submitScore(widget.level, _engine.score));
    AdsService.instance.maybeShowInterstitialAfterPuzzle();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CompletionDialog(
        score: _engine.score,
        elapsedSeconds: _engine.elapsedSeconds,
        onNewPuzzle: () {
          SoundService.instance.play(SoundEffect.confirm);
          Navigator.of(ctx).pop();
          setState(() => _engine.start());
        },
        onHome: () {
          SoundService.instance.play(SoundEffect.back);
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _onHint() {
    SoundService.instance.play(SoundEffect.hint);
    _engine.useHint();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _engine.clearHint();
    });
  }

  Future<void> _onBackPressed() async {
    SoundService.instance.play(SoundEffect.back);
    if (_engine.isComplete) {
      Navigator.of(context).pop();
      return;
    }
    _engine.pause();
    final quit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạm dừng'),
        content: Text('Điểm hiện tại: ${_engine.score}'),
        actions: [
          TextButton(
            onPressed: () {
              SoundService.instance.play(SoundEffect.back);
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Về trang chủ'),
          ),
          FilledButton(
            onPressed: () {
              SoundService.instance.play(SoundEffect.back);
              Navigator.of(ctx).pop(false);
            },
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (quit == true) {
      Navigator.of(context).pop();
    } else {
      _engine.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                _Hud(engine: _engine, onBack: _onBackPressed, level: widget.level),
                SizedBox(
                  height: 130,
                  child: WordListWidget(engine: _engine),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Center(
                      child: GridWidget(engine: _engine, onWordFound: _onWordFound),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _engine,
                  builder: (context, _) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _engine.hintsRemaining > 0 ? _onHint : null,
                        icon: const Icon(Icons.lightbulb_outline),
                        label: Text('Gợi ý  (${_engine.hintsRemaining})'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D6B),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_banner != null)
                  SizedBox(
                    width: _banner!.size.width.toDouble(),
                    height: _banner!.size.height.toDouble(),
                    child: AdWidget(ad: _banner!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final WordSearchEngine engine;
  final VocabLevel level;
  final VoidCallback onBack;

  const _Hud({required this.engine, required this.level, required this.onBack});

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          color: Colors.black.withValues(alpha: 0.25),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  spacing: 12,
                  children: [
                    _Stat(label: 'Từ', value: '${engine.foundWords.length}/${engine.grid.placedWords.length}'),
                    _Stat(label: 'Điểm', value: '${engine.score}'),
                    _Stat(label: 'Giờ', value: _formatTime(engine.elapsedSeconds)),
                  ],
                ),
              ),
              const SoundToggleButton(),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

class _CompletionDialog extends StatelessWidget {
  final int score;
  final int elapsedSeconds;
  final VoidCallback onNewPuzzle;
  final VoidCallback onHome;

  const _CompletionDialog({
    required this.score,
    required this.elapsedSeconds,
    required this.onNewPuzzle,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return AlertDialog(
      title: const Text('Hoàn thành! 🎉'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Điểm: $score'),
          Text('Thời gian: $m:$s'),
        ],
      ),
      actions: [
        TextButton(onPressed: onHome, child: const Text('Về trang chủ')),
        FilledButton(onPressed: onNewPuzzle, child: const Text('Puzzle mới')),
      ],
    );
  }
}
