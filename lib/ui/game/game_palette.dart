import 'package:flutter/material.dart';

abstract final class GamePalette {
  static const Color voidBlack = Color(0xFF02070D);
  static const Color backdrop = Color(0xFF07111D);
  static const Color panelBase = Color(0xF0091624);
  static const Color panelRaised = Color(0xF20B1B2B);
  static const Color panelInset = Color(0xAA07111D);
  static const Color stone = Color(0xFF4A6172);
  static const Color stoneDark = Color(0xFF223543);
  static const Color metal = Color(0xFF8FA8BA);
  static const Color metalDim = Color(0xFF607486);
  static const Color cyan = Color(0xFF8EE6FF);
  static const Color cyanDeep = Color(0xFF22C7E8);
  static const Color cyanBright = Color(0xFFBFF4FF);
  static const Color gold = Color(0xFFE7C66A);
  static const Color goldBright = Color(0xFFFFD166);
  static const Color green = Color(0xFF63E6A5);
  static const Color danger = Color(0xFFFF7043);
  static const Color warning = Color(0xFFFFC285);
  static const Color textPrimary = Color(0xFFE8F8FF);
  static const Color textSecondary = Color(0xFFB9D6E4);
  static const Color textMuted = Color(0xFF8AA6B8);
  static const Color textDisabled = Color(0xFF667987);

  static const double radius = 8;
  static const double radiusSmall = 6;
  static const double inset = 6;
  static const double gapTiny = 3;
  static const double gapSmall = 6;
  static const double gap = 8;
  static const double gapLarge = 12;

  static const Duration pressDuration = Duration(milliseconds: 90);
  static const Duration transitionDuration = Duration(milliseconds: 130);
}
