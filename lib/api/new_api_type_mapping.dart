import '/api/autocomplete_types.dart';

/// Legacy type filters with no direct Places API (New) equivalent, mapped to
/// the closest set of new-API types.
///
/// As of 2026-07 every other [AutoCompleteType] value's type string exists
/// unchanged in the new API's Table A/B (including the `(cities)` and
/// `(regions)` collections and the `geocode`/`establishment` filters), so no
/// other overrides are needed.
const Map<AutoCompleteType, List<String>> kNewApiTypeOverrides = {
  // The legacy `address` filter does not exist in the new API. These three
  // prediction types cover precise street addresses. Callers who want
  // broader geocoding results can use [AutoCompleteType.geocode] or supply
  // an explicit `types:` list instead.
  AutoCompleteType.address: ['street_address', 'premise', 'subpremise'],
};

/// Maps [types] to the new API's `includedPrimaryTypes` values.
///
/// Callers must run `validateAutocompleteTypes(types)` first; this function
/// only translates values.
List<String> mapTypesToNewApi(List<AutoCompleteType> types) {
  return [
    for (final type in types)
      ...kNewApiTypeOverrides[type] ?? [type.typeString],
  ];
}
