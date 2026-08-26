import 'package:flutter_test/flutter_test.dart';
import 'package:grocer/features/stores/domain/entities/store.dart';

void main() {
  const walmart = Store(
    id: 1,
    slug: 'walmart-az-85120',
    name: 'Walmart',
    chainSlug: 'walmart',
    trackedByUser: true,
    addressLine: '2555 West Apache Trail',
    city: 'Apache Junction',
    state: 'AZ',
    zip: '85120',
    latitude: 33.413804,
    longitude: -111.575329,
  );

  const placeholder = Store(
    id: 2,
    slug: 'kroger-ga-atlanta',
    name: 'Kroger',
    chainSlug: 'kroger',
    trackedByUser: false,
    addressLine: 'Store in Atlanta',
    city: 'Atlanta',
    state: 'GA',
    zip: '30303',
  );

  const mainStreet = Store(
    id: 3,
    slug: 'publix-ga-30047',
    name: 'Publix',
    chainSlug: 'publix',
    trackedByUser: false,
    addressLine: '4120 Highway 29',
    city: 'Lilburn',
    state: 'GA',
    zip: '30047',
  );

  test('subtitle prefers a real street over city-only', () {
    expect(
      walmart.subtitle,
      '2555 West Apache Trail · Apache Junction, AZ 85120',
    );
    expect(walmart.hasStreetAddress, isTrue);
  });

  test('OSM "Store in City" placeholders are not shown as the street', () {
    expect(placeholder.hasStreetAddress, isFalse);
    expect(placeholder.subtitle, 'Atlanta, GA 30303');
  });

  test('a real Main-style street is kept', () {
    const onMain = Store(
      id: 4,
      slug: 'aldi-ga-main',
      name: 'Aldi',
      chainSlug: 'aldi',
      trackedByUser: false,
      addressLine: '100 Main Street',
      city: 'Decatur',
      state: 'GA',
      zip: '30030',
    );
    expect(onMain.hasStreetAddress, isTrue);
    expect(onMain.subtitle, contains('100 Main Street'));
  });

  test('listLabel stays compact for chips', () {
    expect(walmart.listLabel, 'Walmart · Apache Junction, AZ');
    expect(mainStreet.listLabel, 'Publix · Lilburn, GA');
  });
}
