import 'package:flutter/material.dart';

import '../game/word_search_engine.dart';

/// The word clue list: strikes a word through once found, revealing its
/// Vietnamese meaning right underneath — that reveal is the actual teaching
/// moment this game is built around.
///
/// The list sits in a fixed-height panel (see `GameScreen`) and most levels
/// have more words than fit at once, so this also shows small up/down
/// chevron badges whenever there's more content to scroll to in that
/// direction — a user playing an early build on a real phone couldn't tell
/// the panel was scrollable at all otherwise.
class WordListWidget extends StatefulWidget {
  final WordSearchEngine engine;
  const WordListWidget({super.key, required this.engine});

  @override
  State<WordListWidget> createState() => _WordListWidgetState();
}

class _WordListWidgetState extends State<WordListWidget> {
  final ScrollController _controller = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateScrollAffordance);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollAffordance());
  }

  void _updateScrollAffordance() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final canUp = position.pixels > 2;
    final canDown = position.pixels < position.maxScrollExtent - 2;
    if (canUp != _canScrollUp || canDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canUp;
        _canScrollDown = canDown;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.engine,
      builder: (context, _) {
        final words = widget.engine.grid.placedWords;
        // The found/total count changing can change whether the list still
        // overflows its panel, so re-check after this rebuild lays out.
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollAffordance());
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ListView.builder(
              controller: _controller,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: words.length,
              itemBuilder: (context, i) {
                final placed = words[i];
                final found = widget.engine.foundWords.contains(placed);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        found ? Icons.check_circle : Icons.circle_outlined,
                        size: 16,
                        color: found ? Colors.greenAccent : Colors.white54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              placed.word.upper,
                              style: TextStyle(
                                color: found ? Colors.white54 : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                decoration: found
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                              ),
                            ),
                            if (found)
                              Text(
                                placed.word.meaningVi,
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (_canScrollUp) const _ScrollHint(alignment: Alignment.topCenter),
            if (_canScrollDown) const _ScrollHint(alignment: Alignment.bottomCenter),
          ],
        );
      },
    );
  }
}

class _ScrollHint extends StatelessWidget {
  final Alignment alignment;
  const _ScrollHint({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final isTop = alignment == Alignment.topCenter;
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isTop ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 18,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
