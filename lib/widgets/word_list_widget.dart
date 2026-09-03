import 'package:flutter/material.dart';

import '../game/word_search_engine.dart';

/// The word clue list: strikes a word through once found, revealing its
/// Vietnamese meaning right underneath — that reveal is the actual teaching
/// moment this game is built around.
class WordListWidget extends StatelessWidget {
  final WordSearchEngine engine;
  const WordListWidget({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: engine,
      builder: (context, _) {
        final words = engine.grid.placedWords;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: words.length,
          itemBuilder: (context, i) {
            final placed = words[i];
            final found = engine.foundWords.contains(placed);
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
        );
      },
    );
  }
}
