import '/model/place.dart';

/// One address component normalized from either wire format:
/// legacy `long_name`/`short_name` or Places API (New) `longText`/`shortText`.
class RawAddressComponent {
  final List<String> types;
  final String? longText;
  final String? shortText;

  const RawAddressComponent(
      {required this.types, this.longText, this.shortText});
}

/// Builds a [Place] from normalized address [components] plus top-level
/// fields. Shared by both API providers so that derived fields
/// ([Place.zipCodePlus4] and the synthesized [Place.streetAddress],
/// [Place.formattedAddress], [Place.formattedAddressZipPlus4]) behave
/// identically regardless of backend.
Place buildPlaceFromComponents({
  required List<RawAddressComponent> components,
  String? name,
  String? formattedAddress,
  double? lat,
  double? lng,
}) {
  final place = Place();

  place.formattedAddress = formattedAddress;
  place.name = name;
  place.lat = lat;
  place.lng = lng;

  for (final component in components) {
    final type = component.types;
    if (type.contains('street_address')) {
      place.streetAddress = component.longText;
    }
    if (type.contains('street_number')) {
      place.streetNumber = component.longText;
    }
    if (type.contains('route')) {
      place.street = component.longText;
      place.streetShort = component.shortText;
    }
    if (type.contains('sublocality') || type.contains('sublocality_level_1')) {
      place.vicinity = component.longText;
    }
    if (type.contains('locality')) {
      place.city = component.longText;
    }
    if (type.contains('administrative_area_level_2')) {
      place.county = component.longText;
    }
    if (type.contains('administrative_area_level_1')) {
      place.state = component.longText;
      place.stateShort = component.shortText;
    }
    if (type.contains('country')) {
      place.country = component.longText;
    }
    if (type.contains('postal_code')) {
      place.zipCode = component.longText;
    }
    if (type.contains('postal_code_suffix')) {
      place.zipCodeSuffix = component.longText;
    }
  }

  place.zipCodePlus4 ??=
      '${place.zipCode}${place.zipCodeSuffix != null ? '-${place.zipCodeSuffix}' : ''}';
  if (place.streetNumber != null) {
    place.streetAddress ??= '${place.streetNumber} ${place.streetShort}';
    place.formattedAddress ??=
        '${place.streetNumber} ${place.streetShort}, ${place.city}, ${place.stateShort} ${place.zipCode}';
    place.formattedAddressZipPlus4 ??=
        '${place.streetNumber} ${place.streetShort}, ${place.city}, ${place.stateShort} ${place.zipCodePlus4}';
  }
  return place;
}
