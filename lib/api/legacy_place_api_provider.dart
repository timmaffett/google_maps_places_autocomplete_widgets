import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
import 'package:http/http.dart';

import '/api/place_api_provider.dart';
import '/api/place_builder.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

/* FOR DEBUGGING */
void printWrapped(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => debugPrint(match.group(0)));
}

void printJson(dynamic json, {String? title}) {
  JsonEncoder encoder = const JsonEncoder.withIndent('  ');

  // encode it to string
  String prettyPrint = encoder.convert(json);

  if (title != null) {
    debugPrint(title);
  }
  printWrapped(prettyPrint);
}

const bool debugJson = false;
/* END FOR DEBUGGING */

/// [PlaceApiProvider] backed by the legacy Places API
/// (`https://maps.googleapis.com/maps/api/place`).
///
/// Google set this API to legacy status on March 1, 2025 — it can no longer
/// be enabled on new Google Cloud projects but keeps working on projects
/// where it was already enabled. Select it with
/// `apiVersion: PlacesApiVersion.legacy`.
class LegacyPlaceApiProvider extends PlaceApiProvider {
  LegacyPlaceApiProvider(
      this.sessionToken, this.mapsApiKey, this.componentCountry, this.language,
      {Client? client})
      : client = client ?? Client();

  final Client client;
  final String sessionToken;
  final String mapsApiKey;
  final String? componentCountry;
  final String? language;

/* Example JSON returned from Places autocomplete suggestions API request
    (ie.
      host: 'maps.googleapis.com',
        path: '/maps/api/place/autocomplete/json', )
    request below

result["predictions"] =
[
  {
    "description": "678 North Market Street, Redding, CA, USA",
    "matched_substrings": [
      {
        "length": 3,
        "offset": 0
      }
    ],
    "place_id": "ChIJiRzbkjrt0lQRVvD61FBwlmw",
    "reference": "ChIJiRzbkjrt0lQRVvD61FBwlmw",
    "structured_formatting": {
      "main_text": "678 North Market Street",
      "main_text_matched_substrings": [
        {
          "length": 3,
          "offset": 0
        }
      ],
      "secondary_text": "Redding, CA, USA"
    },
    "terms": [
      {
        "offset": 0,
        "value": "678"
      },
      {
        "offset": 4,
        "value": "North Market Street"
      },
      {
        "offset": 25,
        "value": "Redding"
      },
      {
        "offset": 34,
        "value": "CA"
      },
      {
        "offset": 38,
        "value": "USA"
      }
    ],
    "types": [
      "premise",
      "geocode"
    ]
  },

  ... repeating the other suggestions in same format

]
*/
  ///[includeFullSuggestionDetails] if we should include ALL details that are returned in API suggestions.
  ///   (This is sent as true when the `onInitialSuggestionClick` is in use)
  ///[types] the autocomplete types to request from the API.
  @override
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types}) async {
    validateAutocompleteTypes(types);
    String typesString = '';
    for (final type in types) {
      if (typesString.isNotEmpty) typesString += '|';
      typesString += type.typeString;
    }

    final Map<String, dynamic> parameters = <String, dynamic>{
      'input': input,
      'types': typesString,
      'key': mapsApiKey,
      'sessiontoken': sessionToken
    };

    if (language != null) {
      parameters.addAll(<String, dynamic>{'language': language});
    }
    if (componentCountry != null) {
      parameters
          .addAll(<String, dynamic>{'components': 'country:$componentCountry'});
    }

    final Uri request = Uri(
        scheme: 'https',
        host: 'maps.googleapis.com',
        path: '/maps/api/place/autocomplete/json',
        queryParameters: parameters);

    final response = await client.get(request);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['status'] == 'OK') {
        if (debugJson) {
          printJson(result['predictions'],
              title: 'GOOGLE MAP API RETURN VALUE result["predictions"]');
        }

        // compose suggestions in a list
        return result['predictions'].map<Suggestion>((p) {
          if (includeFullSuggestionDetails) {
            // Package everything useful from API json
            final mainText = p['structured_formatting']?['main_text'];
            final secondaryText = p['structured_formatting']?['secondary_text'];
            final terms = p['terms']
                .map<String>((term) => term['value'] as String)
                .toList();
            final types =
                p['types'].map<String>((atype) => atype as String).toList();

            return Suggestion(p['place_id'], p['description'],
                mainText: mainText,
                secondaryText: secondaryText,
                terms: terms,
                types: types);
          } else {
            // just use the simple Suggestion parts we need
            return Suggestion(p['place_id'], p['description']);
          }
        }).toList();
      }
      if (result['status'] == 'ZERO_RESULTS') {
        return [];
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch suggestion');
    }
  }

  /* EXAMPLE JSON returned from Places Detail
     (ie.   host: 'maps.googleapis.com',
        path: '/maps/api/place/details/json',  )
    request below:

result["result"]
{
  "address_components": [
    {
      "long_name": "6781",
      "short_name": "6781",
      "types": [
        "street_number"
      ]
    },
    {
      "long_name": "Eastside Road",
      "short_name": "Eastside Rd",
      "types": [
        "route"
      ]
    },
    {
      "long_name": "Metz Road",
      "short_name": "Metz Road",
      "types": [
        "neighborhood",
        "political"
      ]
    },
    {
      "long_name": "Anderson",
      "short_name": "Anderson",
      "types": [
        "locality",
        "political"
      ]
    },
    {
      "long_name": "Shasta County",
      "short_name": "Shasta County",
      "types": [
        "administrative_area_level_2",
        "political"
      ]
    },
    {
      "long_name": "California",
      "short_name": "CA",
      "types": [
        "administrative_area_level_1",
        "political"
      ]
    },
    {
      "long_name": "United States",
      "short_name": "US",
      "types": [
        "country",
        "political"
      ]
    },
    {
      "long_name": "96007",
      "short_name": "96007",
      "types": [
        "postal_code"
      ]
    },
    {
      "long_name": "9406",
      "short_name": "9406",
      "types": [
        "postal_code_suffix"
      ]
    }
  ],
  "formatted_address": "6781 Eastside Rd, Anderson, CA 96007, USA",
  "geometry": {
    "location": {
      "lat": 40.4839756,
      "lng": -122.34802
    },
    "viewport": {
      "northeast": {
        "lat": 40.48515498029149,
        "lng": -122.3471568197085
      },
      "southwest": {
        "lat": 40.48245701970849,
        "lng": -122.3498547802915
      }
    }
  },
  "name": "6781 Eastside Rd"
}
  */
  ///Requests full address info from Google Places API for the specified
  ///[placeId] and returns a [Place] object returned info.
  @override
  Future<Place> getPlaceDetailFromId(String placeId) async {
    // if you want to get the details of the selected place by place_id
    final Map<String, dynamic> parameters = <String, dynamic>{
      'place_id': placeId,
      'fields': 'name,formatted_address,address_component,geometry',
      'key': mapsApiKey,
      'sessiontoken': sessionToken
    };
    final Uri request = Uri(
        scheme: 'https',
        host: 'maps.googleapis.com',
        path: '/maps/api/place/details/json',
        queryParameters: parameters);

    if (debugJson) {
      debugPrint(request.toString());
    }

    final response = await client.get(request);

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['status'] == 'OK') {
        if (debugJson) {
          printJson(result['result'],
              title: 'GOOGLE MAP API RETURN VALUE result["result"]');
        }
        final components =
            result['result']['address_components'] as List<dynamic>;
        return buildPlaceFromComponents(
          components: [
            for (final component in components)
              RawAddressComponent(
                types: (component['types'] as List<dynamic>).cast<String>(),
                longText: component['long_name'] as String?,
                shortText: component['short_name'] as String?,
              ),
          ],
          name: result['result']['name'] as String?,
          formattedAddress: result['result']['formatted_address'] as String?,
          lat: result['result']['geometry']['location']['lat'] as double,
          lng: result['result']['geometry']['location']['lng'] as double,
        );
      }
      throw Exception(result['error_message']);
    } else {
      throw Exception('Failed to fetch suggestion');
    }
  }
}
