import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum HomePage { lists, schedule, settings }

class AppPreferences extends Equatable {
  final ThemeMode themeMode;
  final Color accentColor;
  final String fontFamily;
  final double textScale; // 0.85 - 1.4, clamped
  final List<HomePage> pageOrder;

  const AppPreferences({
    required this.themeMode,
    required this.accentColor,
    required this.fontFamily,
    required this.textScale,
    required this.pageOrder,
  });

  factory AppPreferences.defaults() => const AppPreferences(
        themeMode: ThemeMode.system,
        accentColor: Color(0xFF2F6F4F),
        fontFamily: 'Inter',
        textScale: 1.0,
        pageOrder: [HomePage.lists, HomePage.schedule, HomePage.settings],
      );

  AppPreferences copyWith({
    ThemeMode? themeMode,
    Color? accentColor,
    String? fontFamily,
    double? textScale,
    List<HomePage>? pageOrder,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      fontFamily: fontFamily ?? this.fontFamily,
      textScale: (textScale ?? this.textScale).clamp(0.85, 1.4),
      pageOrder: pageOrder ?? this.pageOrder,
    );
  }

  @override
  List<Object?> get props => [themeMode, accentColor, fontFamily, textScale, pageOrder];
}
