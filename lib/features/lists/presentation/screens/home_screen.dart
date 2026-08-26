import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../account/presentation/providers/account_di.dart';
import '../../../../core/theme/tokens.dart';
import '../../../navigation/presentation/app_drawer.dart';
import '../../../sharing/presentation/providers/sharing_di.dart';
import '../../../sync/presentation/providers/sync_di.dart';
import '../../domain/entities/grocery_list.dart';
import '../../domain/list_sections.dart';
import '../providers/list_actions_controller.dart';
import '../providers/list_filter_provider.dart';
import '../providers/lists_di.dart';
import '../providers/lists_provider.dart';
import '../widgets/create_list_modal.dart';
import '../widgets/edit_list_modal.dart';
import '../widgets/list_card.dart';
import '../widgets/list_filter_chips.dart';
import '../widgets/missed_date_indicator.dart';
import 'list_detail_screen.dart';

/// The app's only page: AppBar → next scheduled date → the lists themselves.
/// Everything else (settings, stores, price lookup) is reached from the drawer
/// behind the AppBar's hamburger, so the list stays the whole screen.
///
/// This screen owns ZERO business logic — it renders whatever
/// listsStreamProvider emits and delegates every action to a modal or the
/// actions controller.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    GroceryList list,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete list?',
      message: '"${list.name}" and all its items will be permanently removed.',
    );
    if (!confirmed) return;
    await ref.read(listActionsControllerProvider.notifier).deleteList(list.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off overdue date reconciliation once per app open.
    ref.watch(reconcileSchedulesProvider);
    // Attaches the debounced "sync after local writes" listener for as long as
    // home is mounted, which is the app's whole lifetime in practice.
    ref.watch(syncOnWriteProvider);

    final listsAsync = ref.watch(listsStreamProvider);
    final filter = ref.watch(listFilterProvider);
    final sharedIds = ref.watch(sharedListIdsProvider).valueOrNull ?? const <String>{};
    // Sharing is only a real distinction once there's an account behind it.
    final canShare = ref.watch(currentUserProvider).valueOrNull != null;

    // Edit/delete now happen from this screen, so failures must surface here.
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
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Your Lists')),
      body: listsAsync.when(
        data: (lists) {
          if (lists.isEmpty) {
            return const _EmptyState();
          }
          final visible = _applyFilter(lists, filter, sharedIds);
          // Lists arrive sorted by scheduledFor, so the first one is what's
          // due next (or the oldest thing still overdue). The banner tracks all
          // lists, not the filtered subset: the next trip doesn't change
          // because of which chip is selected.
          return Column(
            children: [
              _NextScheduledHeader(date: lists.first.scheduledFor),
              if (canShare) const ListFilterChips(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(listsStreamProvider);
                    ref.invalidate(sharedListIdsProvider);
                    await ref.read(syncStatusProvider.notifier).syncNow();
                  },
                  child: visible.isEmpty
                      ? _FilteredEmptyState(filter: filter)
                      : _SectionedLists(
                          sections: groupIntoSections(visible),
                          onOpen: (list) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ListDetailScreen(listId: list.id),
                            ),
                          ),
                          onEdit: (list) =>
                              showEditListModal(context, list: list),
                          onDelete: (list) => _confirmDelete(context, ref, list),
                          onMissedTap: (list) => showMissedDateDialog(
                            context: context,
                            onAcknowledge: () async {
                              await ref
                                  .read(listActionsControllerProvider.notifier)
                                  .clearLastMissedOn(list.id);
                            },
                          ),
                        ),
                ),
              ),
            ],
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

/// Shared means "someone else is on it", whether this user owns it or was
/// invited to it. [sharedIds] is empty when signed out, so everything reads as
/// solo and the chips are hidden anyway.
List<GroceryList> _applyFilter(
  List<GroceryList> lists,
  ListFilter filter,
  Set<String> sharedIds,
) {
  return switch (filter) {
    ListFilter.all => lists,
    ListFilter.solo =>
      lists.where((l) => !sharedIds.contains(l.id)).toList(growable: false),
    ListFilter.shared =>
      lists.where((l) => sharedIds.contains(l.id)).toList(growable: false),
  };
}

/// Lists under "Overdue" / "This week" / "Later" headers.
///
/// One flat [ListView] over pre-computed sections rather than nested scrollables
/// so the whole page scrolls as a single surface and lazy building still works.
class _SectionedLists extends StatelessWidget {
  final List<ListSectionGroup> sections;
  final ValueChanged<GroceryList> onOpen;
  final ValueChanged<GroceryList> onEdit;
  final ValueChanged<GroceryList> onDelete;
  final ValueChanged<GroceryList> onMissedTap;

  const _SectionedLists({
    required this.sections,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onMissedTap,
  });

  @override
  Widget build(BuildContext context) {
    // Flattened once per build: rows are either a header or a card.
    final rows = <Object>[];
    for (final group in sections) {
      rows.add(group.section);
      rows.addAll(group.lists);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is ListSection) {
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: row == ListSection.overdue
                        ? Theme.of(context).colorScheme.error
                        : AppColors.textMuted,
                  ),
            ),
          );
        }

        final list = row as GroceryList;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ListCard(
            list: list,
            onTap: () => onOpen(list),
            onEdit: () => onEdit(list),
            onDelete: () => onDelete(list),
            onMissedTap: list.hasMissedDate ? () => onMissedTap(list) : null,
          ),
        );
      },
    );
  }
}

/// Shown when a filter hides everything — distinct from having no lists at all,
/// which is a different message and a different fix.
class _FilteredEmptyState extends StatelessWidget {
  final ListFilter filter;
  const _FilteredEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = filter == ListFilter.shared
        ? 'No shared lists yet. Open a list and use "Share with people".'
        : 'Every list is shared right now.';

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// Banner above the lists showing when the next shopping trip is due.
class _NextScheduledHeader extends StatelessWidget {
  final DateTime date;
  const _NextScheduledHeader({required this.date});

  /// Compared as UTC midnights so a daylight-saving boundary can't turn
  /// "tomorrow" into a 23-hour difference and report 0 days.
  static int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final target = DateTime.utc(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _daysUntil(date);
    final isOverdue = days < 0;

    final label = switch (days) {
      < 0 => 'Overdue',
      0 => 'Today',
      1 => 'Tomorrow',
      _ => 'In $days days',
    };

    final background = isOverdue
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final foreground = isOverdue
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(isOverdue ? Icons.event_busy_outlined : Icons.event_outlined,
              color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next scheduled list',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMEd().format(date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: foreground),
          ),
        ],
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
