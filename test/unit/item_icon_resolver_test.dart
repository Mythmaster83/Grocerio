import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/item_icons/domain/item_icon_kind.dart';

void main() {
  group('ItemIconResolver.resolve', () {
    test('matches plain names', () {
      expect(ItemIconResolver.resolve('Milk'), ItemIconKind.milk);
      expect(ItemIconResolver.resolve('carrots'), ItemIconKind.carrot);
      expect(ItemIconResolver.resolve('2L Whole Milk'), ItemIconKind.milk);
    });

    test('falls back to generic for unknown and empty names', () {
      expect(ItemIconResolver.resolve('widget'), ItemIconKind.generic);
      expect(ItemIconResolver.resolve('   '), ItemIconKind.generic);
    });

    // Matching is substring-based, so rule ORDER decides these. Each case
    // below is a word that contains a shorter keyword from another rule.
    test('specific keywords win over substrings of other words', () {
      expect(ItemIconResolver.resolve('toilet paper'), ItemIconKind.toiletPaper);
      expect(ItemIconResolver.resolve('shampoo'), ItemIconKind.soap);
      expect(ItemIconResolver.resolve('eggplant'), ItemIconKind.eggplant);
      expect(ItemIconResolver.resolve('pineapple'), ItemIconKind.pineapple);
      expect(ItemIconResolver.resolve('watermelon'), ItemIconKind.watermelon);
      expect(ItemIconResolver.resolve('popcorn'), ItemIconKind.popcorn);
      expect(ItemIconResolver.resolve('peanut butter'), ItemIconKind.nuts);
      expect(ItemIconResolver.resolve('doughnuts'), ItemIconKind.doughnut);
      expect(ItemIconResolver.resolve('ice cream'), ItemIconKind.iceCream);
      expect(ItemIconResolver.resolve('candy'), ItemIconKind.candy);
      expect(ItemIconResolver.resolve('steak'), ItemIconKind.meat);
      expect(ItemIconResolver.resolve('kale'), ItemIconKind.leafyGreen);
    });
  });
}
