import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design language: warm neutral surfaces, a single confident accent, and
/// generous whitespace — deliberately avoiding the default Material
/// purple/indigo + drop-shadow-everywhere look that reads as an unstyled
/// scaffold. Accent color and font family are user-configurable
/// (see preferences feature) — [AppTheme.build] takes them as parameters
/// rather than hardcoding, because "change theme mode and color" is a
/// named MVP requirement, not a stretch goal.
class AppTheme {
  AppTheme._();

  static const Color _neutralLight = Color(0xFFFAF9F6);
  static const Color _neutralDark = Color(0xFF14161A);

  static ThemeData build({
    required Brightness brightness,
    required Color accent,
    required String fontFamily,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: isDark ? _neutralDark : _neutralLight,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.comfortable,
    );

    final textTheme = _textTheme(fontFamily, base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: colorScheme.surfaceContainerHigh,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),
    );
  }

  static TextTheme _textTheme(String fontFamily, TextTheme base) {
    try {
      return GoogleFonts.getTextTheme(fontFamily, base);
    } catch (_) {
      // Unknown/unsupported font name from preferences storage — fail soft
      // to the platform default rather than crashing the whole app on a
      // stale or corrupted preference value.
      return base;
    }
  }

  /// Curated accent palette shown in preferences — deliberately not a full
  /// color wheel. Constrained choice sets are what keep a "user-selectable
  /// theme color" feature from producing accidentally illegible combos.
  static const List<Color> accentPalette = [
    Color(0xFF2F6F4F), // forest
    Color(0xFF3A5A9B), // denim
    Color(0xFFB0552B), // terracotta
    Color(0xFF6B4E8E), // plum
    Color(0xFF2D6E75), // teal
    Color(0xFF8C6D1F), // ochre
  ];
}
