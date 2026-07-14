/// LIVE smoke tests that call the real Google Places APIs.
///
/// These are skipped unless `test/private_keys.json` exists (copy
/// `test/private_keys.json.template` and fill in your API keys). They make
/// billable (though session-tokened) requests, so they are meant for manual
/// pre-release verification, not CI:
///
///     flutter test test/live_api_smoke_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
import 'package:google_maps_places_autocomplete_widgets/api/legacy_place_api_provider.dart';
import 'package:google_maps_places_autocomplete_widgets/api/new_place_api_provider.dart';

const _testAddressQuery = '1600 Amphitheatre Parkway, Mountain View';

Map<String, dynamic> _loadKeys() {
  final file = File('test/private_keys.json');
  if (!file.existsSync()) return const {};
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final keys = _loadKeys();
  final newKey = (keys['newPlacesApiKey'] as String?) ?? '';
  final legacyKey = (keys['legacyPlacesApiKey'] as String?) ?? '';

  group('LIVE Places API (New)', () {
    test('autocomplete + place details round trip', () async {
      final provider = NewPlaceApiProvider(
          'live-smoke-new-0001', newKey, 'us', 'en-US');

      final suggestions = await provider.fetchSuggestions(_testAddressQuery,
          includeFullSuggestionDetails: true,
          types: [AutoCompleteType.address]);
      debugPrint('NEW API suggestions:');
      for (final s in suggestions) {
        debugPrint('  $s');
      }
      expect(suggestions, isNotEmpty,
          reason: 'expected at least one suggestion for a famous address');
      expect(suggestions.first.placeId, isNotEmpty);
      expect(suggestions.first.description, contains('Amphitheatre'));

      final place =
          await provider.getPlaceDetailFromId(suggestions.first.placeId);
      debugPrint('NEW API place details: $place');
      expect(place.lat, isNotNull);
      expect(place.lng, isNotNull);
      expect(place.city, isNotNull);
      expect(place.zipCode, isNotNull);
    });
  },
      skip: newKey.isEmpty
          ? 'no newPlacesApiKey in test/private_keys.json '
              '(copy test/private_keys.json.template)'
          : false);

  group('LIVE legacy Places API', () {
    test('autocomplete + place details round trip', () async {
      final provider = LegacyPlaceApiProvider(
          'live-smoke-legacy-0001', legacyKey, 'us', 'en-US');

      final suggestions = await provider.fetchSuggestions(_testAddressQuery,
          includeFullSuggestionDetails: true,
          types: [AutoCompleteType.address]);
      debugPrint('LEGACY API suggestions:');
      for (final s in suggestions) {
        debugPrint('  $s');
      }
      expect(suggestions, isNotEmpty,
          reason: 'expected at least one suggestion for a famous address');
      expect(suggestions.first.placeId, isNotEmpty);
      expect(suggestions.first.description, contains('Amphitheatre'));

      final place =
          await provider.getPlaceDetailFromId(suggestions.first.placeId);
      debugPrint('LEGACY API place details: $place');
      expect(place.lat, isNotNull);
      expect(place.lng, isNotNull);
      expect(place.city, isNotNull);
      expect(place.zipCode, isNotNull);
    });
  },
      skip: legacyKey.isEmpty
          ? 'no legacyPlacesApiKey in test/private_keys.json '
              '(copy test/private_keys.json.template)'
          : false);
}
