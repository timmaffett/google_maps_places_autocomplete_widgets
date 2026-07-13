import 'dart:convert';

import 'package:http/http.dart';

import '/api/autocomplete_types.dart';
import '/api/new_api_type_mapping.dart';
import '/api/place_api_provider.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

/// [PlaceApiProvider] backed by Places API (New)
/// (`https://places.googleapis.com/v1`). Plain REST over [Client], so it
/// works on every platform the `http` package supports.
///
/// Requires "Places API (New)" to be enabled for [mapsApiKey] in the Google
/// Cloud console.
///
/// For API keys with application restrictions, supply [androidPackageName] +
/// [androidCertSha1Fingerprint] (Android) or [iosBundleId] (iOS); they are
/// sent as the `X-Android-Package`/`X-Android-Cert`/`X-Ios-Bundle-Identifier`
/// headers Google validates against the key's registered apps.
class NewPlaceApiProvider extends PlaceApiProvider {
  NewPlaceApiProvider(
    this.sessionToken,
    this.mapsApiKey,
    this.componentCountry,
    this.language, {
    this.androidPackageName,
    this.androidCertSha1Fingerprint,
    this.iosBundleId,
    Client? client,
  }) : client = client ?? Client();

  final Client client;
  final String sessionToken;
  final String mapsApiKey;
  final String? componentCountry;
  final String? language;
  final String? androidPackageName;
  final String? androidCertSha1Fingerprint;
  final String? iosBundleId;

  static const String _host = 'places.googleapis.com';

  Map<String, String> _baseHeaders() => <String, String>{
        'X-Goog-Api-Key': mapsApiKey,
        if (androidPackageName != null)
          'X-Android-Package': androidPackageName!,
        if (androidCertSha1Fingerprint != null)
          'X-Android-Cert': androidCertSha1Fingerprint!,
        if (iosBundleId != null) 'X-Ios-Bundle-Identifier': iosBundleId!,
      };

  Never _throwApiError(Response response, String operation) {
    String message = 'Failed to $operation (HTTP ${response.statusCode})';
    try {
      final decoded = json.decode(response.body);
      final errorMessage = decoded['error']?['message'];
      if (errorMessage is String) message = errorMessage;
    } catch (_) {
      // Non-JSON error body: keep the default message.
    }
    if (response.statusCode == 403) {
      message =
          '$message (Is "Places API (New)" enabled for this API key in the Google Cloud console? https://console.cloud.google.com/apis/library/places.googleapis.com)';
    }
    throw Exception(message);
  }

  @override
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types}) async {
    validateAutocompleteTypes(types);

    final response = await client.post(
      Uri.https(_host, '/v1/places:autocomplete'),
      headers: {..._baseHeaders(), 'Content-Type': 'application/json'},
      body: json.encode(<String, dynamic>{
        'input': input,
        'sessionToken': sessionToken,
        if (language != null) 'languageCode': language,
        if (componentCountry != null)
          'includedRegionCodes': [componentCountry],
        'includedPrimaryTypes': mapTypesToNewApi(types),
      }),
    );

    if (response.statusCode != 200) {
      _throwApiError(response, 'fetch suggestions');
    }

    final result = json.decode(response.body) as Map<String, dynamic>;
    final suggestions = result['suggestions'] as List<dynamic>? ?? const [];
    final parsed = <Suggestion>[];
    for (final suggestion in suggestions) {
      final p = (suggestion as Map<String, dynamic>)['placePrediction'];
      // Entries carrying only a queryPrediction have no placePrediction;
      // we never request query predictions, but skip defensively.
      if (p is! Map<String, dynamic>) continue;

      final placeId = p['placeId'] as String;
      final description = (p['text']?['text'] as String?) ?? '';
      if (includeFullSuggestionDetails) {
        parsed.add(Suggestion(
          placeId,
          description,
          mainText: p['structuredFormat']?['mainText']?['text'] as String?,
          secondaryText:
              p['structuredFormat']?['secondaryText']?['text'] as String?,
          // The new API has no equivalent of the legacy `terms` list.
          terms: null,
          types: (p['types'] as List<dynamic>?)?.cast<String>(),
        ));
      } else {
        parsed.add(Suggestion(placeId, description));
      }
    }
    return parsed;
  }

  @override
  Future<Place> getPlaceDetailFromId(String placeId) async {
    throw UnimplementedError('implemented in the next commit');
  }
}
