import 'package:colorful_iconify_flutter/icons/fluent_emoji_flat.dart';
import 'package:flutter/material.dart';
import 'package:iconify_flutter/iconify_flutter.dart';

import '../../domain/item_icon_kind.dart';

/// Colorful icon for a grocery item, derived from its name.
///
/// Replaces the old Pexels photo thumbnail: the SVGs ship inside the app, so
/// there is no HTTP request, API key, attribution link, or rate limit in the
/// "add item" path — and it renders identically offline.
///
/// Icon set: Microsoft Fluent Emoji (flat), MIT licensed.
class ItemIconAvatar extends StatelessWidget {
  final String itemName;
  final double size;

  const ItemIconAvatar({
    super.key,
    required this.itemName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kind = ItemIconResolver.resolve(itemName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      // Decorative: the item name is always rendered next to this icon, so
      // announcing it again would just make the row noisier for screen readers.
      child: ExcludeSemantics(
        child: Center(
          child: Iconify(_svgFor(kind), size: size * 0.62),
        ),
      ),
    );
  }

  static String _svgFor(ItemIconKind kind) => switch (kind) {
        ItemIconKind.milk => FluentEmojiFlat.glass_of_milk,
        ItemIconKind.cheese => FluentEmojiFlat.cheese_wedge,
        ItemIconKind.butter => FluentEmojiFlat.butter,
        ItemIconKind.egg => FluentEmojiFlat.egg,
        ItemIconKind.bread => FluentEmojiFlat.bread,
        ItemIconKind.baguette => FluentEmojiFlat.baguette_bread,
        ItemIconKind.croissant => FluentEmojiFlat.croissant,
        ItemIconKind.bagel => FluentEmojiFlat.bagel,
        ItemIconKind.pretzel => FluentEmojiFlat.pretzel,
        ItemIconKind.pancake => FluentEmojiFlat.pancakes,
        ItemIconKind.rice => FluentEmojiFlat.cooked_rice,
        ItemIconKind.pasta => FluentEmojiFlat.spaghetti,
        ItemIconKind.cereal => FluentEmojiFlat.steaming_bowl,
        ItemIconKind.apple => FluentEmojiFlat.red_apple,
        ItemIconKind.banana => FluentEmojiFlat.banana,
        ItemIconKind.grapes => FluentEmojiFlat.grapes,
        ItemIconKind.strawberry => FluentEmojiFlat.strawberry,
        ItemIconKind.watermelon => FluentEmojiFlat.watermelon,
        ItemIconKind.orange => FluentEmojiFlat.tangerine,
        ItemIconKind.lemon => FluentEmojiFlat.lemon,
        ItemIconKind.pineapple => FluentEmojiFlat.pineapple,
        ItemIconKind.mango => FluentEmojiFlat.mango,
        ItemIconKind.peach => FluentEmojiFlat.peach,
        ItemIconKind.pear => FluentEmojiFlat.pear,
        ItemIconKind.cherries => FluentEmojiFlat.cherries,
        ItemIconKind.avocado => FluentEmojiFlat.avocado,
        ItemIconKind.tomato => FluentEmojiFlat.tomato,
        ItemIconKind.potato => FluentEmojiFlat.potato,
        ItemIconKind.onion => FluentEmojiFlat.onion,
        ItemIconKind.garlic => FluentEmojiFlat.garlic,
        ItemIconKind.broccoli => FluentEmojiFlat.broccoli,
        ItemIconKind.cucumber => FluentEmojiFlat.cucumber,
        ItemIconKind.leafyGreen => FluentEmojiFlat.leafy_green,
        ItemIconKind.corn => FluentEmojiFlat.ear_of_corn,
        ItemIconKind.mushroom => FluentEmojiFlat.mushroom,
        ItemIconKind.pepper => FluentEmojiFlat.hot_pepper,
        ItemIconKind.eggplant => FluentEmojiFlat.eggplant,
        ItemIconKind.carrot => FluentEmojiFlat.carrot,
        ItemIconKind.chicken => FluentEmojiFlat.poultry_leg,
        ItemIconKind.meat => FluentEmojiFlat.meat_on_bone,
        ItemIconKind.bacon => FluentEmojiFlat.bacon,
        ItemIconKind.fish => FluentEmojiFlat.fish,
        ItemIconKind.shrimp => FluentEmojiFlat.shrimp,
        ItemIconKind.crab => FluentEmojiFlat.crab,
        ItemIconKind.burger => FluentEmojiFlat.hamburger,
        ItemIconKind.pizza => FluentEmojiFlat.pizza,
        ItemIconKind.hotDog => FluentEmojiFlat.hot_dog,
        ItemIconKind.sandwich => FluentEmojiFlat.sandwich,
        ItemIconKind.fries => FluentEmojiFlat.french_fries,
        ItemIconKind.popcorn => FluentEmojiFlat.popcorn,
        ItemIconKind.cookie => FluentEmojiFlat.cookie,
        ItemIconKind.chocolate => FluentEmojiFlat.chocolate_bar,
        ItemIconKind.candy => FluentEmojiFlat.candy,
        ItemIconKind.doughnut => FluentEmojiFlat.doughnut,
        ItemIconKind.cupcake => FluentEmojiFlat.cupcake,
        ItemIconKind.cake => FluentEmojiFlat.birthday_cake,
        ItemIconKind.iceCream => FluentEmojiFlat.ice_cream,
        ItemIconKind.honey => FluentEmojiFlat.honey_pot,
        ItemIconKind.nuts => FluentEmojiFlat.peanuts,
        ItemIconKind.coffee => FluentEmojiFlat.hot_beverage,
        ItemIconKind.tea => FluentEmojiFlat.teacup_without_handle,
        ItemIconKind.beer => FluentEmojiFlat.beer_mug,
        ItemIconKind.wine => FluentEmojiFlat.wine_glass,
        ItemIconKind.juice => FluentEmojiFlat.beverage_box,
        ItemIconKind.softDrink => FluentEmojiFlat.cup_with_straw,
        ItemIconKind.water => FluentEmojiFlat.potable_water,
        ItemIconKind.babyBottle => FluentEmojiFlat.baby_bottle,
        ItemIconKind.salt => FluentEmojiFlat.salt,
        ItemIconKind.cooking => FluentEmojiFlat.cooking,
        ItemIconKind.cannedFood => FluentEmojiFlat.canned_food,
        ItemIconKind.soap => FluentEmojiFlat.soap,
        ItemIconKind.toiletPaper => FluentEmojiFlat.roll_of_paper,
        ItemIconKind.sponge => FluentEmojiFlat.sponge,
        ItemIconKind.broom => FluentEmojiFlat.broom,
        ItemIconKind.bucket => FluentEmojiFlat.bucket,
        ItemIconKind.toothbrush => FluentEmojiFlat.toothbrush,
        ItemIconKind.lotion => FluentEmojiFlat.lotion_bottle,
        ItemIconKind.medicine => FluentEmojiFlat.pill,
        ItemIconKind.bandage => FluentEmojiFlat.adhesive_bandage,
        ItemIconKind.petFood => FluentEmojiFlat.dog_face,
        ItemIconKind.generic => FluentEmojiFlat.basket,
      };
}
