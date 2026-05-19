import 'package:flutter/material.dart';

import 'game_palette.dart';

abstract final class GameTextStyles {
  static const List<Shadow> textShadow = [
    Shadow(color: GamePalette.voidBlack, blurRadius: 5, offset: Offset(0, 1.5)),
  ];

  static const TextStyle title = TextStyle(
    color: GamePalette.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    height: 1.05,
    shadows: textShadow,
  );

  static const TextStyle sectionTitle = TextStyle(
    color: GamePalette.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w900,
    height: 1.08,
    shadows: textShadow,
  );

  static const TextStyle body = TextStyle(
    color: GamePalette.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle caption = TextStyle(
    color: GamePalette.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  static const TextStyle chip = TextStyle(
    color: GamePalette.cyan,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    height: 1,
    shadows: textShadow,
  );

  static const TextStyle button = TextStyle(
    color: GamePalette.textPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    height: 1,
    shadows: textShadow,
  );

  static const TextStyle buttonSmall = TextStyle(
    color: GamePalette.textPrimary,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    height: 1,
    shadows: textShadow,
  );

  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }
}
