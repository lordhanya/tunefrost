import 'package:flutter/material.dart';

import 'package:music_player/core/utils/haptics.dart';

/// A–Z index rail for jumping through a uniformly-sized, alphabetically
/// sorted list. Drag or tap a letter to scroll there; the letter currently
/// at the top of the list is highlighted.
///
/// The list must use a fixed `itemExtent` so jumps can map letter → offset.
/// [topPadding] should match the list's `contentPadding.top`.
class AlphabetScrollbar extends StatefulWidget {
  const AlphabetScrollbar({
    super.key,
    required this.controller,
    required this.labels,
    required this.itemExtent,
    required this.topPadding,
    this.bottomPadding = 0,
  });

  final ScrollController controller;

  /// First letter of every row (`'#'` for non A–Z), in list order.
  final List<String> labels;

  /// Uniform row height of the attached list.
  final double itemExtent;

  /// Scroll offset of row 0 (the list's top content padding).
  final double topPadding;

  /// Scroll offset past the last row, if any (list's bottom padding).
  final double bottomPadding;

  static const rail = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '#',
  ];

  /// Cheap sortedness check so caller-ordered lists can opt out.
  static bool isSorted(List<String> labels) {
    for (var i = 1; i < labels.length; i++) {
      if (labels[i].compareTo(labels[i - 1]) < 0) return false;
    }
    return true;
  }

  @override
  State<AlphabetScrollbar> createState() => _AlphabetScrollbarState();
}

class _AlphabetScrollbarState extends State<AlphabetScrollbar> {
  String _active = '';
  String _soughtLetter = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    _onScroll();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.labels.isEmpty || !widget.controller.hasClients) return;
    final index =
        ((widget.controller.offset - widget.topPadding) / widget.itemExtent)
            .floor()
            .clamp(0, widget.labels.length - 1);
    final letter = widget.labels[index];
    if (letter != _active) {
      setState(() => _active = letter);
    }
  }

  /// First row whose label is >= [letter] (labels are sorted, `'#'` < `'A'`).
  int _targetIndex(String letter) {
    for (var i = 0; i < widget.labels.length; i++) {
      if (widget.labels[i].compareTo(letter) >= 0) return i;
    }
    return widget.labels.length - 1;
  }

  void _seek(double dy, double height) {
    if (widget.labels.isEmpty || height == 0 || !widget.controller.hasClients) {
      return;
    }
    final railIndex = (dy / height * AlphabetScrollbar.rail.length)
        .floor()
        .clamp(0, AlphabetScrollbar.rail.length - 1);
    final letter = AlphabetScrollbar.rail[railIndex];
    // Tick once per crossed letter while tapping/dragging the rail.
    if (letter != _soughtLetter) {
      _soughtLetter = letter;
      context.hapticSelect();
    }
    final row = _targetIndex(letter);
    final offset = widget.topPadding + row * widget.itemExtent;
    widget.controller.jumpTo(
      offset.clamp(0.0, widget.controller.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (d) => _seek(d.localPosition.dy, context.size?.height ?? 0),
      onVerticalDragStart: (d) =>
          _seek(d.localPosition.dy, context.size?.height ?? 0),
      onVerticalDragUpdate: (d) =>
          _seek(d.localPosition.dy, context.size?.height ?? 0),
      child: Container(
        width: 24,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final letter in AlphabetScrollbar.rail)
              Expanded(
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      letterSpacing: 0.3,
                      color: letter == _active
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
