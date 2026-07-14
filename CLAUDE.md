# google_maps_places_autocomplete_widgets

Flutter package (pure Dart, no platform code) providing `AddressAutocompleteTextField` and
`AddressAutocompleteTextFormField` — drop-in replacements for `TextField`/`TextFormField`
with Google Places address autocompletion. Published on pub.dev. Since v2.0.0 the default
backend is **Places API (New)** (`places.googleapis.com/v1`); the legacy Places API remains
available via `apiVersion: PlacesApiVersion.legacy` (1.3.x line was legacy-only).

## Commands

- `flutter analyze` — lint (uses `flutter_lints`)
- `flutter test` — unit tests
- `cd example && flutter run` — demo app; requires a real Maps API key
  (example reads it from `example/lib/privatekeys.dart`, which is git-ignored/private)

## Architecture

```
lib/address_autocomplete_widgets.dart      barrel export (the only intended import)
lib/widgets/address_autocomplete_generic.dart
    AddresssAutocompleteStatefulWidget     abstract widget: declares ALL shared params
                                           (note the triple-s typo in the class name — public API, keep)
    SuggestionOverlayMixin                 all behavior: overlay, debounce, focus,
                                           suggestion list, clear button, callbacks
lib/widgets/address_autocomplete_textfield.dart      TextField variant
lib/widgets/address_autocomplete_textformfield.dart  TextFormField variant
lib/service/address_service.dart           thin facade: search() + getPlaceDetail();
                                           selects/accepts the provider
lib/api/place_api_provider.dart            PUBLIC abstract PlaceApiProvider contract
                                           (fetchSuggestions, getPlaceDetailFromId)
lib/api/legacy_place_api_provider.dart     legacy Places API REST implementation
lib/api/new_place_api_provider.dart        Places API (New) REST implementation
                                           (key + app-restriction headers, field mask)
lib/api/place_builder.dart                 shared components->Place mapping + derived fields
lib/api/new_api_type_mapping.dart          AutoCompleteType -> includedPrimaryTypes
                                           (address => street_address/premise/subpremise)
lib/api/places_api_version.dart            enum PlacesApiVersion { placesApiNew, legacy }
lib/api/autocomplete_types.dart            AutoCompleteType enum (legacy type strings +
                                           onlySingleValueAllowed flag for collections)
                                           + validateAutocompleteTypes()
lib/model/suggestion.dart                  Suggestion(placeId, description, mainText,
                                           secondaryText, terms, types)
lib/model/place.dart                       Place: parsed address components + derived
                                           fields (zipCodePlus4, formattedAddressZipPlus4…)
```

Key property: widgets/mixin/models never touch the wire format — the Google API surface is
fully isolated behind `PlaceApiProvider` via `AddressService`. Session token (uuid v4) is
generated per widget instance and passed to both autocomplete and details calls (Google
billing sessions).

## Places API (New) support (implemented in v2.0.0)

The legacy Places API cannot be enabled on new Google Cloud projects (legacy-frozen
2025-03-01). v2.0.0 defaults to Places API (New) with `apiVersion: PlacesApiVersion.legacy`
opt-out, app-restriction header params (`androidPackageName`/`androidCertSha1Fingerprint`/
`iosBundleId`), and an injectable `placeApiProvider:` widget param (custom backends: native
SDK + App Check, backend proxy, test fakes). Parity-first: new-API-only features
(locationBias/locationRestriction, origin/distanceMeters, query predictions, regionCode)
are deliberately deferred to a 2.x minor.

Design spec: `doc/superpowers/specs/2026-07-13-places-api-new-design.md` (full legacy→new
wire mapping); implementation plan: `doc/superpowers/plans/2026-07-13-places-api-new-v2.md`;
user-facing migration guide: `MIGRATION.md`.

Open item: verify whether Flutter web can call the new REST API directly (legacy REST was
blocked by CORS in browsers) — see the smoke checklist in the implementation plan.

## Quirks & conventions

- `postalCodeLookup` is deprecated (replaced by `type:`/`types:`); files carry
  `// ignore_for_file: deprecated_member_use_from_same_package` for it.
- `type` (single) and `types` (list, max 5) are mutually exclusive — enforced by an assert
  in `SuggestionOverlayMixin.searchAddress`.
- Collections like `(cities)`/`(regions)`/`address`/`geocode`/`establishment` must be used
  alone (`onlySingleValueAllowed` on the enum).
- `lib/api/legacy_place_api_provider.dart` contains large comment blocks with real captured
  JSON responses from both legacy endpoints — mirrored as fixtures in the provider tests.
- Both built-in providers accept an injectable `http.Client` (`client:` ctor param) —
  tests use `MockClient` from `package:http/testing.dart`; no new dependencies.
- README documents the full user-facing API; keep it in sync with widget params.
