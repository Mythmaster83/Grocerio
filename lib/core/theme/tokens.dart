import 'package:flutter/material.dart';

/// Design tokens for the single dark theme.
///
/// Every surface color, border, radius and spacing step in the app should come
/// from this file. The reason is not tidiness: the previous "flat black"
/// problem came from widgets each picking their own near-black, so nothing read
/// as layered. One palette with three deliberate elevation steps fixes that
/// class of bug permanently.
class AppColors {
  AppColors._();

  /// Scaffold background — the darkest layer.
  static const bg = Color(0xFF0B0D0C);

  /// Cards and sheets sitting on [bg].
  static const surface = Color(0xFF141815);

  /// Nested surfaces: a price cell inside a card, an input inside a sheet.
  static const surfaceElevated = Color(0xFF1C211D);

  /// 6% white. Deliberately barely visible — it separates surfaces without
  /// drawing a line the eye reads as a divider.
  static const borderHairline = Color(0x0FFFFFFF);

  static const accent = Color(0xFF7FE0A8);

  /// Text/icons on top of [accent]. The accent is light, so this is dark.
  static const onAccent = Color(0xFF07130C);

  static const textPrimary = Color(0xFFF1F4F2);
  static const textMuted = Color(0xFF8B948D);

  static const danger = Color(0xFFE5646A);

  /// Fill behind the cheapest price cell — the accent at low opacity, so it
  /// tints rather than shouts.
  static const accentTint = Color(0x1F7FE0A8);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 32;
}

class AppRadii {
  AppRadii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  /// Fully rounded — chips and pills.
  static const double pill = 999;
}

class AppBorders {
  AppBorders._();

  static const double hairlineWidth = 0.5;

  static const BorderSide hairlineSide = BorderSide(
    color: AppColors.borderHairline,
    width: hairlineWidth,
  );

  static Border get hairline => const Border.fromBorderSide(hairlineSide);
}
