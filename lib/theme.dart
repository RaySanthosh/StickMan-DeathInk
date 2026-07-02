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
