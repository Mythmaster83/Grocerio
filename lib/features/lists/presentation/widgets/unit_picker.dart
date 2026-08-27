import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/widgets/centered_dialog.dart';
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
  /// than the "Add item" sheet. Opens a centered dialog instead of a
  /// dropdown — a menu anchored to a 96px field with the keyboard up lands
  /// at the bottom of the screen.
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
    final label = await showCenteredDialog<String>(
      context: context,
      builder: (_) => const _CustomUnitDialog(),
    );
    if (label == null) return;

    final saved = await ref
        .read(preferencesControllerProvider.notifier)
        .rememberCustomUnit(label);
    if (saved != null) onChanged(ItemUnit.custom, saved);
  }

  Future<void> _pickFromDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> labels,
    String currentLabel,
  ) async {
    final picked = await showCenteredDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        alignment: Alignment.center,
        title: const Text('Unit'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final label in labels)
                  ListTile(
                    title: Text(label, overflow: TextOverflow.ellipsis),
                    selected: label == currentLabel,
                    onTap: () => Navigator.of(ctx).pop(label),
                  ),
                ListTile(
                  title: const Text('Add custom unit…'),
                  onTap: () => Navigator.of(ctx).pop(_addCustomValue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;
    if (picked == _addCustomValue) {
      await _promptForCustomUnit(context, ref);
      return;
    }
    final resolved = itemUnitFromLabel(picked);
    onChanged(resolved.unit, resolved.customUnit);
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

    // Both the inline edit row and the add-item sheet open a centered dialog.
    // A DropdownButton menu is laid out against the field, so with the
    // keyboard up it lands at the bottom of the screen.
    return InkWell(
      onTap: () => _pickFromDialog(context, ref, labels, currentLabel),
      child: InputDecorator(
        decoration: dense
            ? const InputDecoration(isDense: true, border: InputBorder.none)
            : const InputDecoration(labelText: 'Unit'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                currentLabel.isEmpty ? 'Unit' : currentLabel,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
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
      alignment: Alignment.center,
      title: const Text('Add custom unit'),
      content: TextField(
        controller: _controller,
        autofocus: false,
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
