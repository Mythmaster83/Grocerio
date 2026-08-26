import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/tokens.dart';
// Needed for the `.label` extension getter on ScheduleFrequency — extension
// members are only visible when the file declaring the extension is imported
// directly; they do NOT travel transitively through grocery_list.dart.
import '../../../scheduling/domain/entities/schedule_frequency.dart';
import '../../domain/entities/grocery_list.dart';
import 'missed_date_indicator.dart';

enum ListCardAction { edit, delete }

class ListCard extends StatelessWidget {
  final GroceryList list;
  final VoidCallback onTap;
  final VoidCallback? onMissedTap;

  /// Opens the rename / reschedule / repeat sheet. Wired to the 3-dot menu so
  /// the most common edits never require opening the list first.
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ListCard({
    super.key,
    required this.list,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onMissedTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        list.items.isEmpty ? 0.0 : list.completedCount / list.items.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 8, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (list.hasMissedDate && onMissedTap != null) ...[
                    MissedDateIndicator(onTap: onMissedTap!),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      list.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _FrequencyChip(label: list.frequency.label),
                  PopupMenuButton<ListCardAction>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'List options',
                    onSelected: (action) => switch (action) {
                      ListCardAction.edit => onEdit(),
                      ListCardAction.delete => onDelete(),
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: ListCardAction.edit,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_calendar_outlined),
                          title: Text('Edit name, date & repeat'),
                        ),
                      ),
                      PopupMenuItem(
                        value: ListCardAction.delete,
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
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.yMMMd().format(list.scheduledFor),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.surfaceElevated,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${list.completedCount}/${list.items.length} items',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  const _FrequencyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
