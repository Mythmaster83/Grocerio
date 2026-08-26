import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/lists/presentation/screens/home_screen.dart';
import 'features/preferences/presentation/providers/preferences_controller.dart';
import 'features/stores/presentation/providers/stores_di.dart';
import 'features/sync/presentation/providers/sync_di.dart';

class GrocerApp extends ConsumerStatefulWidget {
  const GrocerApp({super.key});

  @override
  ConsumerState<GrocerApp> createState() => _GrocerAppState();
}

class _GrocerAppState extends ConsumerState<GrocerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final sync = ref.read(syncStatusProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        sync.startHeartbeat();
        sync.syncNow();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        sync.stopHeartbeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesControllerProvider);
    // Prefetch the store directory so Your stores is not empty on first open.
    ref.watch(storesStreamProvider);

    // Preferences load once at startup from a local Isar write, typically
    // sub-frame — a brief MaterialApp with default theme avoids a jarring
    // blank screen while avoiding a bespoke splash for what is effectively
    // an instant local read.
    final prefs = prefsAsync.valueOrNull;

    final textScale = prefs?.textScale ?? 1.0;
    // One dark theme, regardless of the platform setting — see AppTheme.
    final theme = AppTheme.build(fontFamily: prefs?.fontFamily ?? 'Inter');

    return MaterialApp(
      title: 'Grocerio',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: theme,
      darkTheme: theme,
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
      // Single-page app: lists are the whole UI, settings is pushed from the
      // AppBar. No bottom navigation to keep one destination unambiguous.
      home: const HomeScreen(),
    );
  }
}
