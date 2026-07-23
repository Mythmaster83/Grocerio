import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../voice_input/presentation/widgets/voice_input_button.dart';
import '../../domain/entities/grocery_item.dart';
import '../providers/list_actions_controller.dart';

Future<void> showAddItemModal(BuildContext context, {required String listId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AddItemForm(listId: listId),
    ),
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
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
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
    return Padding(
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
                onResult: (text) => setState(() => _nameController.text = text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ItemUnit>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: ItemUnit.values
                      .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                      .toList(),
                  onChanged: (u) => setState(() => _unit = u ?? _unit),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: actionState.isLoading ? null : _submit,
            child: actionState.isLoading
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add Item'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
