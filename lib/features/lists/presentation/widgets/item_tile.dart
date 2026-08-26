import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/fixed_height_tile.dart';
import '../../../catalog/presentation/widgets/product_match_sheet.dart';
import '../../../item_icons/presentation/widgets/item_icon_avatar.dart';
import '../../../pricing/presentation/widgets/item_price_block.dart';
import '../../../pricing/presentation/widgets/report_price_sheet.dart';
import '../../domain/entities/grocery_item.dart';
import '../providers/list_actions_controller.dart';
import 'unit_picker.dart';

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
  late String? _customUnit;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _qtyController = TextEditingController(text: _formatQty(widget.item.quantity));
    _unit = widget.item.unit;
    _customUnit = widget.item.customUnit;
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
      _customUnit = widget.item.customUnit;
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
      customUnit: _customUnit,
    );
  }

  Future<void> _toggleChecked(bool? value) async {
    await ref.read(listActionsControllerProvider.notifier).updateItem(
          listId: widget.listId,
          itemId: widget.item.id,
          isChecked: value ?? false,
        );
  }

  /// An item with no catalog match has nowhere to attach a price, so the first
  /// report asks which product it is and remembers the answer on the item.
  Future<void> _reportPrice() async {
    final item = widget.item;
    var canonicalItemId = item.canonicalItemId;

    if (canonicalItemId == null) {
      final match = await showProductMatchSheet(context, itemName: item.name);
      if (match == null || !mounted) return;
      canonicalItemId = match.id;
      await ref.read(listActionsControllerProvider.notifier).updateItem(
            listId: widget.listId,
            itemId: item.id,
            canonicalItemId: canonicalItemId,
          );
      if (!mounted) return;
    }

    await showReportPriceSheet(
      context,
      canonicalItemId: canonicalItemId,
      productName: item.name,
      initialUnit: item.unit,
      initialCustomUnit: item.customUnit,
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
    final theme = Theme.of(context);

    // Quantity moves under the name so the row's right edge belongs to the
    // price — the number people actually scan a shopping list for.
    final row = Row(
      children: [
        Checkbox(value: item.isChecked, onChanged: _toggleChecked),
        ItemIconAvatar(itemName: item.name, size: 40),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  decoration:
                      item.isChecked ? TextDecoration.lineThrough : null,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatQty(item.quantity)} ${item.unitLabel}'.trimRight(),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ItemPriceBlock(
          canonicalItemId: item.canonicalItemId,
          onReport: _reportPrice,
        ),
      ],
    );

    // Checked items recede rather than disappear: still readable if you need
    // to double-check what you already picked up.
    return item.isChecked ? Opacity(opacity: 0.55, child: row) : row;
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
        SizedBox(
          width: 96,
          child: UnitPicker(
            dense: true,
            unit: _unit,
            customUnit: _customUnit,
            onChanged: (unit, custom) => setState(() {
              _unit = unit;
              _customUnit = custom;
            }),
          ),
        ),
        IconButton(icon: const Icon(Icons.check), onPressed: _commitEdit),
      ],
    );
  }
}
