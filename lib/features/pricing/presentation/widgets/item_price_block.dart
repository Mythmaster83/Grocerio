import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/entities/store_price.dart';
import '../../domain/price_selection.dart';
import '../providers/pricing_di.dart';

/// Trailing price cell on a list row: the price, then brand + age on one
/// line and the place on the next.
///
/// Brand and place used to share one unconstrained line
/// (`Kroger · Stone Mountain, GA · 4m ago`). After addresses loaded that
/// string stole width from the item name and ellipsized it. Splitting them
/// keeps the same 11px type and a bounded trailing column.
class ItemPriceBlock extends ConsumerWidget {
  final int? canonicalItemId;

  /// Opens the reporting flow. Also used for unmatched items, where it first
  /// asks which product they are.
  final VoidCallback onReport;

  const ItemPriceBlock({
    super.key,
    required this.canonicalItemId,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = canonicalItemId;
    if (id == null) return _NoPrice(onReport: onReport);

    final comparison = ref.watch(itemPriceProvider(id));
    final cheapest = comparison.valueOrNull?.cheapest;
    if (cheapest == null) return _NoPrice(onReport: onReport);

    return _PriceCell(price: cheapest);
  }
}

class _PriceCell extends StatelessWidget {
  final StorePrice price;
  const _PriceCell({required this.price});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = price.isStale ? AppColors.textMuted : AppColors.accent;
    final storeStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.textMuted,
      fontSize: 11,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '\$${price.price.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${price.storeName} · ${formatReportedAge(price.reportedAt, DateTime.now())}',
            style: storeStyle,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (price.storePlace.isNotEmpty)
            Text(
              price.storePlace,
              style: storeStyle,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _NoPrice extends StatelessWidget {
  final VoidCallback onReport;
  const _NoPrice({required this.onReport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No price yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          SizedBox(
            height: 28,
            child: TextButton(
              onPressed: onReport,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Report'),
            ),
          ),
        ],
      ),
    );
  }
}
