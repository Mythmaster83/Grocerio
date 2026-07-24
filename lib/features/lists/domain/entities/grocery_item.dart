import 'package:equatable/equatable.dart';

enum ItemUnit { piece, kg, g, l, ml, pack, dozen }

/// Domain entity — plain Dart, zero Isar/Riverpod/Flutter imports.
/// This is what the UI and usecases talk about. It is deliberately
/// decoupled from GroceryItemModel (the persistence shape) so that
/// swapping storage engines later never touches domain or presentation.
class GroceryItem extends Equatable {
  final String id;
  final String name;
  final double quantity;
  final ItemUnit unit;
  final bool isChecked;
  final String? imageUrl;
  final String? imagePhotographer;
  final String? imagePhotographerUrl;
  final DateTime updatedAt;

  const GroceryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isChecked,
    required this.updatedAt,
    this.imageUrl,
    this.imagePhotographer,
    this.imagePhotographerUrl,
  });

  GroceryItem copyWith({
    String? name,
    double? quantity,
    ItemUnit? unit,
    bool? isChecked,
    String? imageUrl,
    String? imagePhotographer,
    String? imagePhotographerUrl,
    DateTime? updatedAt,
  }) {
    return GroceryItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePhotographer: imagePhotographer ?? this.imagePhotographer,
      imagePhotographerUrl: imagePhotographerUrl ?? this.imagePhotographerUrl,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        quantity,
        unit,
        isChecked,
        imageUrl,
        imagePhotographer,
        imagePhotographerUrl,
        updatedAt,
      ];
}
