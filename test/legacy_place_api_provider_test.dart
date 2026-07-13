import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
import 'package:google_maps_places_autocomplete_widgets/api/legacy_place_api_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Captured real legacy responses (documented in comments in the original
// lib/api/place_api_provider.dart).
const _autocompleteJson = '''
{
  "status": "OK",
  "predictions": [
    {
      "description": "678 North Market Street, Redding, CA, USA",
      "place_id": "ChIJiRzbkjrt0lQRVvD61FBwlmw",
      "reference": "ChIJiRzbkjrt0lQRVvD61FBwlmw",
      "structured_formatting": {
        "main_text": "678 North Market Street",
        "secondary_text": "Redding, CA, USA"
      },
      "terms": [
        {"offset": 0, "value": "678"},
        {"offset": 4, "value": "North Market Street"},
        {"offset": 25, "value": "Redding"},
        {"offset": 34, "value": "CA"},
        {"offset": 38, "value": "USA"}
      ],
      "types": ["premise", "geocode"]
    }
  ]
}
''';

const _detailsJson = '''
{
  "status": "OK",
  "result": {
    "address_components": [
      {"long_name": "6781", "short_name": "6781", "types": ["street_number"]},
      {"long_name": "Eastside Road", "short_name": "Eastside Rd", "types": ["route"]},
      {"long_name": "Anderson", "short_name": "Anderson", "types": ["locality", "political"]},
      {"long_name": "Shasta County", "short_name": "Shasta County", "types": ["administrative_area_level_2", "political"]},
      {"long_name": "California", "short_name": "CA", "types": ["administrative_area_level_1", "political"]},
      {"long_name": "United States", "short_name": "US", "types": ["country", "political"]},
      {"long_name": "96007", "short_name": "96007", "types": ["postal_code"]},
      {"long_name": "9406", "short_name": "9406", "types": ["postal_code_suffix"]}
    ],
    "formatted_address": "6781 Eastside Rd, Anderson, CA 96007, USA",
    "geometry": {"location": {"lat": 40.4839756, "lng": -122.34802}},
    "name": "6781 Eastside Rd"
  }
}
''';

void main() {
  group('fetchSuggestions', () {
    test('sends legacy GET request with expected query parameters', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_autocompleteJson, 200);
      });
      final provider = LegacyPlaceApiProvider(
          'session-token-1', 'test-api-key', 'us', 'en-US',
          client: client);

      await provider.fetchSuggestions('678 north',
          types: [AutoCompleteType.address]);

      expect(captured.method, 'GET');
      expect(captured.url.host, 'maps.googleapis.com');
      expect(captured.url.path, '/maps/api/place/autocomplete/json');
      expect(captured.url.queryParameters['input'], '678 north');
      expect(captured.url.queryParameters['types'], 'address');
      expect(captured.url.queryParameters['key'], 'test-api-key');
      expect(captured.url.queryParameters['sessiontoken'], 'session-token-1');
      expect(captured.url.queryParameters['language'], 'en-US');
      expect(captured.url.queryParameters['components'], 'country:us');
    });

    test('omits language/components params when null', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_autocompleteJson, 200);
      });
      final provider = LegacyPlaceApiProvider(
          'session-token-1', 'test-api-key', null, null,
          client: client);

      await provider
          .fetchSuggestions('x', types: [AutoCompleteType.postalCode]);

      expect(captured.url.queryParameters.containsKey('language'), isFalse);
      expect(captured.url.queryParameters.containsKey('components'), isFalse);
      expect(captured.url.queryParameters['types'], 'postal_code');
    });

    test('parses simple suggestions (no full details)', () async {
      final client =
          MockClient((_) async => http.Response(_autocompleteJson, 200));
      final provider =
          LegacyPlaceApiProvider('t', 'k', null, null, client: client);

      final suggestions = await provider
          .fetchSuggestions('678', types: [AutoCompleteType.address]);

      expect(suggestions, hasLength(1));
      expect(suggestions[0].placeId, 'ChIJiRzbkjrt0lQRVvD61FBwlmw');
      expect(suggestions[0].description,
          '678 North Market Street, Redding, CA, USA');
      expect(suggestions[0].mainText, isNull);
    });

    test('parses full suggestion details when requested', () async {
      final client =
          MockClient((_) async => http.Response(_autocompleteJson, 200));
      final provider =
          LegacyPlaceApiProvider('t', 'k', null, null, client: client);

      final suggestions = await provider.fetchSuggestions('678',
          includeFullSuggestionDetails: true,
          types: [AutoCompleteType.address]);

      expect(suggestions[0].mainText, '678 North Market Street');
      expect(suggestions[0].secondaryText, 'Redding, CA, USA');
      expect(suggestions[0].terms,
          ['678', 'North Market Street', 'Redding', 'CA', 'USA']);
      expect(suggestions[0].types, ['premise', 'geocode']);
    });

    test('returns empty list on ZERO_RESULTS', () async {
      final client = MockClient((_) async =>
          http.Response(jsonEncode({'status': 'ZERO_RESULTS'}), 200));
      final provider =
          LegacyPlaceApiProvider('t', 'k', null, null, client: client);
      expect(
          await provider
              .fetchSuggestions('zzz', types: [AutoCompleteType.address]),
          isEmpty);
    });

    test('throws when a single-only type is combined with others', () async {
      final client =
          MockClient((_) async => http.Response(_autocompleteJson, 200));
      final provider =
          LegacyPlaceApiProvider('t', 'k', null, null, client: client);
      expect(
          () => provider.fetchSuggestions('x', types: [
                AutoCompleteType.address,
                AutoCompleteType.bookStore,
              ]),
          throwsException);
    });

    test('throws when more than 5 types supplied', () async {
      final client =
          MockClient((_) async => http.Response(_autocompleteJson, 200));
      final provider =
          LegacyPlaceApiProvider('t', 'k', null, null, client: client);
      expect(
          () => provider.fetchSuggestions('x', types: [
                AutoCompleteType.bookStore,
                AutoCompleteType.bakery,
                AutoCompleteType.bank,
                AutoCompleteType.bar,
                AutoCompleteType.cafe,
                AutoCompleteType.casino,
              ]),
          throwsException);
    });
  });

  group('getPlaceDetailFromId', () {
    test('sends legacy details request and parses Place', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_detailsJson, 200);
      });
      final provider = LegacyPlaceApiProvider(
          'session-token-1', 'test-api-key', 'us', 'en-US',
          client: client);

      final place =
          await provider.getPlaceDetailFromId('ChIJiRzbkjrt0lQRVvD61FBwlmw');

      expect(captured.url.host, 'maps.googleapis.com');
      expect(captured.url.path, '/maps/api/place/details/json');
      expect(captured.url.queryParameters['place_id'],
          'ChIJiRzbkjrt0lQRVvD61FBwlmw');
      expect(captured.url.queryParameters['fields'],
          'name,formatted_address,address_component,geometry');
      expect(captured.url.queryParameters['sessiontoken'], 'session-token-1');

      expect(place.name, '6781 Eastside Rd');
      expect(
          place.formattedAddress, '6781 Eastside Rd, Anderson, CA 96007, USA');
      expect(place.lat, 40.4839756);
      expect(place.lng, -122.34802);
      expect(place.city, 'Anderson');
      expect(place.stateShort, 'CA');
      expect(place.zipCodePlus4, '96007-9406');
    });

    test('throws with google error_message on API error status', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'status': 'REQUEST_DENIED',
            'error_message': 'The provided API key is invalid.'
          }),
          200));
      final provider =
          LegacyPlaceApiProvider('t', 'k', null, null, client: client);
      expect(
          () => provider.getPlaceDetailFromId('someid'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('The provided API key is invalid.'))));
    });
  });
}
