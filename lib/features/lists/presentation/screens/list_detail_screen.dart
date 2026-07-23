import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../providers/list_actions_controller.dart';
import '../providers/lists_provider.dart';
import '../widgets/add_item_modal.dart';
import '../widgets/item_tile.dart';

class ListDetailScreen extends ConsumerWidget {
  final String listId;
  const ListDetailScreen({super.key, required this.listId});

  Future<void> _completeShopping(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Complete shopping?',
      message: 'This marks the trip as done. You can still edit items afterward.',
      confirmLabel: 'Complete',
      isDestructive: false,
    );
    if (confirmed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shopping trip completed 🎉')),
      );
    }
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
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete list?',
                message: 'This list and all its items will be permanently removed.',
              );
              if (confirmed) {
                await ref.read(listActionsControllerProvider.notifier).deleteList(listId);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: listAsync.when(
        data: (list) {
          if (list == null) {
            return const Center(child: Text('This list no longer exists.'));
          }
          if (list.items.isEmpty) {
            return const Center(child: Text('No items yet — add your first one below.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => ItemTile(listId: listId, item: list.items[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load this list: $error')),
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
