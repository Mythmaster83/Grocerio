import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/theme/tokens.dart';
import '../../../item_icons/presentation/widgets/item_icon_avatar.dart';
import '../../../lists/domain/entities/grocery_item.dart';
import '../../../preferences/presentation/providers/preferences_controller.dart';
import '../../../stores/domain/entities/store.dart';
import '../../../stores/presentation/providers/stores_di.dart';
import '../providers/pricing_di.dart';

/// Offered right after a shopping trip is completed.
///
/// This is the single best moment to collect prices — the receipt is in hand
/// and the user just confirmed they bought these exact things — so it batches
/// every item that was checked off into one store selection and a column of
/// number fields. Skipping is one tap, and nothing here blocks the trip from
/// completing.
Future<void> showPostShoppingPriceSheet(
  BuildContext context, {
  required List<GroceryItem> items,
}) {
  // Only items with a catalog identity can be priced; asking the user to match
  // products one by one at this moment would defeat the point.
  final priceable = items
      .where((item) => item.canonicalItemId != null)
      .toList(growable: false);
  if (priceable.isEmpty) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PostShoppingPriceSheet(items: priceable),
  );
}

class _PostShoppingPriceSheet extends ConsumerStatefulWidget {
  final List<GroceryItem> items;
  const _PostShoppingPriceSheet({required this.items});

  @override
  ConsumerState<_PostShoppingPriceSheet> createState() =>
      _PostShoppingPriceSheetState();
}

class _PostShoppingPriceSheetState
    extends ConsumerState<_PostShoppingPriceSheet> {
  final _controllers = <String, TextEditingController>{};
  Store? _store;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _controllers[item.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Store? _defaultStore(List<Store> stores, String? lastSlug) {
    if (stores.isEmpty) return null;
    for (final store in stores) {
      if (store.slug == lastSlug) return store;
    }
    return stores.first;
  }

  Future<void> _saveAll() async {
    final store = _store;
    if (store == null || _saving) return;

    setState(() => _saving = true);
    final service = ref.read(priceServiceProvider);
    var saved = 0;
    String? firstError;

    for (final item in widget.items) {
      final raw = _controllers[item.id]?.text ?? '';
      if (raw.trim().isEmpty) continue;
      final price = InputSanitizer.parseQuantity(raw);
      if (price == null) continue;

      final result = await service.submitReport(
        canonicalItemId: item.canonicalItemId!,
        storeId: store.id,
        storeSlug: store.slug,
        price: price,
        unit: item.unitLabel,
        zip: store.zip,
      );
      result.when(
        ok: (_) => saved++,
        err: (failure) => firstError ??= failure.message,
      );
    }

    if (!mounted) return;
    ref.invalidate(preferencesControllerProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          firstError ??
              (saved == 0
                  ? 'No prices added'
                  : saved == 1
                      ? '1 price added — thanks'
                      : '$saved prices added — thanks'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    final allStores = ref.watch(storesStreamProvider).valueOrNull ?? const <Store>[];
    final stores = allStores.where((s) => s.trackedByUser).toList();
    final lastSlug =
        ref.watch(preferencesControllerProvider).valueOrNull?.lastReportedStoreSlug;
    if (stores.isNotEmpty) {
      _store ??= _defaultStore(stores, lastSlug);
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What did you pay?', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Add any prices you remember. Blank rows are skipped.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (stores.isNotEmpty)
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final store in stores)
                          ChoiceChip(
                            label: Text(store.listLabel),
                            selected: _store?.id == store.id,
                            onSelected: (_) => setState(() => _store = store),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return Row(
                    children: [
                      ItemIconAvatar(itemName: item.name, size: 32),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _controllers[item.id],
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          textInputAction: index == widget.items.length - 1
                              ? TextInputAction.done
                              : TextInputAction.next,
                          decoration: const InputDecoration(
                            isDense: true,
                            prefixText: '\$ ',
                            hintText: '0.00',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _store == null || _saving ? null : _saveAll,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save prices'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
