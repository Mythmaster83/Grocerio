import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/theme/tokens.dart';
import '../../../lists/domain/entities/grocery_item.dart';
import '../../../lists/presentation/widgets/unit_picker.dart';
import '../../../preferences/presentation/providers/preferences_controller.dart';
import '../../../stores/domain/entities/store.dart';
import '../../../stores/presentation/providers/stores_di.dart';
import '../providers/pricing_di.dart';

/// Captures one price. Returns true when a report was saved.
///
/// Everything here is arranged around a single goal: the common case should be
/// "type a number, press enter". The store is pre-selected, the unit is
/// pre-filled from the item, and the number pad opens focused.
Future<bool> showReportPriceSheet(
  BuildContext context, {
  required int canonicalItemId,
  required String productName,
  ItemUnit initialUnit = ItemUnit.piece,
  String? initialCustomUnit,
  int? initialStoreId,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReportPriceSheet(
      canonicalItemId: canonicalItemId,
      productName: productName,
      initialUnit: initialUnit,
      initialCustomUnit: initialCustomUnit,
      initialStoreId: initialStoreId,
    ),
  );
  return saved ?? false;
}

class _ReportPriceSheet extends ConsumerStatefulWidget {
  final int canonicalItemId;
  final String productName;
  final ItemUnit initialUnit;
  final String? initialCustomUnit;

  /// Set when the user tapped a specific store's empty cell, so the sheet opens
  /// on the store they meant rather than their usual one.
  final int? initialStoreId;

  const _ReportPriceSheet({
    required this.canonicalItemId,
    required this.productName,
    required this.initialUnit,
    required this.initialCustomUnit,
    this.initialStoreId,
  });

  @override
  ConsumerState<_ReportPriceSheet> createState() => _ReportPriceSheetState();
}

class _ReportPriceSheetState extends ConsumerState<_ReportPriceSheet> {
  final _priceController = TextEditingController();
  late ItemUnit _unit;
  late String? _customUnit;
  Store? _store;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    _customUnit = widget.initialCustomUnit;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  /// Last store used, else the first tracked store. Falls back to any store so
  /// the sheet is never unusable just because nothing is tracked.
  Store? _defaultStore(List<Store> stores, String? lastSlug) {
    if (stores.isEmpty) return null;
    for (final store in stores) {
      if (store.id == widget.initialStoreId) return store;
    }
    for (final store in stores) {
      if (store.slug == lastSlug) return store;
    }
    return stores.first;
  }

  Future<void> _submit() async {
    final store = _store;
    if (store == null || _saving) return;

    final price = InputSanitizer.parseQuantity(_priceController.text);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a price, like 3.49')),
      );
      return;
    }

    setState(() => _saving = true);
    final result = await ref.read(priceServiceProvider).submitReport(
          canonicalItemId: widget.canonicalItemId,
          storeId: store.id,
          storeSlug: store.slug,
          price: price,
          unit: itemUnitLabel(_unit, _customUnit),
          zip: store.zip,
        );
    if (!mounted) return;

    result.when(
      ok: (_) {
        // Refresh so the picker's default store reflects this submission next
        // time without waiting for an app restart.
        ref.invalidate(preferencesControllerProvider);
        Navigator.of(context).pop(true);
      },
      err: (failure) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.message)));
      },
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report a price', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.productName,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
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
              )
            else
              Text(
                'Track at least one store in Your stores before reporting a price.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _priceController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: '\$ ',
                      hintText: '3.49',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: UnitPicker(
                    unit: _unit,
                    customUnit: _customUnit,
                    onChanged: (unit, custom) => setState(() {
                      _unit = unit;
                      _customUnit = custom;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _store == null || _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save price'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              (ref.watch(preferencesControllerProvider).valueOrNull?.priceZip ==
                      null)
                  ? 'Track a nearby store in Your stores so prices can sync by area. '
                      'Prices are what shoppers report, not official store data.'
                  : 'Prices are what shoppers report, not official store data.',
              style:
                  theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
