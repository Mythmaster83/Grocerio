import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/tokens.dart';
import '../providers/list_filter_provider.dart';

/// All / Solo / Shared.
///
/// Only rendered once sharing is actually possible (signed in): before that
/// every list is solo, so the chips would offer a choice with one real answer.
class ListFilterChips extends ConsumerWidget {
  const ListFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(listFilterProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          for (final filter in ListFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: selected == filter,
                onSelected: (_) =>
                    ref.read(listFilterProvider.notifier).state = filter,
              ),
            ),
        ],
      ),
    );
  }
}
