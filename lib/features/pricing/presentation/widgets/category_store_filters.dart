import 'package:flutter/material.dart';
import '../../../../core/theme/tokens.dart';
import '../../../catalog/domain/entities/item_category.dart';
import '../../../stores/domain/entities/store.dart';

/// Category (single-select) and store (multi-select) chip rows.
///
/// Store chips show an explicit On/Off affordance so selected vs unselected is
/// obvious in the dark theme — a tinted chip alone was too easy to miss.
class CategoryStoreFilters extends StatelessWidget {
  final ItemCategory? selectedCategory;
  final ValueChanged<ItemCategory?> onCategoryChanged;

  final List<Store> stores;
  final Set<int> selectedStoreIds;
  final ValueChanged<Set<int>> onStoresChanged;

  const CategoryStoreFilters({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.stores,
    required this.selectedStoreIds,
    required this.onStoresChanged,
  });

  void _toggleStore(int storeId) {
    final next = Set<int>.from(selectedStoreIds);
    if (!next.remove(storeId)) next.add(storeId);
    // Empty means "no stores", which renders an empty grid and reads as broken;
    // treat deselecting the last one as selecting all instead.
    onStoresChanged(next.isEmpty ? stores.map((s) => s.id).toSet() : next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: const Text('All'),
                  selected: selectedCategory == null,
                  onSelected: (_) => onCategoryChanged(null),
                ),
              ),
              for (final category in ItemCategory.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(category.label),
                    selected: selectedCategory == category,
                    onSelected: (_) => onCategoryChanged(category),
                  ),
                ),
            ],
          ),
        ),
        if (stores.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Stores in this comparison',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final store in stores)
                _StoreToggleChip(
                  store: store,
                  selected: selectedStoreIds.contains(store.id),
                  onTap: () => _toggleStore(store.id),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StoreToggleChip extends StatelessWidget {
  final Store store;
  final bool selected;
  final VoidCallback onTap;

  const _StoreToggleChip({
    required this.store,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = store.city != null && store.city!.isNotEmpty
        ? '${store.name} (${store.city})'
        : store.name;

    return FilterChip(
      selected: selected,
      showCheckmark: true,
      avatar: Icon(
        selected ? Icons.storefront : Icons.storefront_outlined,
        size: 18,
        color: selected ? AppColors.onAccent : AppColors.textMuted,
      ),
      label: Text(
        selected ? '$label · On' : '$label · Off',
        style: theme.textTheme.labelLarge?.copyWith(
          color: selected ? AppColors.onAccent : AppColors.textPrimary,
        ),
      ),
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.surfaceElevated,
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.borderHairline,
        width: selected ? 1.5 : 1,
      ),
      onSelected: (_) => onTap(),
    );
  }
}
