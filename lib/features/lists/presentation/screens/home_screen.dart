import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/list_actions_controller.dart';
import '../providers/lists_di.dart';
import '../providers/lists_provider.dart';
import '../widgets/create_list_modal.dart';
import '../widgets/list_card.dart';
import '../widgets/missed_date_indicator.dart';
import 'list_detail_screen.dart';

/// Home shows every list as a card grid/list. This screen owns ZERO
/// business logic — it renders whatever listsStreamProvider emits and
/// delegates every action to a modal or the actions controller.
///
/// Settings live on the shell tab (see AppShell); not pushed from here.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off overdue date reconciliation once per app open.
    ref.watch(reconcileSchedulesProvider);

    final listsAsync = ref.watch(listsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Lists'),
      ),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(listsStreamProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lists.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final list = lists[index];
                return ListCard(
                  list: list,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ListDetailScreen(listId: list.id),
                    ),
                  ),
                  onMissedTap: list.hasMissedDate
                      ? () => showMissedDateDialog(
                            context: context,
                            onAcknowledge: () async {
                              await ref
                                  .read(listActionsControllerProvider.notifier)
                                  .clearLastMissedOn(list.id);
                            },
                          )
                      : null,
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load lists: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateListModal(context),
        icon: const Icon(Icons.add),
        label: const Text('New List'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_basket_outlined,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No lists yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Tap "New List" to create your first grocery or stock list.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
