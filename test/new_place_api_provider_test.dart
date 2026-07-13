import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
import 'package:google_maps_places_autocomplete_widgets/api/new_place_api_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Response shaped per
// https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places/autocomplete
const _autocompleteJson = '''
{
  "suggestions": [
    {
      "placePrediction": {
        "place": "places/ChIJiRzbkjrt0lQRVvD61FBwlmw",
        "placeId": "ChIJiRzbkjrt0lQRVvD61FBwlmw",
        "text": {
          "text": "678 North Market Street, Redding, CA, USA",
          "matches": [{"endOffset": 3}]
        },
        "structuredFormat": {
          "mainText": {
            "text": "678 North Market Street",
            "matches": [{"endOffset": 3}]
          },
          "secondaryText": {"text": "Redding, CA, USA"}
        },
        "types": ["premise", "geocode"]
      }
    },
    {
      "queryPrediction": {
        "text": {"text": "pizza in Redding"}
      }
    }
  ]
}
''';

// Response shaped per
// https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places/get
const _detailsJson = '''
{
  "id": "ChIJiRzbkjrt0lQRVvD61FBwlmw",
  "formattedAddress": "6781 Eastside Rd, Anderson, CA 96007, USA",
  "location": {"latitude": 40.4839756, "longitude": -122.34802},
  "displayName": {"text": "6781 Eastside Rd", "languageCode": "en"},
  "addressComponents": [
    {"longText": "6781", "shortText": "6781", "types": ["street_number"]},
    {"longText": "Eastside Road", "shortText": "Eastside Rd", "types": ["route"]},
    {"longText": "Anderson", "shortText": "Anderson", "types": ["locality", "political"]},
    {"longText": "Shasta County", "shortText": "Shasta County", "types": ["administrative_area_level_2", "political"]},
    {"longText": "California", "shortText": "CA", "types": ["administrative_area_level_1", "political"]},
    {"longText": "United States", "shortText": "US", "types": ["country", "political"]},
    {"longText": "96007", "shortText": "96007", "types": ["postal_code"]},
    {"longText": "9406", "shortText": "9406", "types": ["postal_code_suffix"]}
  ]
}
''';

NewPlaceApiProvider _provider(MockClient client,
    {String? country = 'us', String? language = 'en-US'}) {
  return NewPlaceApiProvider(
      'session-token-1', 'test-api-key', country, language,
      client: client);
}

void main() {
  group('fetchSuggestions request shape', () {
    test('POSTs to places:autocomplete with key header and JSON body',
        () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_autocompleteJson, 200);
      });

      await _provider(client)
          .fetchSuggestions('678 north', types: [AutoCompleteType.address]);

      expect(captured.method, 'POST');
      expect(captured.url.toString(),
          'https://places.googleapis.com/v1/places:autocomplete');
      expect(captured.headers['X-Goog-Api-Key'], 'test-api-key');
      expect(captured.headers['Content-Type'], startsWith('application/json'));

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['input'], '678 north');
      expect(body['sessionToken'], 'session-token-1');
      expect(body['languageCode'], 'en-US');
      expect(body['includedRegionCodes'], ['us']);
      expect(body['includedPrimaryTypes'],
          ['street_address', 'premise', 'subpremise']);
    });

    test('omits languageCode/includedRegionCodes when null', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_autocompleteJson, 200);
      });

      await _provider(client, country: null, language: null)
          .fetchSuggestions('x', types: [AutoCompleteType.postalCode]);

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('languageCode'), isFalse);
      expect(body.containsKey('includedRegionCodes'), isFalse);
      expect(body['includedPrimaryTypes'], ['postal_code']);
    });

    test('sends app-restriction headers only when configured', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_autocompleteJson, 200);
      });
      final provider = NewPlaceApiProvider('t', 'k', null, null,
          androidPackageName: 'com.example.app',
          androidCertSha1Fingerprint: 'AA:BB:CC',
          iosBundleId: 'com.example.ios',
          client: client);

      await provider.fetchSuggestions('x', types: [AutoCompleteType.address]);

      expect(captured.headers['X-Android-Package'], 'com.example.app');
      expect(captured.headers['X-Android-Cert'], 'AA:BB:CC');
      expect(captured.headers['X-Ios-Bundle-Identifier'], 'com.example.ios');

      late http.Request captured2;
      final client2 = MockClient((request) async {
        captured2 = request;
        return http.Response(_autocompleteJson, 200);
      });
      await _provider(client2)
          .fetchSuggestions('x', types: [AutoCompleteType.address]);
      expect(captured2.headers.containsKey('X-Android-Package'), isFalse);
      expect(captured2.headers.containsKey('X-Android-Cert'), isFalse);
      expect(
          captured2.headers.containsKey('X-Ios-Bundle-Identifier'), isFalse);
    });

    test('validates type rules before sending', () async {
      var requestSent = false;
      final client = MockClient((_) async {
        requestSent = true;
        return http.Response(_autocompleteJson, 200);
      });
      expect(
          () => _provider(client).fetchSuggestions('x', types: [
                AutoCompleteType.cities,
                AutoCompleteType.bookStore,
              ]),
          throwsException);
      expect(requestSent, isFalse);
    });
  });

  group('fetchSuggestions response parsing', () {
    test('parses placePredictions and skips queryPredictions', () async {
      final client =
          MockClient((_) async => http.Response(_autocompleteJson, 200));

      final suggestions = await _provider(client)
          .fetchSuggestions('678', types: [AutoCompleteType.address]);

      expect(suggestions, hasLength(1));
      expect(suggestions[0].placeId, 'ChIJiRzbkjrt0lQRVvD61FBwlmw');
      expect(suggestions[0].description,
          '678 North Market Street, Redding, CA, USA');
      expect(suggestions[0].mainText, isNull); // full details not requested
    });

    test('fills full details when requested; terms has no new-API equivalent',
        () async {
      final client =
          MockClient((_) async => http.Response(_autocompleteJson, 200));

      final suggestions = await _provider(client).fetchSuggestions('678',
          includeFullSuggestionDetails: true,
          types: [AutoCompleteType.address]);

      expect(suggestions[0].mainText, '678 North Market Street');
      expect(suggestions[0].secondaryText, 'Redding, CA, USA');
      expect(suggestions[0].types, ['premise', 'geocode']);
      expect(suggestions[0].terms, isNull);
    });

    test('returns empty list when response has no suggestions', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      expect(
          await _provider(client)
              .fetchSuggestions('zzz', types: [AutoCompleteType.address]),
          isEmpty);
    });

    test('throws with google error message on non-200', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 400,
              'message': 'Empty text_input.',
              'status': 'INVALID_ARGUMENT'
            }
          }),
          400));
      expect(
          () => _provider(client)
              .fetchSuggestions('x', types: [AutoCompleteType.address]),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Empty text_input.'))));
    });

    test('403 error message includes enable-API hint', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 403,
              'message': 'Requests to this API are blocked.',
              'status': 'PERMISSION_DENIED'
            }
          }),
          403));
      expect(
          () => _provider(client)
              .fetchSuggestions('x', types: [AutoCompleteType.address]),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Is "Places API (New)" enabled'))));
    });
  });

  group('getPlaceDetailFromId', () {
    test('GETs /v1/places/{id} with field mask and session token', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(_detailsJson, 200);
      });

      await _provider(client)
          .getPlaceDetailFromId('ChIJiRzbkjrt0lQRVvD61FBwlmw');

      expect(captured.method, 'GET');
      expect(captured.url.host, 'places.googleapis.com');
      expect(captured.url.path, '/v1/places/ChIJiRzbkjrt0lQRVvD61FBwlmw');
      expect(captured.url.queryParameters['sessionToken'], 'session-token-1');
      expect(captured.url.queryParameters['languageCode'], 'en-US');
      expect(captured.headers['X-Goog-Api-Key'], 'test-api-key');
      expect(captured.headers['X-Goog-FieldMask'],
          'id,displayName,formattedAddress,addressComponents,location');
    });

    test('parses Place identically to the legacy backend', () async {
      final client = MockClient((_) async => http.Response(_detailsJson, 200));

      final place = await _provider(client)
          .getPlaceDetailFromId('ChIJiRzbkjrt0lQRVvD61FBwlmw');

      expect(place.name, '6781 Eastside Rd');
      expect(
          place.formattedAddress, '6781 Eastside Rd, Anderson, CA 96007, USA');
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
      expect(place.zipCodePlus4, '96007-9406');
    });

    test('throws with google error message on non-200', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 404,
              'message': 'Place not found.',
              'status': 'NOT_FOUND'
            }
          }),
          404));
      expect(
          () => _provider(client).getPlaceDetailFromId('bogus'),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Place not found.'))));
    });
  });
}
