import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/api/place_builder.dart';

void main() {
  // Components mirroring the real captured JSON documented in
  // lib/api/place_api_provider.dart (6781 Eastside Rd, Anderson, CA).
  final components = [
    const RawAddressComponent(
        types: ['street_number'], longText: '6781', shortText: '6781'),
    const RawAddressComponent(
        types: ['route'], longText: 'Eastside Road', shortText: 'Eastside Rd'),
    const RawAddressComponent(
        types: ['locality', 'political'],
        longText: 'Anderson',
        shortText: 'Anderson'),
    const RawAddressComponent(
        types: ['administrative_area_level_2', 'political'],
        longText: 'Shasta County',
        shortText: 'Shasta County'),
    const RawAddressComponent(
        types: ['administrative_area_level_1', 'political'],
        longText: 'California',
        shortText: 'CA'),
    const RawAddressComponent(
        types: ['country', 'political'],
        longText: 'United States',
        shortText: 'US'),
    const RawAddressComponent(
        types: ['postal_code'], longText: '96007', shortText: '96007'),
    const RawAddressComponent(
        types: ['postal_code_suffix'], longText: '9406', shortText: '9406'),
  ];

  test('maps all component types to Place fields', () {
    final place = buildPlaceFromComponents(
      components: components,
      name: '6781 Eastside Rd',
      formattedAddress: '6781 Eastside Rd, Anderson, CA 96007, USA',
      lat: 40.4839756,
      lng: -122.34802,
    );

    expect(place.name, '6781 Eastside Rd');
    expect(place.formattedAddress, '6781 Eastside Rd, Anderson, CA 96007, USA');
    expect(place.lat, 40.4839756);
    expect(place.lng, -122.34802);
    expect(place.streetNumber, '6781');
    expect(place.street, 'Eastside Road');
    expect(place.streetShort, 'Eastside Rd');
    expect(place.city, 'Anderson');
    expect(place.county, 'Shasta County');
    expect(place.state, 'California');
    expect(place.stateShort, 'CA');
    expect(place.country, 'United States');
    expect(place.zipCode, '96007');
    expect(place.zipCodeSuffix, '9406');
  });

  test('derives zipCodePlus4 and synthesized street/formatted addresses', () {
    final place = buildPlaceFromComponents(components: components);

    expect(place.zipCodePlus4, '96007-9406');
    expect(place.streetAddress, '6781 Eastside Rd');
    expect(place.formattedAddress, '6781 Eastside Rd, Anderson, CA 96007');
    expect(place.formattedAddressZipPlus4,
        '6781 Eastside Rd, Anderson, CA 96007-9406');
  });

  test('zipCodePlus4 has no suffix part when postal_code_suffix missing', () {
    final place = buildPlaceFromComponents(
      components: components
          .where((c) => !c.types.contains('postal_code_suffix'))
          .toList(),
    );
    expect(place.zipCodePlus4, '96007');
  });

  test('does not synthesize addresses without a street_number', () {
    final place = buildPlaceFromComponents(
      components: components
          .where((c) => !c.types.contains('street_number'))
          .toList(),
    );
    expect(place.streetAddress, isNull);
    expect(place.formattedAddress, isNull);
    expect(place.formattedAddressZipPlus4, isNull);
  });

  test('maps sublocality to vicinity', () {
    final place = buildPlaceFromComponents(components: [
      const RawAddressComponent(
          types: ['sublocality_level_1', 'sublocality', 'political'],
          longText: 'Brooklyn',
          shortText: 'Brooklyn'),
    ]);
    expect(place.vicinity, 'Brooklyn');
  });
}
