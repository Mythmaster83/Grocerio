import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/result.dart';
import '../../../stores/presentation/providers/stores_di.dart';
import '../../../stores/presentation/screens/tracked_stores_screen.dart';
import '../providers/preferences_controller.dart';

/// Pushed from the drawer — the app has a single page, so settings is a route,
/// not a tab.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);
    final trackedCount = ref.watch(trackedStoresProvider).length;

    ref.listen(preferencesControllerProvider, (prev, next) {
      if (next.hasError) {
        final message = next.error is AppFailure
            ? (next.error as AppFailure).message
            : 'Something went wrong.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: prefsAsync.when(
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Text size', style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: prefs.textScale,
              min: 0.85,
              max: 1.4,
              divisions: 11,
              label: '${(prefs.textScale * 100).round()}%',
              onChanged: (v) =>
                  controller.updatePrefs((p) => p.copyWith(textScale: v)),
            ),
            const SizedBox(height: 12),
            Text('Font', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: prefs.fontFamily,
              items: const ['Inter', 'Nunito', 'Merriweather', 'Roboto Mono']
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (f) {
                if (f != null) {
                  controller.updatePrefs((p) => p.copyWith(fontFamily: f));
                }
              },
            ),
            const SizedBox(height: 24),
            Text('Shopping', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Your stores'),
                subtitle: Text(
                  trackedCount == 0
                      ? 'Pick nearby locations to compare prices'
                      : '$trackedCount tracked · community prices follow these',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TrackedStoresScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load preferences: $e')),
      ),
    );
  }
}
