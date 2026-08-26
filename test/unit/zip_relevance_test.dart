import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/pricing/domain/zip_relevance.dart';

void main() {
  group('normalizeZip', () {
    test('strips non-digits and keeps five', () {
      expect(normalizeZip('30318-1234'), '30318');
      expect(normalizeZip('  30318  '), '30318');
    });

    test('accepts a three-digit prefix', () {
      expect(normalizeZip('303'), '303');
    });

    test('rejects anything shorter than a prefix', () {
      expect(normalizeZip('30'), isNull);
      expect(normalizeZip(''), isNull);
      expect(normalizeZip(null), isNull);
      expect(normalizeZip('abc'), isNull);
    });
  });

  group('zipPrefix', () {
    test('is the first three digits', () {
      expect(zipPrefix('30318'), '303');
      expect(zipPrefix('30318-9999'), '303');
    });
  });

  group('reportMatchesArea', () {
    test('same metro matches', () {
      expect(
        reportMatchesArea(reportZip: '30318', userZip: '30309'),
        isTrue,
      );
    });

    test('different metro does not match', () {
      expect(
        reportMatchesArea(reportZip: '44101', userZip: '30318'),
        isFalse,
      );
    });

    test('missing ZIP on either side is treated as somewhere else', () {
      expect(reportMatchesArea(reportZip: null, userZip: '30318'), isFalse);
      expect(reportMatchesArea(reportZip: '30318', userZip: null), isFalse);
      expect(reportMatchesArea(reportZip: null, userZip: null), isFalse);
    });
  });
}
