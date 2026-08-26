import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/tokens.dart';
import '../../../catalog/domain/entities/canonical_item.dart';
import '../../../catalog/domain/entities/item_category.dart';
import '../../../catalog/presentation/providers/catalog_di.dart';
import '../../../stores/domain/entities/store.dart';
import '../../../stores/presentation/providers/stores_di.dart';
import '../../domain/entities/store_price.dart';
import '../providers/pricing_di.dart';
import '../widgets/category_store_filters.dart';
import '../widgets/price_comparison_card.dart';
import '../widgets/price_search_bar.dart';
import '../widgets/report_price_sheet.dart';

/// Browse the catalog and compare what shoppers have reported.
///
/// Composition over Phases B and D: the catalog search, the price grouping, and
/// the report sheet all already exist. What this screen adds is the ability to
/// look up a price *before* deciding to buy something, which is the point of
/// tracking prices at all.
class PriceLookupScreen extends ConsumerStatefulWidget {
  const PriceLookupScreen({super.key});

  @override
  ConsumerState<PriceLookupScreen> createState() => _PriceLookupScreenState();
}

class _PriceLookupScreenState extends ConsumerState<PriceLookupScreen> {
  String _query = '';
  ItemCategory? _category;
  Set<int>? _selectedStoreIds;

  List<CanonicalItem> _results = const [];
  Map<int, PriceComparison> _comparisons = const {};
  bool _loading = true;

  Future<void> _load() async {
    setState(() => _loading = true);

    final catalog = ref.read(catalogRepositoryProvider);
    final searchResult =
        await catalog.search(_query, category: _category, limit: 30);
    final items = searchResult.when(ok: (i) => i, err: (_) => <CanonicalItem>[]);

    final comparisonResult = await ref.read(priceRepositoryProvider).comparisonsFor(
          items.map((i) => i.id).toList(growable: false),
          storeIdsFilter: _selectedStoreIds,
        );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = items;
      _comparisons = comparisonResult.when(
        ok: (map) => map,
        err: (_) => const <int, PriceComparison>{},
      );
    });
  }

  Future<void> _report(CanonicalItem item, Store store) async {
    final saved = await showReportPriceSheet(
      context,
      canonicalItemId: item.id,
      productName: item.name,
      initialStoreId: store.id,
    );
    if (saved) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allStores = ref.watch(storesStreamProvider).valueOrNull ?? const <Store>[];
    final trackedStores =
        allStores.where((s) => s.trackedByUser).toList(growable: false);

    // Filter chips are the stores you track — On/Off toggles which of those
    // appear in this comparison, not the whole US directory.
    if (_selectedStoreIds == null && trackedStores.isNotEmpty) {
      _selectedStoreIds = trackedStores.map((s) => s.id).toSet();
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    final visibleStores = trackedStores
        .where((s) => _selectedStoreIds?.contains(s.id) ?? true)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Price lookup')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                PriceSearchBar(
                  onChanged: (value) {
                    _query = value;
                    _load();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                CategoryStoreFilters(
                  selectedCategory: _category,
                  onCategoryChanged: (category) {
                    setState(() => _category = category);
                    _load();
                  },
                  stores: trackedStores,
                  selectedStoreIds: _selectedStoreIds ?? const {},
                  onStoresChanged: (ids) {
                    setState(() => _selectedStoreIds = ids);
                    _load();
                  },
                ),
                if (trackedStores.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      'No stores tracked yet. Open Your stores (drawer or '
                      'Settings) and turn on locations near you.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'No products match that search.',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.sm,
                          AppSpacing.lg,
                          AppSpacing.xxl,
                        ),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          return PriceComparisonCard(
                            item: item,
                            comparison: _comparisons[item.id] ??
                                PriceComparison.empty(item.id),
                            stores: visibleStores,
                            onReport: (store) => _report(item, store),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
