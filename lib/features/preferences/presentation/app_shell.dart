import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../lists/presentation/screens/home_screen.dart';
import '../domain/entities/app_preferences.dart';
import 'providers/preferences_controller.dart';
import 'screens/settings_screen.dart';

/// Root shell: bottom nav destinations follow [AppPreferences.pageOrder].
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  HomePage _current = HomePage.lists;

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesControllerProvider);
    final pageOrder =
        prefsAsync.valueOrNull?.pageOrder ?? AppPreferences.defaults().pageOrder;

    // Keep the same logical page selected when order changes.
    var selectedIndex = pageOrder.indexOf(_current);
    if (selectedIndex < 0) {
      selectedIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _current = pageOrder.first);
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          for (final page in pageOrder) _destinationBody(page),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _current = pageOrder[i]);
        },
        destinations: [
          for (final page in pageOrder)
            NavigationDestination(
              icon: Icon(_iconFor(page)),
              selectedIcon: Icon(_selectedIconFor(page)),
              label: _labelFor(page),
            ),
        ],
      ),
    );
  }

  Widget _destinationBody(HomePage page) {
    return switch (page) {
      HomePage.lists => const HomeScreen(),
      HomePage.settings => const SettingsScreen(),
    };
  }

  static String _labelFor(HomePage page) => switch (page) {
        HomePage.lists => 'Lists',
        HomePage.settings => 'Settings',
      };

  static IconData _iconFor(HomePage page) => switch (page) {
        HomePage.lists => Icons.list_alt_outlined,
        HomePage.settings => Icons.settings_outlined,
      };

  static IconData _selectedIconFor(HomePage page) => switch (page) {
        HomePage.lists => Icons.list_alt,
        HomePage.settings => Icons.settings,
      };
}
