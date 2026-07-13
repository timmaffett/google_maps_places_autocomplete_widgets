import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
import 'package:google_maps_places_autocomplete_widgets/api/new_api_type_mapping.dart';

void main() {
  test('address (no new-API equivalent) expands to precise-address types', () {
    expect(mapTypesToNewApi([AutoCompleteType.address]),
        ['street_address', 'premise', 'subpremise']);
  });

  test('all other types map to their legacy type string unchanged', () {
    expect(mapTypesToNewApi([AutoCompleteType.postalCode]), ['postal_code']);
    expect(mapTypesToNewApi([AutoCompleteType.cities]), ['(cities)']);
    expect(mapTypesToNewApi([AutoCompleteType.regions]), ['(regions)']);
    expect(mapTypesToNewApi([AutoCompleteType.geocode]), ['geocode']);
    expect(
        mapTypesToNewApi([AutoCompleteType.establishment]), ['establishment']);
    expect(
        mapTypesToNewApi(
            [AutoCompleteType.bookStore, AutoCompleteType.bicycleStore]),
        ['book_store', 'bicycle_store']);
  });
}
