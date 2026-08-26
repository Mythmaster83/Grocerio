import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../preferences/presentation/providers/preferences_controller.dart';
import '../../domain/entities/grocery_item.dart';

typedef UnitChanged = void Function(ItemUnit unit, String? customUnit);

/// Dropdown of built-in units + every custom unit the user has saved, plus an
/// "Add custom unit…" entry that persists what they type (see
/// [PreferencesController.rememberCustomUnit]) so it's one tap next time.
///
/// The dropdown's value is the *label*, not the enum: that's the only
/// representation that can express both built-in and free-text units, and
/// [itemUnitFromLabel] maps it back to something persistable.
class UnitPicker extends ConsumerWidget {
  final ItemUnit unit;
  final String? customUnit;
  final UnitChanged onChanged;

  /// Compact form for the inline item-edit row, which has far less width
  /// than the "Add item" sheet.
  final bool dense;

  const UnitPicker({
    super.key,
    required this.unit,
    required this.customUnit,
    required this.onChanged,
    this.dense = false,
  });

  static const _addCustomValue = '\u0000add-custom';

  Future<void> _promptForCustomUnit(BuildContext context, WidgetRef ref) async {
    final label = await showDialog<String>(
      context: context,
      builder: (_) => const _CustomUnitDialog(),
    );
    if (label == null) return;

    final saved = await ref
        .read(preferencesControllerProvider.notifier)
        .rememberCustomUnit(label);
    if (saved != null) onChanged(ItemUnit.custom, saved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedUnits =
        ref.watch(preferencesControllerProvider).valueOrNull?.customUnits ??
            const <String>[];

    final currentLabel = itemUnitLabel(unit, customUnit);
    // A custom unit that was later removed from the directory must still be
    // selectable, otherwise the dropdown would have no matching value.
    final labels = <String>[
      for (final u in builtInUnits) u.name,
      ...savedUnits,
      if (unit == ItemUnit.custom &&
          currentLabel.isNotEmpty &&
          !savedUnits.contains(currentLabel))
        currentLabel,
    ];

    // A plain DropdownButton (not DropdownButtonFormField) so the displayed
    // value comes only from the parent's state. A FormField would latch onto
    // the "Add custom unit…" sentinel and keep showing it if the user
    // cancelled the dialog.
    return InputDecorator(
      decoration: dense
          ? const InputDecoration(isDense: true, border: InputBorder.none)
          : const InputDecoration(labelText: 'Unit'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: labels.contains(currentLabel) ? currentLabel : null,
          isExpanded: true,
          items: [
            for (final label in labels)
              DropdownMenuItem(
                value: label,
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
            const DropdownMenuItem(
              value: _addCustomValue,
              child: Text('Add custom unit…'),
            ),
          ],
          onChanged: (label) {
            if (label == null) return;
            if (label == _addCustomValue) {
              _promptForCustomUnit(context, ref);
              return;
            }
            final resolved = itemUnitFromLabel(label);
            onChanged(resolved.unit, resolved.customUnit);
          },
        ),
      ),
    );
  }
}

class _CustomUnitDialog extends StatefulWidget {
  const _CustomUnitDialog();

  @override
  State<_CustomUnitDialog> createState() => _CustomUnitDialogState();
}

class _CustomUnitDialogState extends State<_CustomUnitDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add custom unit'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: InputSanitizer.maxUnitLabelLength,
        textCapitalization: TextCapitalization.none,
        decoration: const InputDecoration(
          hintText: 'e.g. bunch, bottle, sachet',
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
