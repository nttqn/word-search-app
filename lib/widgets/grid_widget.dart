import 'dart:math';

import 'package:flutter/material.dart';

import '../game/grid_generator.dart';
import '../game/word_search_engine.dart';

const List<Color> _foundWordColors = [
  Color(0xFFE85D9C),
  Color(0xFF5DB4E8),
  Color(0xFF7CC576),
  Color(0xFFE8A75D),
  Color(0xFFB07CE8),
  Color(0xFFE85D5D),
  Color(0xFF5DE8C7),
  Color(0xFFE8D45D),
  Color(0xFF8C9EFF),
  Color(0xFFFF8A65),
  Color(0xFF4DD0E1),
  Color(0xFFAED581),
];

/// The letter grid: a single [GestureDetector] over the whole board converts
/// pan position to board-local cell coordinates (same
/// `RenderBox.globalToLocal` + `(local / cellSize).floor()` technique used by
/// block-puzzle-app's `BoardWidget`), snaps the drag to the nearest of the 8
/// straight-line directions, and live-highlights that path. On release the
/// path is handed to [WordSearchEngine.trySelect].
class GridWidget extends StatefulWidget {
  final WordSearchEngine engine;
  final void Function(PlacedWord word) onWordFound;

  const GridWidget({super.key, required this.engine, required this.onWordFound});

  @override
  State<GridWidget> createState() => _GridWidgetState();
}

class _GridWidgetState extends State<GridWidget> {
  final GlobalKey _boardKey = GlobalKey();
  double _cellSize = 0;
  Cell? _startCell;
  List<Cell> _dragPath = const [];
  bool _dragWasWrong = false;

  @override
  Widget build(BuildContext context) {
    final grid = widget.engine.grid;
    return AnimatedBuilder(
      animation: widget.engine,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final side = min(constraints.maxWidth, constraints.maxHeight);
            _cellSize = side / grid.size;
            final wordColors = <PlacedWord, Color>{
              for (var i = 0; i < grid.placedWords.length; i++)
                grid.placedWords[i]: _foundWordColors[i % _foundWordColors.length],
            };
            final foundCellColor = <Cell, Color>{};
            for (final w in widget.engine.foundWords) {
              final color = wordColors[w]!;
              for (final c in w.cells) {
                foundCellColor[c] = color;
              }
            }
            final hintCells = widget.engine.highlightedHintCells?.toSet() ?? const {};
            final dragCells = _dragPath.toSet();

            return Listener(
              onPointerDown: (e) => _onStart(e.position, grid.size),
              onPointerMove: (e) => _onUpdate(e.position, grid.size),
              onPointerUp: (_) => _onEnd(),
              onPointerCancel: (_) => _onCancel(),
              child: Container(
                key: _boardKey,
                width: side,
                height: side,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E9D2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  children: [
                    for (var r = 0; r < grid.size; r++)
                      for (var c = 0; c < grid.size; c++)
                        Positioned(
                          left: c * _cellSize,
                          top: r * _cellSize,
                          width: _cellSize,
                          height: _cellSize,
                          child: _CellView(
                            letter: grid.letters[r][c],
                            foundColor: foundCellColor[Cell(r, c)],
                            isHinted: hintCells.contains(Cell(r, c)),
                            isDragging: dragCells.contains(Cell(r, c)),
                            dragWasWrong: _dragWasWrong,
                          ),
                        ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Cell? _cellAt(Offset globalPosition, int gridSize) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _cellSize <= 0) return null;
    final local = box.globalToLocal(globalPosition);
    final col = (local.dx / _cellSize).floor();
    final row = (local.dy / _cellSize).floor();
    if (row < 0 || row >= gridSize || col < 0 || col >= gridSize) return null;
    return Cell(row.clamp(0, gridSize - 1), col.clamp(0, gridSize - 1));
  }

  void _onStart(Offset position, int gridSize) {
    final cell = _cellAt(position, gridSize);
    if (cell == null) return;
    setState(() {
      _startCell = cell;
      _dragPath = [cell];
      _dragWasWrong = false;
    });
  }

  void _onUpdate(Offset position, int gridSize) {
    final start = _startCell;
    if (start == null) return;
    final current = _cellAt(position, gridSize);
    if (current == null) return;
    final path = _straightLinePath(start, current);
    if (path.length != _dragPath.length || path.last != _dragPath.last) {
      setState(() => _dragPath = path);
    }
  }

  void _onEnd() {
    if (_startCell == null || _dragPath.length < 2) {
      _resetDrag();
      return;
    }
    final match = widget.engine.trySelect(_dragPath);
    if (match != null) {
      widget.onWordFound(match);
      _resetDrag();
    } else {
      setState(() => _dragWasWrong = true);
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _resetDrag();
      });
    }
  }

  void _onCancel() => _resetDrag();

  void _resetDrag() {
    if (!mounted) return;
    setState(() {
      _startCell = null;
      _dragPath = const [];
      _dragWasWrong = false;
    });
  }

  /// Snaps a start->current drag to the nearest of the 8 straight-line
  /// directions and returns every cell along that line, inclusive.
  static List<Cell> _straightLinePath(Cell start, Cell current) {
    final dr = current.row - start.row;
    final dc = current.col - start.col;
    if (dr == 0 && dc == 0) return [start];

    int stepR, stepC, length;
    if (dr == 0) {
      stepR = 0;
      stepC = dc.sign;
      length = dc.abs();
    } else if (dc == 0) {
      stepR = dr.sign;
      stepC = 0;
      length = dr.abs();
    } else if (dr.abs() == dc.abs()) {
      stepR = dr.sign;
      stepC = dc.sign;
      length = dr.abs();
    } else if (dr.abs() > 2 * dc.abs()) {
      stepR = dr.sign;
      stepC = 0;
      length = dr.abs();
    } else if (dc.abs() > 2 * dr.abs()) {
      stepR = 0;
      stepC = dc.sign;
      length = dc.abs();
    } else {
      stepR = dr.sign;
      stepC = dc.sign;
      length = min(dr.abs(), dc.abs());
    }

    return List.generate(
      length + 1,
      (k) => Cell(start.row + stepR * k, start.col + stepC * k),
    );
  }
}

class _CellView extends StatelessWidget {
  final String letter;
  final Color? foundColor;
  final bool isHinted;
  final bool isDragging;
  final bool dragWasWrong;

  const _CellView({
    required this.letter,
    required this.foundColor,
    required this.isHinted,
    required this.isDragging,
    required this.dragWasWrong,
  });

  @override
  Widget build(BuildContext context) {
    Color? bg;
    Color textColor = const Color(0xFF2A2A2A);
    if (foundColor != null) {
      bg = foundColor;
      textColor = Colors.white;
    } else if (isDragging) {
      bg = dragWasWrong
          ? const Color(0xFFEF5350).withValues(alpha: 0.6)
          : const Color(0xFF3D8BFD).withValues(alpha: 0.55);
      textColor = Colors.white;
    } else if (isHinted) {
      bg = const Color(0xFFFFD54F);
    }

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg),
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
          fontSize: 16,
        ),
      ),
    );
  }
}
