import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/tokens.dart';
import '../../../item_icons/presentation/widgets/item_icon_avatar.dart';
import '../../domain/entities/canonical_item.dart';
// Imported for the `.label` extension getter on ItemCategory, which does not
// travel transitively through canonical_item.dart.
import '../../domain/entities/item_category.dart';
import '../providers/catalog_di.dart';

/// Asks which catalog product a free-text item actually is.
///
/// Only shown when automatic resolution found nothing. The user can either
/// link to a seeded product or create a custom one so prices still attach
/// (e.g. "dumbbells" is not in the grocery seed).
Future<CanonicalItem?> showProductMatchSheet(
  BuildContext context, {
  required String itemName,
}) {
  return showModalBottomSheet<CanonicalItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ProductMatchSheet(itemName: itemName),
  );
}

class _ProductMatchSheet extends ConsumerStatefulWidget {
  final String itemName;
  const _ProductMatchSheet({required this.itemName});

  @override
  ConsumerState<_ProductMatchSheet> createState() => _ProductMatchSheetState();
}

class _ProductMatchSheetState extends ConsumerState<_ProductMatchSheet> {
  late final TextEditingController _controller;
  List<CanonicalItem> _results = const [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.itemName);
    _search(widget.itemName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final result = await ref.read(catalogRepositoryProvider).search(query);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _results = result.when(ok: (items) => items, err: (_) => const []);
    });
  }

  Future<void> _createCustom() async {
    if (_creating) return;
    setState(() => _creating = true);
    final name = _controller.text.trim().isEmpty
        ? widget.itemName
        : _controller.text.trim();
    final result =
        await ref.read(catalogRepositoryProvider).createCustom(name);
    if (!mounted) return;
    setState(() => _creating = false);
    result.when(
      ok: (item) => Navigator.of(context).pop(item),
      err: (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final customLabel = _controller.text.trim().isEmpty
        ? widget.itemName
        : _controller.text.trim();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Which product is this?',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Link "${widget.itemName}" to a known product, or save it '
                    'as a custom product so you can still report prices.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _controller,
                    onChanged: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search products',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      children: [
                        if (_results.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Text(
                              'Nothing in the catalog matches. Save it as a '
                              'custom product to track prices anyway.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                        for (final item in _results)
                          ListTile(
                            leading: ItemIconAvatar(
                                itemName: item.name, size: 36),
                            title: Text(item.name),
                            subtitle: Text(
                              item.category.label,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                            onTap: () => Navigator.of(context).pop(item),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.xxl,
                          ),
                          child: OutlinedButton.icon(
                            onPressed: _creating ? null : _createCustom,
                            icon: _creating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.add),
                            label: Text('Use "$customLabel" as custom product'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
