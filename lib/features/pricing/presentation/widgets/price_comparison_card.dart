import 'package:flutter/material.dart';
import '../../../../core/theme/tokens.dart';
import '../../../catalog/domain/entities/canonical_item.dart';
import '../../../item_icons/presentation/widgets/item_icon_avatar.dart';
import '../../domain/entities/store_price.dart';
import '../../domain/price_selection.dart';
import '../../../stores/domain/entities/store.dart';

/// One product, priced across every selected store.
///
/// Each store gets a cell whether or not it has a price, because an empty cell
/// is itself the call to action: it's the only place a shopper can see that
/// nobody has reported this yet, and tap to fix it.
class PriceComparisonCard extends StatelessWidget {
  final CanonicalItem item;
  final PriceComparison comparison;
  final List<Store> stores;

  /// Called with the store the user wants to price.
  final void Function(Store store) onReport;

  const PriceComparisonCard({
    super.key,
    required this.item,
    required this.comparison,
    required this.stores,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final byStoreId = {for (final p in comparison.byStore) p.storeId: p};
    final cheapestStoreId = comparison.cheapest?.storeId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ItemIconAvatar(itemName: item.name, size: 36),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final store in stores)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _StoreRow(
                  store: store,
                  price: byStoreId[store.id],
                  isCheapest: byStoreId.length > 1 && store.id == cheapestStoreId,
                  now: now,
                  onReport: () => onReport(store),
                ),
              ),
            if (!comparison.hasAnyPrice)
              Text(
                'Prices come from shoppers. Add the first one.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _StoreRow extends StatelessWidget {
  final Store store;
  final StorePrice? price;
  final bool isCheapest;
  final DateTime now;
  final VoidCallback onReport;

  const _StoreRow({
    required this.store,
    required this.price,
    required this.isCheapest,
    required this.now,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = price;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isCheapest ? AppColors.accentTint : AppColors.surfaceElevated,
        border: AppBorders.hairline,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(store.listLabel, style: theme.textTheme.bodyMedium),
                if (current != null)
                  Text(
                    'reported ${formatReportedAge(current.reportedAt, now)}'
                    '${current.isStale ? ' · may be out of date' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (current == null)
            TextButton(onPressed: onReport, child: const Text('Report price'))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '\$${current.price.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: current.isStale
                            ? AppColors.textMuted
                            : (isCheapest
                                ? AppColors.accent
                                : AppColors.textPrimary),
                      ),
                    ),
                    Text(
                      'per ${current.unit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onReport,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Update price',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
