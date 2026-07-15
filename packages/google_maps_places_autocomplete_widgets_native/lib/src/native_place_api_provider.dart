import 'package:flutter/foundation.dart';
import 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
import 'package:google_maps_places_autocomplete_widgets/api/new_api_type_mapping.dart';
import 'package:google_maps_places_autocomplete_widgets/api/place_api_provider.dart';
import 'package:google_maps_places_autocomplete_widgets/api/place_builder.dart';
import 'package:google_maps_places_autocomplete_widgets/model/place.dart';
import 'package:google_maps_places_autocomplete_widgets/model/suggestion.dart';

import 'messages.g.dart';

/// [PlaceApiProvider] backed by Google's native Places SDKs (Android/iOS).
///
/// Compared to the core package's REST backend this enables:
///  - app-restricted API keys with zero header configuration, and
///  - Firebase App Check attestation ([initialize] with `useAppCheck: true`),
///    which — with enforcement turned on — makes a scraped key useless
///    outside your genuine app.
///
/// Only Android and iOS are supported ([isSupported]); use the core REST
/// backend on web/desktop. Billing session tokens are managed natively.
class NativePlaceApiProvider extends PlaceApiProvider {
  NativePlaceApiProvider(
      {this.componentCountry,
      this.language,
      @visibleForTesting PlacesNativeApi? api})
      : _api = api ?? _sharedApi ?? PlacesNativeApi();

  final String? componentCountry;
  final String? language;
  final PlacesNativeApi _api;

  static PlacesNativeApi? _sharedApi;
  static bool _initialized = false;

  /// True on Android and iOS (the platforms the native Places SDKs exist on).
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initializes the native Places SDK (New) with [mapsApiKey]. Call once
  /// (e.g. in main()) before constructing providers. With [useAppCheck] the
  /// SDKs' Firebase App Check token providers are installed — the host app
  /// must have configured firebase_core + firebase_app_check first.
  static Future<void> initialize(
      {required String mapsApiKey,
      bool useAppCheck = false,
      @visibleForTesting PlacesNativeApi? api}) async {
    _ensureSupportedPlatform();
    _sharedApi = api ?? PlacesNativeApi();
    await _sharedApi!.initialize(mapsApiKey, useAppCheck);
    _initialized = true;
  }

  @visibleForTesting
  static void resetForTesting() {
    _sharedApi = null;
    _initialized = false;
  }

  static void _ensureSupportedPlatform() {
    if (!isSupported) {
      throw UnsupportedError(
          'NativePlaceApiProvider is only available on Android and iOS. '
          'On other platforms use the core package\'s default REST backend.');
    }
  }

  void _ensureReady() {
    _ensureSupportedPlatform();
    if (!_initialized) {
      throw StateError(
          'Call NativePlaceApiProvider.initialize(mapsApiKey: ...) before use.');
    }
  }

  @override
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types}) async {
    _ensureReady();
    validateAutocompleteTypes(types);
    final predictions = await _api.fetchPredictions(
        input, mapTypesToNewApi(types), componentCountry, language);
    return [
      for (final p in predictions)
        if (includeFullSuggestionDetails)
          Suggestion(p.placeId, p.fullText,
              mainText: p.primaryText,
              secondaryText: p.secondaryText,
              // The native SDKs have no equivalent of the legacy `terms`.
              terms: null,
              types: p.types?.whereType<String>().toList())
        else
          Suggestion(p.placeId, p.fullText),
    ];
  }

  @override
  Future<Place> getPlaceDetailFromId(String placeId) async {
    _ensureReady();
    final d = await _api.fetchPlace(placeId, language);
    return buildPlaceFromComponents(
      components: [
        for (final c in d.components)
          RawAddressComponent(
              types: c.types.whereType<String>().toList(),
              longText: c.longText,
              shortText: c.shortText),
      ],
      name: d.name,
      formattedAddress: d.formattedAddress,
      lat: d.lat,
      lng: d.lng,
    );
  }
}
