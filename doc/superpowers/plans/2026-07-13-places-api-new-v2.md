# Places API (New) v2.0.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Places API (New) as the default backend of `google_maps_places_autocomplete_widgets` v2.0.0, with a legacy opt-out, an injectable `PlaceApiProvider` abstraction, and app-restriction header support — while keeping the public widget API unchanged.

**Architecture:** All Google-facing code currently lives in one concrete class (`PlaceApiProvider`) behind `AddressService`. We split it into an abstract `PlaceApiProvider` contract with two built-in implementations (`LegacyPlaceApiProvider` = current code moved, `NewPlaceApiProvider` = new REST backend), selected by a `PlacesApiVersion` widget parameter or overridden entirely by an injected provider. Shared `Place`-building logic is extracted so both backends produce identical derived fields.

**Tech Stack:** Flutter/Dart 3 (SDK `>=3.0.0 <4.0.0`), `http` ^1.1.0 (includes `package:http/testing.dart` `MockClient` — no new dependencies), `uuid`, `flutter_test`.

**Spec:** `doc/superpowers/specs/2026-07-13-places-api-new-design.md` — read it first.

## Global Constraints

- Pure Dart package: NO platform folders, NO new dependencies. `pubspec.yaml` deps stay exactly: `flutter`, `uuid: ^4.2.1`, `http: ^1.1.0`; dev: `flutter_test`, `flutter_lints: ^5.0.0`.
- SDK constraint stays `">=3.0.0 <4.0.0"` (Dart 3 features like switch expressions are allowed).
- Public widget API is backward compatible EXCEPT: new optional params, default backend becomes Places API (New), and `Suggestion.terms` is `null` on the new backend. Never rename the public `componentCountry` widget param. The internal misspelled field `compomentCountry` SHOULD be fixed to `componentCountry` during the move.
- Exact names (used across tasks): `enum PlacesApiVersion { placesApiNew, legacy }`; widget/service params `apiVersion`, `placeApiProvider`, `androidPackageName`, `androidCertSha1Fingerprint`, `iosBundleId`.
- Exact endpoints: `POST https://places.googleapis.com/v1/places:autocomplete`; `GET https://places.googleapis.com/v1/places/{placeId}`; details field mask string: `id,displayName,formattedAddress,addressComponents,location`.
- Every task ends with `flutter analyze` reporting "No issues found!" and `flutter test` green, then a commit.
- Version bump to 2.0.0 happens ONLY in the final task.
- Run all commands from the repo root: `C:\src\google_maps_places_autocomplete_widgets`.

## File Structure (end state)

```
lib/api/place_api_provider.dart        abstract PlaceApiProvider (public contract)   [Task 2]
lib/api/legacy_place_api_provider.dart LegacyPlaceApiProvider (current code, moved)  [Task 2]
lib/api/new_place_api_provider.dart    NewPlaceApiProvider (Places API New REST)     [Tasks 4-5]
lib/api/places_api_version.dart        enum PlacesApiVersion                         [Task 2]
lib/api/place_builder.dart             RawAddressComponent + buildPlaceFromComponents [Task 1]
lib/api/new_api_type_mapping.dart      AutoCompleteType -> includedPrimaryTypes      [Task 3]
lib/api/autocomplete_types.dart        + validateAutocompleteTypes()                 [Task 2]
lib/service/address_service.dart       selects/accepts provider                      [Task 6]
lib/widgets/*.dart                     new params, debugPrint cleanup                [Task 6]
lib/address_autocomplete_widgets.dart  + exports                                     [Task 6]
example/lib/main.dart                  apiVersion toggle                             [Task 7]
test/place_builder_test.dart                                                         [Task 1]
test/legacy_place_api_provider_test.dart                                             [Task 2]
test/new_api_type_mapping_test.dart                                                  [Task 3]
test/new_place_api_provider_test.dart                                                [Tasks 4-5]
test/widget_injectable_provider_test.dart                                            [Task 6]
README.md, MIGRATION.md, CHANGELOG.md, pubspec.yaml                                  [Task 8]
```

---

### Task 1: Shared Place builder

Extract the address-component → `Place` logic (currently inlined in `PlaceApiProvider.getPlaceDetailFromId`, `lib/api/place_api_provider.dart:322-379`) into a shared, wire-format-agnostic helper so both backends produce identical derived fields (`zipCodePlus4`, synthesized `streetAddress`/`formattedAddress`/`formattedAddressZipPlus4`).

**Files:**
- Create: `lib/api/place_builder.dart`
- Test: `test/place_builder_test.dart`

**Interfaces:**
- Consumes: `Place` from `lib/model/place.dart` (existing).
- Produces (used by Tasks 2 and 5):
  - `class RawAddressComponent { final List<String> types; final String? longText; final String? shortText; const RawAddressComponent({required this.types, this.longText, this.shortText}); }`
  - `Place buildPlaceFromComponents({required List<RawAddressComponent> components, String? name, String? formattedAddress, double? lat, double? lng})`

- [ ] **Step 1: Write the failing test**

Create `test/place_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/api/place_builder.dart';

void main() {
  // Components mirroring the real captured JSON documented in
  // lib/api/place_api_provider.dart (6781 Eastside Rd, Anderson, CA).
  final components = [
    const RawAddressComponent(
        types: ['street_number'], longText: '6781', shortText: '6781'),
    const RawAddressComponent(
        types: ['route'], longText: 'Eastside Road', shortText: 'Eastside Rd'),
    const RawAddressComponent(
        types: ['locality', 'political'],
        longText: 'Anderson',
        shortText: 'Anderson'),
    const RawAddressComponent(
        types: ['administrative_area_level_2', 'political'],
        longText: 'Shasta County',
        shortText: 'Shasta County'),
    const RawAddressComponent(
        types: ['administrative_area_level_1', 'political'],
        longText: 'California',
        shortText: 'CA'),
    const RawAddressComponent(
        types: ['country', 'political'],
        longText: 'United States',
        shortText: 'US'),
    const RawAddressComponent(
        types: ['postal_code'], longText: '96007', shortText: '96007'),
    const RawAddressComponent(
        types: ['postal_code_suffix'], longText: '9406', shortText: '9406'),
  ];

  test('maps all component types to Place fields', () {
    final place = buildPlaceFromComponents(
      components: components,
      name: '6781 Eastside Rd',
      formattedAddress: '6781 Eastside Rd, Anderson, CA 96007, USA',
      lat: 40.4839756,
      lng: -122.34802,
    );

    expect(place.name, '6781 Eastside Rd');
    expect(place.formattedAddress, '6781 Eastside Rd, Anderson, CA 96007, USA');
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
  });

  test('derives zipCodePlus4 and synthesized street/formatted addresses', () {
    final place = buildPlaceFromComponents(components: components);

    expect(place.zipCodePlus4, '96007-9406');
    expect(place.streetAddress, '6781 Eastside Rd');
    expect(place.formattedAddress, '6781 Eastside Rd, Anderson, CA 96007');
    expect(place.formattedAddressZipPlus4, '6781 Eastside Rd, Anderson, CA 96007-9406');
  });

  test('zipCodePlus4 has no suffix part when postal_code_suffix missing', () {
    final place = buildPlaceFromComponents(
      components: components
          .where((c) => !c.types.contains('postal_code_suffix'))
          .toList(),
    );
    expect(place.zipCodePlus4, '96007');
  });

  test('does not synthesize addresses without a street_number', () {
    final place = buildPlaceFromComponents(
      components: components
          .where((c) => !c.types.contains('street_number'))
          .toList(),
    );
    expect(place.streetAddress, isNull);
    expect(place.formattedAddress, isNull);
    expect(place.formattedAddressZipPlus4, isNull);
  });

  test('maps sublocality to vicinity', () {
    final place = buildPlaceFromComponents(components: [
      const RawAddressComponent(
          types: ['sublocality_level_1', 'sublocality', 'political'],
          longText: 'Brooklyn',
          shortText: 'Brooklyn'),
    ]);
    expect(place.vicinity, 'Brooklyn');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/place_builder_test.dart`
Expected: FAIL — compilation error, `place_builder.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/api/place_builder.dart`. The mapping and derived-field logic is copied EXACTLY from `lib/api/place_api_provider.dart:322-379` (preserve behavior verbatim, including the `zipCodePlus4` string interpolation quirks):

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/place_builder_test.dart`
Expected: PASS (5 tests). Also run: `flutter analyze` — expected "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/api/place_builder.dart test/place_builder_test.dart
git commit -m "refactor: extract shared Place builder for use by both API backends"
```

---

### Task 2: Provider abstraction + LegacyPlaceApiProvider

Turn `PlaceApiProvider` into an abstract public contract; move the existing implementation to `LegacyPlaceApiProvider` with an injectable `http.Client`; add the `PlacesApiVersion` enum and a shared `validateAutocompleteTypes()`. Behavior must not change.

**Files:**
- Create: `lib/api/legacy_place_api_provider.dart` (code moved from `place_api_provider.dart`)
- Create: `lib/api/places_api_version.dart`
- Rewrite: `lib/api/place_api_provider.dart` (becomes the abstract class only)
- Modify: `lib/api/autocomplete_types.dart` (append `validateAutocompleteTypes`)
- Modify: `lib/service/address_service.dart` (construct `LegacyPlaceApiProvider`; type field as abstract `PlaceApiProvider`)
- Delete: `test/google_maps_places_autocomplete_widgets_test.dart` (empty scaffold, tests nothing)
- Test: `test/legacy_place_api_provider_test.dart`

**Interfaces:**
- Consumes: `RawAddressComponent`, `buildPlaceFromComponents` (Task 1); existing `Suggestion`, `Place`, `AutoCompleteType`.
- Produces (relied on by Tasks 3-6):
  - `abstract class PlaceApiProvider { Future<List<Suggestion>> fetchSuggestions(String input, {bool includeFullSuggestionDetails = false, required List<AutoCompleteType> types}); Future<Place> getPlaceDetailFromId(String placeId); }`
  - `class LegacyPlaceApiProvider extends PlaceApiProvider` with constructor `LegacyPlaceApiProvider(String sessionToken, String mapsApiKey, String? componentCountry, String? language, {Client? client})`
  - `enum PlacesApiVersion { placesApiNew, legacy }`
  - `void validateAutocompleteTypes(List<AutoCompleteType> types)` in `autocomplete_types.dart` — throws `Exception` (same messages as today).

- [ ] **Step 1: Write the failing tests**

Create `test/legacy_place_api_provider_test.dart`:

```dart
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
      expect(
          suggestions[0].description, '678 North Market Street, Redding, CA, USA');
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
      expect(place.formattedAddress, '6781 Eastside Rd, Anderson, CA 96007, USA');
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/legacy_place_api_provider_test.dart`
Expected: FAIL — compilation error, `legacy_place_api_provider.dart` does not exist.

- [ ] **Step 3: Add `validateAutocompleteTypes` to `lib/api/autocomplete_types.dart`**

Append at the end of the file (after the enum's closing `}`):

```dart
/// Validates the Google Places rules shared by both API backends:
/// a maximum of 5 type values, and "single only" values (collections such
/// as `(cities)`/`(regions)` and the legacy `address`/`geocode`/
/// `establishment` filters) must not be combined with any other value.
/// Throws [Exception] on violation (same behavior/messages as v1.x).
void validateAutocompleteTypes(List<AutoCompleteType> types) {
  for (final type in types) {
    if (type.onlySingleValueAllowed && types.length > 1) {
      throw Exception(
          'If $type is specified then it is the ONLY autocomplete type allowed by Google Places. See https://developers.google.com/maps/documentation/places/web-service/autocomplete#types');
    }
  }
  if (types.length > 5) {
    throw Exception(
        'A maximum of 5 autocomplete types are allowed by Google Places. See https://developers.google.com/maps/documentation/places/web-service/autocomplete#types');
  }
}
```

- [ ] **Step 4: Create `lib/api/places_api_version.dart`**

```dart
/// Selects which Google Places backend the autocomplete widgets use.
enum PlacesApiVersion {
  /// Places API (New) — `https://places.googleapis.com/v1`. The default.
  /// Requires "Places API (New)" to be enabled for your API key in the
  /// Google Cloud console.
  placesApiNew,

  /// The legacy Places API — `https://maps.googleapis.com/maps/api/place`.
  /// Google set this API to legacy status on March 1, 2025: it can no longer
  /// be enabled on new Google Cloud projects, but keeps working on projects
  /// where it was already enabled.
  legacy,
}
```

- [ ] **Step 5: Create `lib/api/legacy_place_api_provider.dart`**

Move the ENTIRE current content of `lib/api/place_api_provider.dart` here, then apply exactly these changes (everything else stays verbatim, including the captured-JSON comment blocks):

1. Rename class `PlaceApiProvider` → `LegacyPlaceApiProvider extends PlaceApiProvider`, add imports `import '/api/place_api_provider.dart';` and `import '/api/place_builder.dart';`, and change `import 'package:flutter/material.dart';` → `import 'package:flutter/foundation.dart';` (only `debugPrint` is used).
2. Constructor and fields — injectable client, typo fix:

```dart
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
```

   (Update the two usages of the old `compomentCountry` field inside `fetchSuggestions` accordingly.)
3. Add `@override` to `fetchSuggestions` and `getPlaceDetailFromId`.
4. In `fetchSuggestions`, replace the inline validation (the `if (type.onlySingleValueAllowed ...)` block inside the loop and the trailing `if (types.length > 5)` block) with a single call at the top: `validateAutocompleteTypes(types);` — keep the `typesString` building loop:

```dart
    validateAutocompleteTypes(types);
    String typesString = '';
    for (final type in types) {
      if (typesString.isNotEmpty) typesString += '|';
      typesString += type.typeString;
    }
```

5. In `getPlaceDetailFromId`, replace everything from `final components = ...` down to (and including) the derived-fields block and `return place;` with:

```dart
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
```

   Also delete the now-dead `//PlaceApiNew` breadcrumb comments (the real new provider arrives in Task 4).

- [ ] **Step 6: Rewrite `lib/api/place_api_provider.dart` as the abstract contract**

Replace the file's entire content with:

```dart
import '/api/autocomplete_types.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

/// The contract for a Google Places backend used by the autocomplete widgets.
///
/// Two implementations are built in: `LegacyPlaceApiProvider` (legacy Places
/// API) and `NewPlaceApiProvider` (Places API (New)), selected by the
/// widgets' `apiVersion` parameter. Supply your own implementation via the
/// widgets' `placeApiProvider` parameter to use a different backend entirely
/// (a native Places SDK wrapper, a backend proxy that holds your API key
/// server side, or a test fake).
///
/// Implementations must:
///  - return an empty list from [fetchSuggestions] when there are no results
///    (never throw for "no matches");
///  - throw an [Exception] with a human-readable message on API errors;
///  - honor Google billing-session semantics: all [fetchSuggestions] calls
///    for one user interaction share a session token, and
///    [getPlaceDetailFromId] terminates that session.
abstract class PlaceApiProvider {
  /// Returns autocomplete suggestions for [input], restricted to [types].
  ///
  /// [includeFullSuggestionDetails] asks for [Suggestion.mainText],
  /// [Suggestion.secondaryText], [Suggestion.terms] and [Suggestion.types]
  /// to be populated when the backend can supply them. (It is set when the
  /// widget's `onInitialSuggestionClick` callback is in use.)
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types});

  /// Returns full address details for the suggestion with [placeId].
  Future<Place> getPlaceDetailFromId(String placeId);
}
```

- [ ] **Step 7: Update `lib/service/address_service.dart`**

Replace the import and construction so behavior is unchanged (legacy still used — the switch to a default of new happens in Task 6):

```dart
import '/api/legacy_place_api_provider.dart';
import '/api/place_api_provider.dart';
import '/api/autocomplete_types.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

class AddressService {
  AddressService(this.sessionToken, this.mapsApiKey, this.componentCountry,
      this.language) {
    apiClient = LegacyPlaceApiProvider(
        sessionToken, mapsApiKey, componentCountry, language);
  }

  final String sessionToken;
  final String mapsApiKey;
  final String? componentCountry;
  final String? language;
  late PlaceApiProvider apiClient;

  Future<List<Suggestion>> search(String query,
      {bool includeFullSuggestionDetails = false,
      List<AutoCompleteType> types = const [AutoCompleteType.address]}) async {
    return await apiClient.fetchSuggestions(query,
        includeFullSuggestionDetails: includeFullSuggestionDetails,
        types: types);
  }

  Future<Place> getPlaceDetail(String placeId) async {
    Place placeDetails = await apiClient.getPlaceDetailFromId(placeId);
    return placeDetails;
  }
}
```

Also delete the empty scaffold test: `test/google_maps_places_autocomplete_widgets_test.dart`.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test`
Expected: PASS (Task 1's 5 tests + this task's 9 tests).
Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: abstract PlaceApiProvider contract with LegacyPlaceApiProvider implementation"
```

---

### Task 3: New-API type mapping

Map `AutoCompleteType` values to the new API's `includedPrimaryTypes`. Research result (2026-07-13, place-types doc): every legacy type string in the enum exists in new Table A/B EXCEPT `address`, and `(cities)`/`(regions)` remain valid — so the mapping is identity plus one override. (If Google ever rejects a type at runtime, the provider's descriptive error handling from Task 4 covers it.)

**Files:**
- Create: `lib/api/new_api_type_mapping.dart`
- Test: `test/new_api_type_mapping_test.dart`

**Interfaces:**
- Consumes: `AutoCompleteType` (existing).
- Produces (used by Task 4):
  - `const Map<AutoCompleteType, List<String>> kNewApiTypeOverrides`
  - `List<String> mapTypesToNewApi(List<AutoCompleteType> types)`

- [ ] **Step 1: Write the failing test**

Create `test/new_api_type_mapping_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/new_api_type_mapping_test.dart`
Expected: FAIL — compilation error, `new_api_type_mapping.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/api/new_api_type_mapping.dart`:

```dart
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
    for (final type in types) ...kNewApiTypeOverrides[type] ?? [type.typeString],
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/new_api_type_mapping_test.dart`
Expected: PASS (2 tests). Also `flutter analyze` — "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/api/new_api_type_mapping.dart test/new_api_type_mapping_test.dart
git commit -m "feat: map AutoCompleteType values to Places API (New) includedPrimaryTypes"
```

---

### Task 4: NewPlaceApiProvider — autocomplete

The Places API (New) suggestions call: `POST https://places.googleapis.com/v1/places:autocomplete` with the key in `X-Goog-Api-Key`, optional app-restriction headers, and a JSON body.

**Files:**
- Create: `lib/api/new_place_api_provider.dart`
- Test: `test/new_place_api_provider_test.dart`

**Interfaces:**
- Consumes: `PlaceApiProvider` (Task 2), `validateAutocompleteTypes` (Task 2), `mapTypesToNewApi` (Task 3), `Suggestion` (existing).
- Produces (used by Tasks 5-6): `class NewPlaceApiProvider extends PlaceApiProvider` with constructor `NewPlaceApiProvider(String sessionToken, String mapsApiKey, String? componentCountry, String? language, {String? androidPackageName, String? androidCertSha1Fingerprint, String? iosBundleId, Client? client})`.

- [ ] **Step 1: Write the failing tests**

Create `test/new_place_api_provider_test.dart`:

```dart
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
      expect(captured2.headers.containsKey('X-Ios-Bundle-Identifier'), isFalse);
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/new_place_api_provider_test.dart`
Expected: FAIL — compilation error, `new_place_api_provider.dart` does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/api/new_place_api_provider.dart` (the `getPlaceDetailFromId` body is completed in Task 5; here it throws `UnimplementedError`):

```dart
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
        if (componentCountry != null) 'includedRegionCodes': [componentCountry],
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/new_place_api_provider_test.dart`
Expected: PASS (9 tests). Also `flutter analyze` — "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/api/new_place_api_provider.dart test/new_place_api_provider_test.dart
git commit -m "feat: NewPlaceApiProvider autocomplete via Places API (New) REST"
```

---

### Task 5: NewPlaceApiProvider — place details

`GET https://places.googleapis.com/v1/places/{placeId}` with the field mask header; parse into `Place` via the shared builder. Passing the session token terminates the billing session (matching legacy behavior).

**Files:**
- Modify: `lib/api/new_place_api_provider.dart` (replace the `UnimplementedError` body)
- Test: `test/new_place_api_provider_test.dart` (append a group)

**Interfaces:**
- Consumes: `RawAddressComponent`, `buildPlaceFromComponents` (Task 1).
- Produces: completed `NewPlaceApiProvider.getPlaceDetailFromId(String placeId) -> Future<Place>`.

- [ ] **Step 1: Write the failing tests**

Append to `test/new_place_api_provider_test.dart` (inside `main()`, after the existing groups) — and add this constant next to `_autocompleteJson`:

```dart
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
```

```dart
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
      expect(place.formattedAddress, '6781 Eastside Rd, Anderson, CA 96007, USA');
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/new_place_api_provider_test.dart`
Expected: FAIL — the three new tests fail with `UnimplementedError`.

- [ ] **Step 3: Write the implementation**

In `lib/api/new_place_api_provider.dart`, add `import '/api/place_builder.dart';` and replace the `getPlaceDetailFromId` body:

```dart
  @override
  Future<Place> getPlaceDetailFromId(String placeId) async {
    // Passing the session token here terminates the autocomplete billing
    // session, exactly as the legacy `sessiontoken` param did.
    final response = await client.get(
      Uri.https(_host, '/v1/places/$placeId', <String, String>{
        'sessionToken': sessionToken,
        if (language != null) 'languageCode': language!,
      }),
      headers: {
        ..._baseHeaders(),
        'X-Goog-FieldMask':
            'id,displayName,formattedAddress,addressComponents,location',
      },
    );

    if (response.statusCode != 200) {
      _throwApiError(response, 'fetch place details');
    }

    final result = json.decode(response.body) as Map<String, dynamic>;
    return buildPlaceFromComponents(
      components: [
        for (final component
            in result['addressComponents'] as List<dynamic>? ?? const [])
          RawAddressComponent(
            types: ((component as Map<String, dynamic>)['types']
                        as List<dynamic>? ??
                    const [])
                .cast<String>(),
            longText: component['longText'] as String?,
            shortText: component['shortText'] as String?,
          ),
      ],
      name: result['displayName']?['text'] as String?,
      formattedAddress: result['formattedAddress'] as String?,
      lat: (result['location']?['latitude'] as num?)?.toDouble(),
      lng: (result['location']?['longitude'] as num?)?.toDouble(),
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test`
Expected: PASS (all suites). Also `flutter analyze` — "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/api/new_place_api_provider.dart test/new_place_api_provider_test.dart
git commit -m "feat: NewPlaceApiProvider place details via Places API (New) REST"
```

---

### Task 6: Wire into AddressService, widgets, and public exports

Make Places API (New) the default, add the five new widget parameters, export the public abstractions, and delete the stray `debugPrint` noise. This is the release's only behavior change for existing users.

**Files:**
- Modify: `lib/service/address_service.dart`
- Modify: `lib/widgets/address_autocomplete_generic.dart`
- Modify: `lib/widgets/address_autocomplete_textfield.dart`
- Modify: `lib/widgets/address_autocomplete_textformfield.dart`
- Modify: `lib/address_autocomplete_widgets.dart`
- Test: `test/widget_injectable_provider_test.dart`

**Interfaces:**
- Consumes: everything produced by Tasks 2-5.
- Produces (relied on by Tasks 7-8): widget params `apiVersion` (default `PlacesApiVersion.placesApiNew`), `placeApiProvider`, `androidPackageName`, `androidCertSha1Fingerprint`, `iosBundleId` on BOTH widgets; barrel exports of `PlaceApiProvider` and `PlacesApiVersion`.

- [ ] **Step 1: Write the failing widget test**

Create `test/widget_injectable_provider_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
import 'package:google_maps_places_autocomplete_widgets/api/place_api_provider.dart';

class FakePlaceApiProvider extends PlaceApiProvider {
  final List<String> suggestionQueries = [];
  final List<String> detailRequests = [];

  @override
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types}) async {
    suggestionQueries.add(input);
    return [Suggestion('fake-place-id', '123 Fake Street, Springfield')];
  }

  @override
  Future<Place> getPlaceDetailFromId(String placeId) async {
    detailRequests.add(placeId);
    return Place(
        formattedAddress: '123 Fake Street, Springfield',
        city: 'Springfield');
  }
}

void main() {
  testWidgets(
      'injected placeApiProvider drives suggestions and selection end-to-end',
      (tester) async {
    final fake = FakePlaceApiProvider();
    Place? clickedPlace;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressAutocompleteTextField(
          mapsApiKey: 'unused-because-provider-injected',
          placeApiProvider: fake,
          debounceTime: 20,
          onSuggestionClick: (place) => clickedPlace = place,
        ),
      ),
    ));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123');
    // let the debounce timer fire and the fake future resolve
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(fake.suggestionQueries, ['123']);
    expect(find.text('123 Fake Street, Springfield'), findsOneWidget);

    await tester.tap(find.text('123 Fake Street, Springfield'));
    await tester.pumpAndSettle();

    expect(fake.detailRequests, ['fake-place-id']);
    expect(clickedPlace?.city, 'Springfield');
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '123 Fake Street, Springfield');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_injectable_provider_test.dart`
Expected: FAIL — compilation error: no `placeApiProvider` parameter on `AddressAutocompleteTextField`.

- [ ] **Step 3: Update `lib/service/address_service.dart`**

Replace the constructor and imports (keep `search`/`getPlaceDetail` as-is):

```dart
import '/api/legacy_place_api_provider.dart';
import '/api/new_place_api_provider.dart';
import '/api/place_api_provider.dart';
import '/api/places_api_version.dart';
import '/api/autocomplete_types.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

class AddressService {
  AddressService(
    this.sessionToken,
    this.mapsApiKey,
    this.componentCountry,
    this.language, {
    PlacesApiVersion apiVersion = PlacesApiVersion.placesApiNew,
    PlaceApiProvider? placeApiProvider,
    String? androidPackageName,
    String? androidCertSha1Fingerprint,
    String? iosBundleId,
  }) {
    apiClient = placeApiProvider ??
        switch (apiVersion) {
          PlacesApiVersion.legacy => LegacyPlaceApiProvider(
              sessionToken, mapsApiKey, componentCountry, language),
          PlacesApiVersion.placesApiNew => NewPlaceApiProvider(
              sessionToken, mapsApiKey, componentCountry, language,
              androidPackageName: androidPackageName,
              androidCertSha1Fingerprint: androidCertSha1Fingerprint,
              iosBundleId: iosBundleId),
        };
  }

  final String sessionToken;
  final String mapsApiKey;
  final String? componentCountry;
  final String? language;
  late PlaceApiProvider apiClient;
```

- [ ] **Step 4: Update `lib/widgets/address_autocomplete_generic.dart`**

1. Add imports:

```dart
import '/api/place_api_provider.dart';
import '/api/places_api_version.dart';
```

2. In `AddresssAutocompleteStatefulWidget`, after the `abstract final String mapsApiKey;` declaration, add:

```dart
  /// Which Google Places backend to use. Defaults to
  /// [PlacesApiVersion.placesApiNew]; pass [PlacesApiVersion.legacy] to keep
  /// using the legacy Places API on Google Cloud projects where it is still
  /// enabled. Ignored when [placeApiProvider] is supplied.
  abstract final PlacesApiVersion apiVersion;

  /// Optional custom backend (native SDK wrapper, backend proxy, test fake).
  /// When supplied, [apiVersion], [mapsApiKey] and the built-in providers are
  /// not used for API calls.
  abstract final PlaceApiProvider? placeApiProvider;

  /// Optional — your Android applicationId, sent as the `X-Android-Package`
  /// header so Android-app-restricted API keys work. Use together with
  /// [androidCertSha1Fingerprint].
  abstract final String? androidPackageName;

  /// Optional — the SHA-1 signing-certificate fingerprint registered for
  /// your Android app in the Google Cloud console, sent as `X-Android-Cert`.
  abstract final String? androidCertSha1Fingerprint;

  /// Optional — your iOS bundle identifier, sent as
  /// `X-Ios-Bundle-Identifier` so iOS-app-restricted API keys work.
  abstract final String? iosBundleId;
```

3. In `SuggestionOverlayMixin.initState()`, replace the `AddressService(...)` construction with:

```dart
    addressService = AddressService(
      sessionToken,
      widget.mapsApiKey,
      widget.componentCountry,
      widget.language,
      apiVersion: widget.apiVersion,
      placeApiProvider: widget.placeApiProvider,
      androidPackageName: widget.androidPackageName,
      androidCertSha1Fingerprint: widget.androidCertSha1Fingerprint,
      iosBundleId: widget.iosBundleId,
    );
```

4. Delete the three stray debug lines: `debugPrint('SuggestionOverlayMixin init() called!!!!');` (in `initState`), `debugPrint('SuggestionOverlayMixin dispose() called!!!!');` (in `dispose`), and the `debugPrint('hideOverlay suggestionHasBeenSelected=...');` line (in `hideOverlay`).

- [ ] **Step 5: Update both concrete widgets**

In `lib/widgets/address_autocomplete_textfield.dart` AND `lib/widgets/address_autocomplete_textformfield.dart`:

1. Add the same two imports as in step 4.
2. After the `final String mapsApiKey;` field, add:

```dart
  @override
  final PlacesApiVersion apiVersion;

  @override
  final PlaceApiProvider? placeApiProvider;

  @override
  final String? androidPackageName;

  @override
  final String? androidCertSha1Fingerprint;

  @override
  final String? iosBundleId;
```

3. In each constructor's parameter list, directly after `required this.mapsApiKey,`, add:

```dart
    this.apiVersion = PlacesApiVersion.placesApiNew,
    this.placeApiProvider,
    this.androidPackageName,
    this.androidCertSha1Fingerprint,
    this.iosBundleId,
```

- [ ] **Step 6: Export the public abstractions**

In `lib/address_autocomplete_widgets.dart`, add after the existing exports:

```dart
export 'package:google_maps_places_autocomplete_widgets/api/place_api_provider.dart';
export 'package:google_maps_places_autocomplete_widgets/api/places_api_version.dart';
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test`
Expected: PASS (all suites, including the new widget test).
Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat!: Places API (New) is the default backend; add apiVersion, placeApiProvider and app-restriction params"
```

---

### Task 7: Example app backend toggle

Let the demo app switch backends at runtime so both paths are easy to smoke-test with a real key.

**Files:**
- Modify: `example/lib/main.dart`

**Interfaces:**
- Consumes: `PlacesApiVersion`, widget `apiVersion` param (Task 6; both re-exported by the barrel import already present in the example).

Note: the widgets create their `AddressService` in `initState`, so changing `apiVersion` alone would not take effect on an existing widget — each autocomplete widget must get a `ValueKey` that includes the version so the toggle recreates it.

- [ ] **Step 1: Add the toggle state and switch**

In `_AddressAutocompleteTextFieldExampleState` (example/lib/main.dart, class starting near line 59), add a field at the top of the class:

```dart
  PlacesApiVersion _apiVersion = PlacesApiVersion.placesApiNew;
```

In its `build()`, insert as the FIRST child of the `Column` (before the `const Text('Example of ZipCode/Postal Code lookup:')` row):

```dart
              SwitchListTile(
                title: Text(_apiVersion == PlacesApiVersion.placesApiNew
                    ? 'Using Places API (New)'
                    : 'Using legacy Places API'),
                subtitle: const Text(
                    'Toggle which Google Places backend the widgets below use'),
                value: _apiVersion == PlacesApiVersion.placesApiNew,
                onChanged: (useNew) => setState(() => _apiVersion = useNew
                    ? PlacesApiVersion.placesApiNew
                    : PlacesApiVersion.legacy),
              ),
```

- [ ] **Step 2: Pass the version (and a recreate key) to all four example widgets**

To EACH of the four `AddressAutocompleteTextField(...)` constructor calls in this file (zip lookup, cities, establishment, address), add as the first arguments (using a unique prefix per widget: `'zip'`, `'cities'`, `'establishment'`, `'address'`):

```dart
                  key: ValueKey('zip-$_apiVersion'),
                  apiVersion: _apiVersion,
```

In the `AddressAutocompleteTextFormField(...)` call inside `_AddressAutocompleteTextFormFieldExampleState.build()`, add one line after `mapsApiKey: ...,` (this tab keeps the default new backend; the line documents the param):

```dart
                  apiVersion: PlacesApiVersion.placesApiNew,
```

- [ ] **Step 3: Verify it builds and analyzes**

Run: `flutter analyze` (from repo root — covers the example too)
Expected: "No issues found!"
Run: `flutter test`
Expected: PASS.

(Manual smoke test with a real key in `example/lib/privatekeys.dart` happens in Task 8's checklist.)

- [ ] **Step 4: Commit**

```bash
git add example/lib/main.dart
git commit -m "docs(example): add runtime toggle between legacy and new Places API backends"
```

---

### Task 8: Docs, changelog, and 2.0.0 release prep

**Files:**
- Create: `MIGRATION.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md` (prepend entry)
- Modify: `pubspec.yaml` (version only)

- [ ] **Step 1: Create `MIGRATION.md`**

```markdown
# Migrating to 2.0.0 (Places API (New))

Google set the legacy Places API to legacy status on March 1, 2025 — it can no
longer be enabled on new Google Cloud projects. Version 2.0.0 of this package
therefore uses **Places API (New)** by default. For most apps migration is:

1. Enable **"Places API (New)"** for your project in the
   [Google Cloud console](https://console.cloud.google.com/apis/library/places.googleapis.com)
   (your existing API key can be used once the API is enabled for its project —
   check the key's **API restrictions** include Places API (New) if you use them).
2. Upgrade the package to `^2.0.0`.

No code changes are required. All widget parameters, callbacks, and the
`Place`/`Suggestion` models are unchanged.

## Staying on the legacy API temporarily

If your project still has the legacy Places API enabled and you are not ready
to switch, pass:

```dart
AddressAutocompleteTextField(
  mapsApiKey: '...',
  apiVersion: PlacesApiVersion.legacy,
  ...
)
```

or pin the package to `^1.3.0`. Note Google has committed to at least 12
months notice before turning the legacy API off, but no new features.

## Behavior differences on the new backend

- `Suggestion.terms` is always `null` — the new API has no equivalent field.
- The default address filter is translated: the legacy `types=address` filter
  does not exist in the new API, so `AutoCompleteType.address` (the default)
  is sent as `includedPrimaryTypes: [street_address, premise, subpremise]`.
  If you prefer broader geocoding matches, use `type: AutoCompleteType.geocode`.
- All other `AutoCompleteType` values are passed through with the same type
  string. `type`/`types` rules (max 5, collections alone) are unchanged.
- Error message text now comes from the new API's error format.

## Securing your API key (new capability)

Places API (New) honors **application-restricted** API keys over REST. If your
key is restricted to your Android or iOS app in the Cloud console, supply:

```dart
AddressAutocompleteTextField(
  mapsApiKey: '...',
  androidPackageName: 'com.example.myapp',        // X-Android-Package
  androidCertSha1Fingerprint: 'AA:BB:...:99',     // X-Android-Cert
  iosBundleId: 'com.example.myapp',               // X-Ios-Bundle-Identifier
  ...
)
```

Honest security note: these values are public information, so they deter
key-scraping and accidental reuse rather than determined attackers. Pair them
with API restrictions and quota caps. For cryptographic app attestation
(Firebase App Check) you need Google's native Places SDKs — reachable from
this package by injecting a custom provider (below). The strongest option
remains a backend proxy that keeps the key server side.

## Custom backends: `placeApiProvider`

`PlaceApiProvider` is now a public abstract class. Inject your own
implementation (backend proxy, native SDK wrapper, test fake) and the widgets
will use it instead of the built-in REST backends:

```dart
class MyProxyProvider extends PlaceApiProvider {
  @override
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types}) async {
    // call your server...
  }

  @override
  Future<Place> getPlaceDetailFromId(String placeId) async {
    // call your server...
  }
}

AddressAutocompleteTextField(
  mapsApiKey: 'unused',
  placeApiProvider: MyProxyProvider(),
  ...
)
```

## Other 2.0.0 breaking notes

- The internal concrete class previously named `PlaceApiProvider` (never
  exported from the package barrel) is now `LegacyPlaceApiProvider`;
  `PlaceApiProvider` is the abstract contract. Only code that deep-imported
  `api/place_api_provider.dart` is affected.
```

- [ ] **Step 2: Update `README.md`**

Make these edits:

1. In the intro (line 4, "The only required additional parameter is your Google Maps API key."), append:

```markdown
As of v2.0.0 the widgets use **Places API (New)** by default (the legacy
Places API cannot be enabled on new Google Cloud projects). Make sure
["Places API (New)"](https://console.cloud.google.com/apis/library/places.googleapis.com)
is enabled for your API key's project. Existing 1.x users: see
[MIGRATION.md](MIGRATION.md) — for most apps no code changes are needed. To
temporarily keep using the legacy API, pass `apiVersion: PlacesApiVersion.legacy`.
```

2. In the `## Features` list, add three bullets:

```markdown
- Uses Google **Places API (New)** by default; the legacy Places API remains
  available via `apiVersion: PlacesApiVersion.legacy`.
- Supports application-restricted API keys via `androidPackageName`,
  `androidCertSha1Fingerprint` and `iosBundleId` (sent as Google's
  `X-Android-Package` / `X-Android-Cert` / `X-Ios-Bundle-Identifier` headers).
- Pluggable backend: implement the public `PlaceApiProvider` abstract class
  and pass it as `placeApiProvider:` to use your own proxy/native backend
  (also handy as a fake in widget tests).
```

3. After the `## Usage` code examples, add:

```markdown
### Notes when using Places API (New) (the default)

- The legacy `address` type filter has no equivalent in the new API;
  `AutoCompleteType.address` (the default) is translated to
  `street_address` + `premise` + `subpremise`. Use
  `type: AutoCompleteType.geocode` for broader geocoding matches.
- `Suggestion.terms` is always `null` (no new-API equivalent).
- See [MIGRATION.md](MIGRATION.md) for key-restriction setup and custom
  `placeApiProvider` backends.
```

- [ ] **Step 3: Prepend to `CHANGELOG.md`**

```markdown
## 2.0.0

- **Places API (New) is now the default backend** (`places.googleapis.com/v1`).
  The legacy Places API was set to legacy status by Google on 2025-03-01 and
  cannot be enabled on new Cloud projects. Pass
  `apiVersion: PlacesApiVersion.legacy` to keep using the legacy API where it
  is still enabled. See MIGRATION.md.
- NEW: `placeApiProvider` widget parameter + public abstract
  `PlaceApiProvider` — inject a custom backend (backend proxy, native SDK
  wrapper, or test fake).
- NEW: `androidPackageName`, `androidCertSha1Fingerprint`, `iosBundleId`
  widget parameters — support application-restricted API keys over REST.
- Behavior on the new backend: `Suggestion.terms` is `null`;
  `AutoCompleteType.address` is translated to
  `street_address`/`premise`/`subpremise` (no `address` filter in the new API).
- BREAKING (internal): the concrete class formerly named `PlaceApiProvider`
  (not exported from the barrel) is now `LegacyPlaceApiProvider`.
- Removed stray debugPrint logging from the overlay mixin.
- Example app: runtime toggle between the two backends.
```

- [ ] **Step 4: Bump version in `pubspec.yaml`**

Change line 3: `version: 1.3.3` → `version: 2.0.0`.

- [ ] **Step 5: Verify**

Run: `flutter analyze` — "No issues found!"
Run: `flutter test` — all pass.
Run: `dart pub publish --dry-run` — expect "Package has 0 warnings." (or only the LICENSE/long-description warnings that already existed on 1.3.3).

Manual smoke checklist (requires a real key in `example/lib/privatekeys.dart` with Places API (New) enabled — record results in the PR/commit message):
- [ ] Address lookup returns suggestions on the NEW backend; selecting one fills the field and the details pane (name, lat/lng, zip+4).
- [ ] Zip, cities, and establishment fields work on the NEW backend.
- [ ] Toggle to LEGACY still works (on a project with legacy enabled).
- [ ] `flutter run -d chrome` on the example: check whether the new REST API works from the browser (spec open item — document the result in MIGRATION.md's notes either way).

- [ ] **Step 6: Commit**

```bash
git add MIGRATION.md README.md CHANGELOG.md pubspec.yaml
git commit -m "docs: migration guide, README and changelog for 2.0.0 (Places API New)"
```

---

## Deferred (explicitly out of scope for 2.0.0)

Per the spec's parity-first decision: `locationBias`/`locationRestriction`, `origin`+`distanceMeters`, `includeQueryPredictions`, `regionCode`, new Table A enum additions, and a native-SDK/App Check companion package are follow-up 2.x work.
