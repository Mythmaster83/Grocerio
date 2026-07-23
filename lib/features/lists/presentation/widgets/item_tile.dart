import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/fixed_height_tile.dart';
import '../../../images/presentation/widgets/network_image_with_fallback.dart';
import '../../domain/entities/grocery_item.dart';
import '../providers/list_actions_controller.dart';

/// Single item row: checkbox, name, quantity+unit, and swipe actions.
/// This widget is intentionally "dumb" — it renders a [GroceryItem] and
/// calls back into [ListActionsController] for every mutation. It never
/// talks to Isar, never holds its own copy of "is this checked" that could
/// drift from the source of truth — that drift is exactly what produced
/// the old app's checkbox bugs.
class ItemTile extends ConsumerStatefulWidget {
  final String listId;
  final GroceryItem item;

  const ItemTile({super.key, required this.listId, required this.item});

  @override
  ConsumerState<ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<ItemTile> {
  bool _editing = false;
  late final TextEditingController _nameController;
  late final TextEditingController _qtyController;
  late ItemUnit _unit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _qtyController = TextEditingController(text: _formatQty(widget.item.quantity));
    _unit = widget.item.unit;
  }

  @override
  void didUpdateWidget(covariant ItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep local edit buffers in sync if the item changes underneath us
    // (e.g. another device / voice input updates it) while NOT clobbering
    // a field the user is actively mid-edit on.
    if (!_editing && oldWidget.item != widget.item) {
      _nameController.text = widget.item.name;
      _qtyController.text = _formatQty(widget.item.quantity);
      _unit = widget.item.unit;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  String _formatQty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  Future<void> _commitEdit() async {
    final controller = ref.read(listActionsControllerProvider.notifier);
    final quantity = InputSanitizer.parseQuantity(_qtyController.text);
    setState(() => _editing = false);
    await controller.updateItem(
      listId: widget.listId,
      itemId: widget.item.id,
      name: _nameController.text,
      quantity: quantity ?? widget.item.quantity,
      unit: _unit,
    );
  }

  Future<void> _toggleChecked(bool? value) async {
    await ref.read(listActionsControllerProvider.notifier).updateItem(
          listId: widget.listId,
          itemId: widget.item.id,
          isChecked: value ?? false,
        );
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete item?',
      message: '"${widget.item.name}" will be removed from this list.',
    );
    if (!confirmed) return;
    if (!mounted) return;
    await ref
        .read(listActionsControllerProvider.notifier)
        .deleteItem(listId: widget.listId, itemId: widget.item.id);
  }

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(widget.item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => setState(() => _editing = true),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
            icon: Icons.edit_outlined,
            label: 'Edit',
          ),
          SlidableAction(
            onPressed: (_) => _delete(),
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: FixedHeightTile(
        child: _editing ? _buildEditRow(context) : _buildDisplayRow(context),
      ),
    );
  }

  Widget _buildDisplayRow(BuildContext context) {
    final item = widget.item;
    return Row(
      children: [
        Checkbox(value: item.isChecked, onChanged: _toggleChecked),
        NetworkImageWithFallback(imageUrl: item.imageUrl, size: 40),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.name,
            style: TextStyle(
              decoration: item.isChecked ? TextDecoration.lineThrough : null,
              color: item.isChecked
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_formatQty(item.quantity)} ${item.unit.name}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildEditRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(isDense: true, hintText: 'Item name'),
            autofocus: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<ItemUnit>(
          value: _unit,
          underline: const SizedBox.shrink(),
          items: ItemUnit.values
              .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
              .toList(),
          onChanged: (u) => setState(() => _unit = u ?? _unit),
        ),
        IconButton(icon: const Icon(Icons.check), onPressed: _commitEdit),
      ],
    );
  }
}
