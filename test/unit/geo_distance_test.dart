import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/stores/domain/geo_distance.dart';

void main() {
  test('milesBetween is roughly correct for known cities', () {
    // Atlanta → Marietta is on the order of 15–25 miles.
    final miles = GeoDistance.milesBetween(
      lat1: 33.7490,
      lon1: -84.3880,
      lat2: 33.9526,
      lon2: -84.5499,
    );
    expect(miles, greaterThan(10));
    expect(miles, lessThan(30));
  });

  test('formatMiles uses one decimal under 10', () {
    expect(GeoDistance.formatMiles(0.05), '< 0.1 mi');
    expect(GeoDistance.formatMiles(3.2), '3.2 mi');
    expect(GeoDistance.formatMiles(42.4), '42 mi');
  });

  test('formatMiles marks coarse GPS as approximate', () {
    expect(GeoDistance.formatMiles(0.2, approximate: true), '~< 0.5 mi');
    expect(GeoDistance.formatMiles(3.2, approximate: true), '~3 mi');
    expect(GeoDistance.formatMiles(42.4, approximate: true), '~42 mi');
  });

  test('isPlausible rejects Null Island and out-of-range coords', () {
    expect(GeoDistance.isPlausible(lat: 33.75, lon: -84.39), isTrue);
    expect(GeoDistance.isPlausible(lat: 0, lon: 0), isFalse);
    expect(GeoDistance.isPlausible(lat: 91, lon: 0), isFalse);
    expect(GeoDistance.isPlausible(lat: double.nan, lon: 0), isFalse);
  });
}
