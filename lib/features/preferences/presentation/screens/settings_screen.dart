import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/preferences_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: prefsAsync.when(
        data: (prefs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {prefs.themeMode},
              onSelectionChanged: (s) => controller.updatePrefs((p) => p.copyWith(themeMode: s.first)),
            ),
            const SizedBox(height: 24),
            Text('Accent color', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: AppTheme.accentPalette.map((color) {
                final selected = prefs.accentColor.toARGB32() == color.toARGB32();
                return GestureDetector(
                  onTap: () => controller.updatePrefs((p) => p.copyWith(accentColor: color)),
                  child: CircleAvatar(
                    backgroundColor: color,
                    radius: 20,
                    child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text('Text size', style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: prefs.textScale,
              min: 0.85,
              max: 1.4,
              divisions: 11,
              label: '${(prefs.textScale * 100).round()}%',
              onChanged: (v) => controller.updatePrefs((p) => p.copyWith(textScale: v)),
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
                if (f != null) controller.updatePrefs((p) => p.copyWith(fontFamily: f));
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load preferences: $e')),
      ),
    );
  }
}
