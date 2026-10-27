import 'package:flutter/material.dart';

import '../services/pronunciation_service.dart';
import '../services/review_service.dart';
import '../services/sound_service.dart';
import '../widgets/app_background.dart';

enum _Filter { all, due, mastered }

/// "Sổ từ của tôi": every word the player has found so far, with its
/// meaning, how well it's remembered (the spaced-repetition box as dots),
/// and a speaker button. Purely a view over [ReviewService]'s data — it
/// never changes any schedule itself; only finding a word in a puzzle does.
class WordBookScreen extends StatefulWidget {
  const WordBookScreen({super.key});

  @override
  State<WordBookScreen> createState() => _WordBookScreenState();
}

class _WordBookScreenState extends State<WordBookScreen> {
  List<WordProgress>? _words;
  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final words = await ReviewService.instance.allWords();
    words.sort((a, b) => a.word.upper.compareTo(b.word.upper));
    if (!mounted) return;
    setState(() => _words = words);
  }

  List<WordProgress> _visible(DateTime now) {
    final q = _query.trim().toLowerCase();
    return [
      for (final w in _words ?? const <WordProgress>[])
        if (switch (_filter) {
              _Filter.all => true,
              _Filter.due => w.isDueAt(now),
              _Filter.mastered => w.isMastered,
            } &&
            (q.isEmpty ||
                w.word.word.toLowerCase().contains(q) ||
                w.word.meaningVi.toLowerCase().contains(q)))
          w,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final words = _words;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          // Same width cap + proportional scale as HomeScreen/GameScreen.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final scale = (constraints.maxWidth / 420).clamp(1.0, 1.8);
                  return Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(4, 8 * scale, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                SoundService.instance.play(SoundEffect.back);
                                Navigator.of(context).pop();
                              },
                              icon: Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 24 * scale,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Sổ từ của tôi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20 * scale,
                                ),
                              ),
                            ),
                            if (words != null)
                              Text(
                                '${words.length} từ',
                                style: TextStyle(
                                  color: const Color(0xFFFFD54F),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14 * scale,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          16 * scale,
                          8 * scale,
                          16 * scale,
                          4 * scale,
                        ),
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          style: TextStyle(fontSize: 15 * scale),
                          decoration: InputDecoration(
                            hintText: 'Tìm từ tiếng Anh hoặc nghĩa…',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * scale),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final (filter, label) in const [
                              (_Filter.all, 'Tất cả'),
                              (_Filter.due, 'Cần ôn'),
                              (_Filter.mastered, 'Đã thuộc'),
                            ])
                              ChoiceChip(
                                label: Text(
                                  label,
                                  style: TextStyle(fontSize: 13 * scale),
                                ),
                                selected: _filter == filter,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.08,
                                ),
                                side: BorderSide.none,
                                onSelected: (_) =>
                                    setState(() => _filter = filter),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: words == null
                            ? const Center(child: CircularProgressIndicator())
                            : _buildList(_visible(now), now, scale),
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

  Widget _buildList(List<WordProgress> visible, DateTime now, double scale) {
    if (visible.isEmpty) {
      final message = (_words?.isEmpty ?? true)
          ? 'Chưa có từ nào — tìm được từ nào trong puzzle, từ đó sẽ vào sổ.'
          : 'Không có từ nào khớp.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14 * scale),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16 * scale, 8, 16 * scale, 16),
      itemCount: visible.length,
      itemBuilder: (context, i) =>
          _WordTile(progress: visible[i], now: now, scale: scale),
    );
  }
}

class _WordTile extends StatelessWidget {
  final WordProgress progress;
  final DateTime now;
  final double scale;

  const _WordTile({
    required this.progress,
    required this.now,
    required this.scale,
  });

  String get _status {
    if (progress.isDueAt(now)) return 'Cần ôn';
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      progress.due.year,
      progress.due.month,
      progress.due.day,
    );
    final days = dueDay.difference(today).inDays;
    return days <= 0 ? 'Ôn lại hôm nay' : 'Ôn lại sau $days ngày';
  }

  @override
  Widget build(BuildContext context) {
    final due = progress.isDueAt(now);
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      margin: EdgeInsets.only(bottom: 8 * scale),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * scale, 10 * scale, 4, 10 * scale),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.word.upper,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16 * scale,
                    ),
                  ),
                  Text(
                    progress.word.meaningVi,
                    style: TextStyle(
                      color: const Color(0xFFFFD54F),
                      fontSize: 13 * scale,
                    ),
                  ),
                  SizedBox(height: 6 * scale),
                  Row(
                    children: [
                      for (var b = 1; b <= WordProgress.maxBox; b++)
                        Container(
                          width: 8 * scale,
                          height: 8 * scale,
                          margin: EdgeInsets.only(right: 3 * scale),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: b <= progress.box
                                ? Colors.greenAccent
                                : Colors.white24,
                          ),
                        ),
                      SizedBox(width: 8 * scale),
                      Text(
                        _status,
                        style: TextStyle(
                          color: due ? const Color(0xFFFF8A3D) : Colors.white54,
                          fontSize: 11 * scale,
                          fontWeight: due ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => PronunciationService.instance.speak(
                progress.word.word,
                onDemand: true,
              ),
              icon: Icon(
                Icons.volume_up,
                color: Colors.white70,
                size: 24 * scale,
              ),
              tooltip: 'Nghe phát âm',
            ),
          ],
        ),
      ),
    );
  }
}
