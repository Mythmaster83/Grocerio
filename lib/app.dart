import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/lists/presentation/screens/home_screen.dart';
import 'features/preferences/presentation/providers/preferences_controller.dart';

class GrocerApp extends ConsumerWidget {
  const GrocerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesControllerProvider);

    // Preferences load once at startup from a local Isar write, typically
    // sub-frame — a brief MaterialApp with default theme avoids a jarring
    // blank screen while avoiding a bespoke splash for what is effectively
    // an instant local read.
    final prefs = prefsAsync.valueOrNull;

    final textScale = prefs?.textScale ?? 1.0;

    return MaterialApp(
      title: 'Grocer',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.values[prefs?.themeModeIndex ?? 0],
      theme: AppTheme.build(
        brightness: Brightness.light,
        accent: Color(prefs?.accentColorValue ?? 0xFF2F6F4F),
        fontFamily: prefs?.fontFamily ?? 'Inter',
      ),
      darkTheme: AppTheme.build(
        brightness: Brightness.dark,
        accent: Color(prefs?.accentColorValue ?? 0xFF2F6F4F),
        fontFamily: prefs?.fontFamily ?? 'Inter',
      ),
      // User text-size preference is applied here — the one place Flutter
      // expects accessibility scaling to live — instead of baking a scale
      // factor into individual TextStyles (which crashes when fontSize is
      // null, as Google Fonts sometimes leaves it).
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}
