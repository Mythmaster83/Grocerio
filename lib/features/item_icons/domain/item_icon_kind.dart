/// Icon categories an item name can resolve to.
///
/// Deliberately semantic ("milk", "leafyGreen") rather than named after a
/// specific icon set, so swapping the icon pack later is a change in the
/// presentation layer only — this file and its rules stay untouched.
enum ItemIconKind {
  // Dairy & eggs
  milk,
  cheese,
  butter,
  egg,

  // Bakery & grains
  bread,
  baguette,
  croissant,
  bagel,
  pretzel,
  pancake,
  rice,
  pasta,
  cereal,

  // Fruit
  apple,
  banana,
  grapes,
  strawberry,
  watermelon,
  orange,
  lemon,
  pineapple,
  mango,
  peach,
  pear,
  cherries,
  avocado,

  // Vegetables
  tomato,
  potato,
  onion,
  garlic,
  broccoli,
  cucumber,
  leafyGreen,
  corn,
  mushroom,
  pepper,
  eggplant,
  carrot,

  // Protein
  chicken,
  meat,
  bacon,
  fish,
  shrimp,
  crab,

  // Prepared & snacks
  burger,
  pizza,
  hotDog,
  sandwich,
  fries,
  popcorn,
  cookie,
  chocolate,
  candy,
  doughnut,
  cupcake,
  cake,
  iceCream,
  honey,
  nuts,

  // Drinks
  coffee,
  tea,
  beer,
  wine,
  juice,
  softDrink,
  water,
  babyBottle,

  // Pantry
  salt,
  cooking,
  cannedFood,

  // Household & care
  soap,
  toiletPaper,
  sponge,
  broom,
  bucket,
  toothbrush,
  lotion,
  medicine,
  bandage,
  petFood,

  /// Fallback when nothing matches.
  generic,
}

/// Maps a free-text item name ("2% milk", "toilet paper") to an
/// [ItemIconKind] using substring keyword rules.
///
/// Pure Dart on purpose: no Flutter and no icon-package imports, so the rules
/// are unit-testable and cost nothing at render time beyond a string scan.
class ItemIconResolver {
  ItemIconResolver._();

  static ItemIconKind resolve(String itemName) {
    final name = itemName.toLowerCase().trim();
    if (name.isEmpty) return ItemIconKind.generic;

    for (final rule in _rules) {
      for (final keyword in rule.keywords) {
        if (name.contains(keyword)) return rule.kind;
      }
    }
    return ItemIconKind.generic;
  }
}

class _Rule {
  final ItemIconKind kind;
  final List<String> keywords;
  const _Rule(this.kind, this.keywords);
}

/// ORDER IS PART OF THE BEHAVIOUR. Matching is substring-based, so any rule
/// whose keyword is contained inside another word must come first:
/// "toilet" before "oil", "shampoo" before "ham", "pineapple" before "apple",
/// "watermelon" before "water", "popcorn" before "corn", "eggplant" before
/// "egg", "doughnut" before "nut", "candy" before "canned".
const List<_Rule> _rules = [
  // --- Trap-prone rules: these MUST outrank the shorter keywords below ---
  _Rule(ItemIconKind.toiletPaper,
      ['toilet', 'tissue', 'paper towel', 'napkin', 'kitchen roll']),
  _Rule(ItemIconKind.soap, [
    'shampoo',
    'conditioner',
    'detergent',
    'soap',
    'body wash',
    'hand wash',
    'dish liquid',
  ]),
  _Rule(ItemIconKind.iceCream, ['ice cream', 'icecream', 'gelato', 'sorbet', 'popsicle']),
  _Rule(ItemIconKind.petFood, ['dog food', 'cat food', 'pet food', 'cat litter', 'kibble']),
  _Rule(ItemIconKind.nuts, ['peanut']),
  _Rule(ItemIconKind.doughnut, ['doughnut', 'donut']),
  _Rule(ItemIconKind.cupcake, ['cupcake', 'muffin']),
  _Rule(ItemIconKind.pancake, ['pancake', 'waffle']),
  _Rule(ItemIconKind.popcorn, ['popcorn']),
  _Rule(ItemIconKind.eggplant, ['eggplant', 'aubergine']),
  _Rule(ItemIconKind.pineapple, ['pineapple']),
  _Rule(ItemIconKind.watermelon, ['watermelon']),
  _Rule(ItemIconKind.candy, ['candy', 'sweets', 'sugar', 'gummy']),
  _Rule(ItemIconKind.chocolate, ['chocolate', 'cocoa', 'nutella']),
  _Rule(ItemIconKind.burger, ['burger']),
  _Rule(ItemIconKind.fries, ['fries', 'chips', 'crisps']),
  _Rule(ItemIconKind.softDrink, ['soda', 'cola', 'soft drink', 'lemonade', 'energy drink']),

  // --- Dairy & eggs ---
  _Rule(ItemIconKind.milk, ['milk', 'yogurt', 'yoghurt', 'cream']),
  _Rule(ItemIconKind.cheese, ['cheese', 'parmesan', 'mozzarella', 'feta']),
  _Rule(ItemIconKind.butter, ['butter', 'margarine']),
  _Rule(ItemIconKind.egg, ['egg']),

  // --- Bakery & grains ---
  _Rule(ItemIconKind.baguette, ['baguette']),
  _Rule(ItemIconKind.croissant, ['croissant']),
  _Rule(ItemIconKind.bagel, ['bagel']),
  _Rule(ItemIconKind.pretzel, ['pretzel']),
  _Rule(ItemIconKind.bread, ['bread', 'loaf', 'toast', 'bun', 'flour', 'tortilla', 'pita']),
  _Rule(ItemIconKind.rice, ['rice', 'risotto', 'quinoa']),
  _Rule(ItemIconKind.pasta, ['pasta', 'spaghetti', 'noodle', 'macaroni', 'penne', 'lasagna']),
  _Rule(ItemIconKind.cereal, ['cereal', 'granola', 'muesli', 'porridge', 'oat', 'soup']),

  // --- Fruit ---
  _Rule(ItemIconKind.apple, ['apple']),
  _Rule(ItemIconKind.banana, ['banana', 'plantain']),
  _Rule(ItemIconKind.grapes, ['grape', 'raisin']),
  _Rule(ItemIconKind.strawberry, ['strawberry', 'berry', 'berries']),
  _Rule(ItemIconKind.orange, ['orange', 'tangerine', 'mandarin', 'clementine']),
  _Rule(ItemIconKind.lemon, ['lemon', 'lime', 'citrus']),
  _Rule(ItemIconKind.mango, ['mango']),
  _Rule(ItemIconKind.peach, ['peach', 'apricot', 'nectarine']),
  _Rule(ItemIconKind.pear, ['pear']),
  _Rule(ItemIconKind.cherries, ['cherry', 'cherries']),
  _Rule(ItemIconKind.avocado, ['avocado', 'guacamole']),

  // --- Vegetables ---
  _Rule(ItemIconKind.tomato, ['tomato', 'ketchup', 'passata']),
  _Rule(ItemIconKind.potato, ['potato']),
  _Rule(ItemIconKind.onion, ['onion', 'shallot', 'leek']),
  _Rule(ItemIconKind.garlic, ['garlic', 'ginger']),
  _Rule(ItemIconKind.broccoli, ['broccoli', 'cauliflower', 'asparagus', 'green bean']),
  _Rule(ItemIconKind.cucumber, ['cucumber', 'pickle', 'zucchini', 'courgette']),
  _Rule(ItemIconKind.leafyGreen, [
    'lettuce',
    'spinach',
    'kale',
    'cabbage',
    'salad',
    'herb',
    'basil',
    'coriander',
    'parsley',
  ]),
  _Rule(ItemIconKind.corn, ['corn', 'maize']),
  _Rule(ItemIconKind.mushroom, ['mushroom']),
  _Rule(ItemIconKind.pepper, ['pepper', 'chili', 'chilli', 'jalapeno', 'paprika']),
  _Rule(ItemIconKind.carrot, ['carrot', 'parsnip', 'turnip', 'beet']),

  // --- Protein ---
  _Rule(ItemIconKind.chicken, ['chicken', 'turkey', 'poultry', 'drumstick', 'wing']),
  _Rule(ItemIconKind.bacon, ['bacon', 'pancetta']),
  _Rule(ItemIconKind.meat, [
    'beef',
    'steak',
    'mince',
    'lamb',
    'pork',
    'ham',
    'sausage',
    'meat',
    'ribs',
    'salami',
  ]),
  _Rule(ItemIconKind.fish, ['fish', 'salmon', 'tuna', 'cod', 'sardine', 'mackerel']),
  _Rule(ItemIconKind.shrimp, ['shrimp', 'prawn']),
  _Rule(ItemIconKind.crab, ['crab', 'lobster', 'seafood']),

  // --- Prepared & snacks ---
  _Rule(ItemIconKind.pizza, ['pizza']),
  _Rule(ItemIconKind.hotDog, ['hot dog', 'hotdog']),
  _Rule(ItemIconKind.sandwich, ['sandwich', 'wrap', 'burrito']),
  _Rule(ItemIconKind.cookie, ['cookie', 'biscuit', 'cracker']),
  _Rule(ItemIconKind.cake, ['cake', 'pastry', 'brownie', 'dessert']),
  _Rule(ItemIconKind.honey, ['honey', 'syrup', 'jam', 'marmalade']),
  _Rule(ItemIconKind.nuts, ['nut', 'almond', 'cashew', 'pistachio', 'seed']),

  // --- Drinks ---
  _Rule(ItemIconKind.coffee, ['coffee', 'espresso', 'latte', 'cappuccino']),
  _Rule(ItemIconKind.tea, ['tea', 'chai', 'matcha']),
  _Rule(ItemIconKind.beer, ['beer', 'lager', 'cider']),
  _Rule(ItemIconKind.wine, ['wine', 'champagne', 'prosecco']),
  _Rule(ItemIconKind.juice, ['juice', 'smoothie', 'squash']),
  _Rule(ItemIconKind.water, ['water', 'sparkling']),
  _Rule(ItemIconKind.babyBottle, ['baby', 'formula']),

  // --- Pantry ---
  _Rule(ItemIconKind.cannedFood, ['canned', 'tinned', 'can of', 'tin of']),
  _Rule(ItemIconKind.salt, ['salt', 'spice', 'seasoning', 'cumin', 'cinnamon']),
  _Rule(ItemIconKind.cooking, ['oil', 'vinegar', 'sauce', 'mayo', 'mustard', 'stock cube']),

  // --- Household & care ---
  _Rule(ItemIconKind.sponge, ['sponge', 'scourer']),
  _Rule(ItemIconKind.broom, ['broom', 'mop', 'brush']),
  _Rule(ItemIconKind.bucket, ['bucket', 'bin bag', 'trash bag', 'bin liner']),
  _Rule(ItemIconKind.toothbrush, ['toothbrush', 'toothpaste', 'floss']),
  _Rule(ItemIconKind.lotion, ['lotion', 'moisturiser', 'moisturizer', 'sunscreen', 'deodorant']),
  _Rule(ItemIconKind.medicine, ['medicine', 'pill', 'vitamin', 'tablet', 'ibuprofen', 'paracetamol']),
  _Rule(ItemIconKind.bandage, ['bandage', 'plaster', 'band aid']),
];
