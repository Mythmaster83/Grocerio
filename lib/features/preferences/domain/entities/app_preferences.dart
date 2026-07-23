import 'package:equatable/equatable.dart';

enum HomePage { lists, schedule, settings }

class AppPreferences extends Equatable {
  final int themeModeIndex;
  final int accentColorValue;
  final String fontFamily;
  final double textScale; // 0.85 - 1.4, clamped
  final List<HomePage> pageOrder;

  const AppPreferences({
    required this.themeModeIndex,
    required this.accentColorValue,
    required this.fontFamily,
    required this.textScale,
    required this.pageOrder,
  });

  factory AppPreferences.defaults() => const AppPreferences(
        themeModeIndex: 0,
        accentColorValue: 0xFF2F6F4F,
        fontFamily: 'Inter',
        textScale: 1.0,
        pageOrder: [HomePage.lists, HomePage.schedule, HomePage.settings],
      );

  AppPreferences copyWith({
    int? themeModeIndex,
    int? accentColorValue,
    String? fontFamily,
    double? textScale,
    List<HomePage>? pageOrder,
  }) {
    return AppPreferences(
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      accentColorValue: accentColorValue ?? this.accentColorValue,
      fontFamily: fontFamily ?? this.fontFamily,
      textScale: (textScale ?? this.textScale).clamp(0.85, 1.4),
      pageOrder: pageOrder ?? this.pageOrder,
    );
  }

  @override
  List<Object?> get props => [themeModeIndex, accentColorValue, fontFamily, textScale, pageOrder];
}
