/// Use [AddressAutocompleteTextField] to replace [TextField] widgets where you want to add Google Places autocompletion.
/// Use [AddressAutocompleteTextFormField] to replace [TextFormField] widgets where you want to add Google Places autocompletion.
/// You only requirement is to supply your Google Maps API key in the [mapsApiKey] parameter.
/// You optionally can specify the type of Google Places autocomplete information returned using the [type] or [types] parameters
/// (The default is [AutoCompleteType.address]).
library;

export 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
export 'package:google_maps_places_autocomplete_widgets/widgets/address_autocomplete_textfield.dart';
export 'package:google_maps_places_autocomplete_widgets/widgets/address_autocomplete_textformfield.dart';
export 'package:google_maps_places_autocomplete_widgets/model/place.dart';
export 'package:google_maps_places_autocomplete_widgets/model/suggestion.dart';
export 'package:google_maps_places_autocomplete_widgets/api/place_api_provider.dart';
export 'package:google_maps_places_autocomplete_widgets/api/places_api_version.dart';
