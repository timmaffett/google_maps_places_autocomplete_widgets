# google_maps_places_autocomplete_widgets

Flutter package (pure Dart, no platform code) providing `AddressAutocompleteTextField` and
`AddressAutocompleteTextFormField` — drop-in replacements for `TextField`/`TextFormField`
with Google Places address autocompletion. Published on pub.dev; current version in
`pubspec.yaml` (1.3.x line uses the **legacy** Places API).

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
lib/service/address_service.dart           thin facade: search() + getPlaceDetail()
lib/api/place_api_provider.dart            ALL Google REST calls live here (2 methods:
                                           fetchSuggestions, getPlaceDetailFromId)
lib/api/autocomplete_types.dart            AutoCompleteType enum (legacy type strings +
                                           onlySingleValueAllowed flag for collections)
lib/model/suggestion.dart                  Suggestion(placeId, description, mainText,
                                           secondaryText, terms, types)
lib/model/place.dart                       Place: parsed address components + derived
                                           fields (zipCodePlus4, formattedAddressZipPlus4…)
```

Key property: widgets/mixin/models never touch the wire format — the Google API surface is
fully isolated behind `PlaceApiProvider` via `AddressService`. Session token (uuid v4) is
generated per widget instance and passed to both autocomplete and details calls (Google
billing sessions).

## Places API migration (active work)

The legacy Places API cannot be enabled on new Google Cloud projects (legacy-frozen
2025-03-01). Plan: v2.0.0 defaults to **Places API (New)** (`places.googleapis.com/v1`,
still plain REST — package stays pure Dart) with `apiVersion: PlacesApiVersion.legacy`
opt-out; dedicated params for app-restricted API keys (`X-Android-Package`/`X-Android-Cert`/
`X-Ios-Bundle-Identifier` headers); feature parity first, new-API-only features later.
`PlaceApiProvider` becomes a public, injectable abstraction (`placeApiProvider:` widget
param) so custom backends (native SDK + App Check, backend proxy, test mocks) can be
supplied without core changes.

**Full design spec: `docs/superpowers/specs/2026-07-13-places-api-new-design.md`** — read it
before touching `lib/api/`. It contains the complete legacy→new wire mapping, the
`AutoCompleteType.address` mapping problem (no `address` filter in the new API), and the
release/testing plan.

## Quirks & conventions

- `PlaceApiProvider.compomentCountry` — misspelled ("compoment") internal field; the public
  widget param is correctly `componentCountry`. Don't rename the public one.
- `postalCodeLookup` is deprecated (replaced by `type:`/`types:`); files carry
  `// ignore_for_file: deprecated_member_use_from_same_package` for it.
- `type` (single) and `types` (list, max 5) are mutually exclusive — enforced by an assert
  in `SuggestionOverlayMixin.searchAddress`.
- Collections like `(cities)`/`(regions)`/`address`/`geocode`/`establishment` must be used
  alone (`onlySingleValueAllowed` on the enum).
- Stray `debugPrint` calls exist in the mixin (init/dispose/hideOverlay) — legacy debugging
  noise; candidates for cleanup in 2.0.0.
- `lib/api/place_api_provider.dart` contains large comment blocks with real captured JSON
  responses from both legacy endpoints — useful as parser test fixtures.
- README documents the full user-facing API; keep it in sync with widget params.
