import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// A row that holds its layout together as textScale grows, per the
/// "fixed-height, responsive widgets respecting text size" UI requirement.
///
/// The trick: we don't hardcode a pixel height (that's what breaks under
/// large accessibility text — labels get clipped or overflow). Instead we
/// give the row a *minimum* height that scales with the ambient text scale
/// factor, so at 1.0x it looks like a normal compact list tile, and at
/// 1.4x it grows instead of clipping.
class FixedHeightTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Draws the row as its own surface card (fill, hairline border, radius).
  /// On by default because that's what every current caller wants; opt out for
  /// rows that already sit inside a card.
  final bool surface;

  const FixedHeightTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.surface = true,
  });

  static const double _baseHeight = 64;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: _baseHeight * scale),
      child: Padding(padding: padding, child: child),
    );

    if (!surface) return row;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: AppBorders.hairline,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: row,
    );
  }
}
