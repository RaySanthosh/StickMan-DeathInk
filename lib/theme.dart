import 'package:flutter/material.dart';

/// Ink-on-paper notebook palette used across UI and in-game rendering.
class InkPalette {
  static const paper = Color(0xFFFBF7EC);
  static const paperShade = Color(0xFFF2EBD9);
  static const ruledLine = Color(0xFFB9D3E6);
  static const marginLine = Color(0xFFE0A29A);
  static const ink = Color(0xFF23252E);
  static const inkFaded = Color(0xFF6C6F7B);
  static const redInk = Color(0xFFB63A2E);
  static const graphite = Color(0xFF8B8E97);
  static const gold = Color(0xFFC9A227);
}

/// Shared, immutable [Paint] objects for in-game rendering. Reused every frame
/// instead of being re-allocated in each component's `render()` — this removes
/// the per-frame garbage that caused GC hitches. Never mutate these; if a draw
/// needs a one-off variation, build a local Paint for it.
class GamePaints {
  GamePaints._();

  static Paint _stroke(Color c, double w, [StrokeJoin? join, StrokeCap? cap]) {
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    if (join != null) p.strokeJoin = join;
    if (cap != null) p.strokeCap = cap;
    return p;
  }

  // fills
  static final Paint paperFill = Paint()..color = InkPalette.paperShade;
  static final Paint redFill = Paint()..color = InkPalette.redInk;
  static final Paint graphiteFill = Paint()..color = InkPalette.graphite;
  static final Paint inkFill = Paint()..color = InkPalette.ink;

  // ink strokes at the widths the game actually uses
  static final Paint ink1 = _stroke(InkPalette.ink, 1);
  static final Paint ink2 = _stroke(InkPalette.ink, 2);
  static final Paint ink24 =
      _stroke(InkPalette.ink, 2.4, StrokeJoin.round);
  static final Paint ink26 =
      _stroke(InkPalette.ink, 2.6, StrokeJoin.round);
  static final Paint ink3 =
      _stroke(InkPalette.ink, 3, StrokeJoin.round, StrokeCap.round);
  static final Paint inkFar3 = _stroke(
      InkPalette.ink.withValues(alpha: 0.55), 3,
      StrokeJoin.round, StrokeCap.round);

  // hatching / faint marks
  static final Paint hatch =
      _stroke(InkPalette.graphite.withValues(alpha: 0.35), 1.2);
  static final Paint hatch05 =
      _stroke(InkPalette.graphite.withValues(alpha: 0.5), 1);
  static final Paint inkFadedThin =
      _stroke(InkPalette.inkFaded, 1.6);

  // trap-specific paints, hoisted out of per-frame render() calls
  static final Paint spikeRedStroke =
      _stroke(InkPalette.redInk, 2.4, StrokeJoin.round);
  static final Paint popupSpecksFill =
      Paint()..color = InkPalette.redInk.withValues(alpha: 0.45);
  static final Paint dartStroke =
      _stroke(InkPalette.ink, 2.4, null, StrokeCap.round);
  static final Paint fakeFloorGhostStroke =
      _stroke(InkPalette.inkFaded.withValues(alpha: 0.2), 1.4);
  static final Paint fakeFloorCrackStroke =
      _stroke(InkPalette.ink.withValues(alpha: 0.7), 1.2);
  static final Paint vanishingGhostStroke =
      _stroke(InkPalette.inkFaded.withValues(alpha: 0.25), 1.6);
  static final Paint laserGlow =
      _stroke(InkPalette.redInk.withValues(alpha: 0.25), 9);
  static final Paint laserCore = _stroke(InkPalette.redInk, 3);
  static final Paint laserWarn =
      _stroke(InkPalette.redInk.withValues(alpha: 0.35), 1.6);
}

ThemeData buildNotebookTheme() {
  const ink = InkPalette.ink;
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: InkPalette.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: InkPalette.redInk,
      surface: InkPalette.paper,
    ),
    fontFamily: 'PatrickHand',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: InkPalette.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: ink, width: 2),
      ),
    ),
  );
}

/// Handwritten display style (titles).
TextStyle caveat(double size,
    {Color color = InkPalette.ink, FontWeight weight = FontWeight.w700}) {
  return TextStyle(
      fontFamily: 'Caveat', fontSize: size, color: color, fontWeight: weight);
}

/// Handwritten body style.
TextStyle hand(double size,
    {Color color = InkPalette.ink, FontWeight weight = FontWeight.w400}) {
  return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: size,
      color: color,
      fontWeight: weight);
}
