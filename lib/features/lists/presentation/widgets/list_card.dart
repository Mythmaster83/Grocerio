import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Needed for the `.label` extension getter on ScheduleFrequency — extension
// members are only visible when the file declaring the extension is imported
// directly; they do NOT travel transitively through grocery_list.dart.
import '../../../scheduling/domain/entities/schedule_frequency.dart';
import '../../domain/entities/grocery_list.dart';

class ListCard extends StatelessWidget {
  final GroceryList list;
  final VoidCallback onTap;

  const ListCard({super.key, required this.list, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = list.items.isEmpty ? 0.0 : list.completedCount / list.items.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      list.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _FrequencyChip(label: list.frequency.label),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat.yMMMd().format(list.scheduledFor),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
        style: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
      ),
    );
  }
}
