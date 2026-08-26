import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../voice_input/presentation/widgets/voice_input_button.dart';
import '../../domain/entities/grocery_item.dart';
import '../providers/list_actions_controller.dart';
import '../providers/lists_di.dart';
import 'unit_picker.dart';

Future<void> showAddItemModal(BuildContext context, {required String listId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddItemForm(listId: listId),
  );
}

class _AddItemForm extends ConsumerStatefulWidget {
  final String listId;
  const _AddItemForm({required this.listId});

  @override
  ConsumerState<_AddItemForm> createState() => _AddItemFormState();
}

class _AddItemFormState extends ConsumerState<_AddItemForm> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  ItemUnit _unit = ItemUnit.piece;
  String? _customUnit;
  String? _error;
  List<String> _suggestions = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _loadSuggestions);
  }

  Future<void> _loadSuggestions() async {
    final query = _nameController.text;
    final result =
        await ref.read(listsRepositoryProvider).suggestItemNames(query);
    if (!mounted) return;
    result.when(
      ok: (names) => setState(() => _suggestions = names),
      err: (_) => setState(() => _suggestions = const []),
    );
  }

  Future<void> _submit() async {
    final quantity = InputSanitizer.parseQuantity(_qtyController.text);
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Item name is required.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter a valid quantity.');
      return;
    }
    final ok = await ref.read(listActionsControllerProvider.notifier).addItem(
          listId: widget.listId,
          name: _nameController.text,
          quantity: quantity,
          unit: _unit,
          customUnit: _customUnit,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = 'Could not add the item. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(listActionsControllerProvider);
    // Use the sheet's MediaQuery — not the caller's — so padding tracks the
    // keyboard open/close cycle and does not leave a stuck bottom gap.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add item', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(hintText: 'e.g. Milk'),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 8),
                VoiceInputButton(
                  onResult: (text) {
                    _nameController.text = text;
                    setState(() {});
                  },
                ),
              ],
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: Material(
                  elevation: 1,
                  borderRadius: BorderRadius.circular(12),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final name = _suggestions[index];
                      return ListTile(
                        dense: true,
                        title: Text(name),
                        onTap: () {
                          _nameController.text = name;
                          _nameController.selection =
                              TextSelection.fromPosition(
                            TextPosition(offset: name.length),
                          );
                          setState(() => _suggestions = const []);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: UnitPicker(
                    unit: _unit,
                    customUnit: _customUnit,
                    onChanged: (unit, custom) => setState(() {
                      _unit = unit;
                      _customUnit = custom;
                    }),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: actionState.isLoading ? null : _submit,
              child: actionState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Item'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
