import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../pricing/presentation/widgets/post_shopping_price_sheet.dart';
import '../../../sharing/presentation/widgets/share_list_sheet.dart';
import '../../domain/entities/grocery_item.dart';
import '../../domain/entities/grocery_list.dart';
import '../../domain/list_text_export.dart';
import '../providers/list_actions_controller.dart';
import '../providers/lists_provider.dart';
import '../widgets/add_item_modal.dart';
import '../widgets/edit_list_modal.dart';
import '../widgets/item_tile.dart';
import '../widgets/missed_date_indicator.dart';

enum _ListDetailAction { copyAsText, shareWithPeople, edit, delete }

class ListDetailScreen extends ConsumerWidget {
  final String listId;
  const ListDetailScreen({super.key, required this.listId});

  /// Copies the list as plain text so it can be pasted into any messaging app.
  /// Still worth keeping alongside real sharing: it needs no account on either
  /// end, which is the difference between "send my wife the list" working now
  /// and working after she installs the app.
  Future<void> _shareAsText(BuildContext context, GroceryList list) async {
    await Clipboard.setData(ClipboardData(text: formatListForSharing(list)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('List copied — paste it anywhere')),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete list?',
      message: 'This list and all its items will be permanently removed.',
    );
    if (!confirmed) return;
    await ref.read(listActionsControllerProvider.notifier).deleteList(listId);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _completeShopping(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Complete shopping?',
      message:
          'Unchecks all items and returns home. Recurring lists move to the '
          'next planned date; one-time lists are deleted.',
      confirmLabel: 'Complete',
      isDestructive: false,
    );
    if (!confirmed || !context.mounted) return;

    // Snapshot the checked items first: completing the trip unchecks
    // everything, so afterwards there is no record of what was actually bought.
    final purchased = ref
            .read(listDetailStreamProvider(listId))
            .valueOrNull
            ?.items
            .where((item) => item.isChecked)
            .toList(growable: false) ??
        const <GroceryItem>[];

    final ok = await ref
        .read(listActionsControllerProvider.notifier)
        .completeShopping(listId);
    if (!ok || !context.mounted) return;

    await showPostShoppingPriceSheet(context, items: purchased);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(listDetailStreamProvider(listId));

    // Listen for write failures (checkbox, edit, delete) and tell the user.
    // This runs during build — NOT inside a button callback.
    ref.listen(listActionsControllerProvider, (previous, next) {
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
      appBar: AppBar(
        title: listAsync.maybeWhen(
          data: (list) => Text(list?.name ?? 'List'),
          orElse: () => const Text('List'),
        ),
        actions: [
          listAsync.maybeWhen(
            data: (list) {
              if (list == null || !list.hasMissedDate) {
                return const SizedBox.shrink();
              }
              return MissedDateIndicator(
                onTap: () => showMissedDateDialog(
                  context: context,
                  onAcknowledge: () async {
                    await ref
                        .read(listActionsControllerProvider.notifier)
                        .clearLastMissedOn(listId);
                  },
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          PopupMenuButton<_ListDetailAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'List options',
            onSelected: (action) async {
              final list = listAsync.valueOrNull;
              switch (action) {
                case _ListDetailAction.copyAsText:
                  if (list != null) await _shareAsText(context, list);
                case _ListDetailAction.shareWithPeople:
                  if (list != null) {
                    await showShareListSheet(
                      context,
                      listId: list.id,
                      listName: list.name,
                    );
                  }
                case _ListDetailAction.edit:
                  if (list != null) await showEditListModal(context, list: list);
                case _ListDetailAction.delete:
                  await _confirmDelete(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _ListDetailAction.shareWithPeople,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.group_add_outlined),
                  title: Text('Share with people'),
                ),
              ),
              PopupMenuItem(
                value: _ListDetailAction.copyAsText,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.ios_share_outlined),
                  title: Text('Copy as text'),
                ),
              ),
              PopupMenuItem(
                value: _ListDetailAction.edit,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_calendar_outlined),
                  title: Text('Edit name, date & repeat'),
                ),
              ),
              PopupMenuItem(
                value: _ListDetailAction.delete,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete list'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: listAsync.when(
        data: (list) {
          if (list == null) {
            return const Center(child: Text('This list no longer exists.'));
          }
          if (list.items.isEmpty) {
            return const Center(
                child: Text('No items yet — add your first one below.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                ItemTile(listId: listId, item: list.items[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Could not load this list: $error')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _completeShopping(context, ref),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete Shopping'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showAddItemModal(context, listId: listId),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
