# Design: google_maps_places_autocomplete_widgets_native (native Places SDK provider)

Date: 2026-07-14
Status: Approved direction (build approach, layout, App Check scope, and naming confirmed
by Tim); spec pending final review.

## Problem

The core package's REST backend supports app-restricted API keys only via self-declared
headers (`X-Android-Package`/`X-Android-Cert`/`X-Ios-Bundle-Identifier`), which are public
strings a determined attacker can forge. Google's **native Places SDKs** unlock the real
hardening: **Firebase App Check** (Play Integrity on Android, App Attest/DeviceCheck on
iOS) — cryptographic app+device attestation. With App Check enforcement on, a scraped API
key is useless outside the genuine app. App Check for Places is only available through the
native SDKs, never raw REST.

The core package's v2.0.0 `placeApiProvider:` injection point was designed for exactly
this: a companion plugin can supply a native-SDK-backed `PlaceApiProvider` with zero core
changes.

## Decision summary

| Decision | Choice |
|---|---|
| Build approach | **Own thin plugin using Pigeon** (typed platform channels). Kotlin + Swift wrapping only what we need: init, autocomplete predictions, fetch place, App Check hookup. No dependency on `flutter_google_places_sdk` (App Check exposure there is uncertain, and we avoid inheriting a third-party surface/release cadence). |
| Repo layout | **`packages/google_maps_places_autocomplete_widgets_native/` in this repo.** Published to pub.dev as an independent package; its pubspec `repository:` points at the subdirectory. The root package does not move. |
| App Check | **Ships in v1** (it is the reason the plugin exists), as an opt-in `useAppCheck` flag on `initialize()`. |
| Name | `google_maps_places_autocomplete_widgets_native` |
| Plugin structure | Single plugin package declaring `android` + `ios` platforms (NOT a federated multi-package split — unwarranted for a 3-method surface we fully own). |
| Core wart fix | **Core v2.1.0 makes `mapsApiKey` optional** (`String?`); required unless `placeApiProvider` is supplied (constructor assert). Ships before/with the native package; the native package depends on core `^2.1.0`. |
| Firebase linkage | Confirmed by Tim 2026-07-14: linking Firebase App Check natively for all plugin users is fine — App Check IS the reason to use the native SDK. |

## Package layout

## Core package change first: v2.1.0 `mapsApiKey` optional

Today the widgets require `mapsApiKey` even when `placeApiProvider` bypasses it — the
`mapsApiKey: 'unused'` wart. Core v2.1.0 fixes this:

- `AddresssAutocompleteStatefulWidget.mapsApiKey` becomes `abstract final String? mapsApiKey`
  (both concrete widgets follow; the constructor param becomes optional).
- New constructor assert on both widgets:
  `assert(mapsApiKey != null || placeApiProvider != null, 'mapsApiKey is required unless a custom placeApiProvider is supplied')`.
- `AddressService` accepts `String? mapsApiKey`; the built-in providers (which are only
  constructed when `placeApiProvider` is null, hence when `mapsApiKey` is non-null per the
  assert) receive `mapsApiKey!`.
- **Backward compatible** (minor version): existing callers already pass the key; existing
  subclasses that declare `final String mapsApiKey` still satisfy the now-nullable
  abstract getter (non-nullable override of a nullable member is legal Dart).
- Published as core **2.1.0** as soon as it lands — the native package then depends on
  `^2.1.0` and its examples/docs omit `mapsApiKey` entirely.

## Package layout

```
packages/google_maps_places_autocomplete_widgets_native/
  pubspec.yaml            flutter plugin (android+ios), depends on
                          google_maps_places_autocomplete_widgets: ^2.1.0
  pigeons/messages.dart   Pigeon definitions (input to code generation)
  lib/
    google_maps_places_autocomplete_widgets_native.dart   barrel export
    src/native_place_api_provider.dart                    the public class
    src/messages.g.dart                                   Pigeon-generated Dart
  android/                Kotlin implementation (+ generated Messages.g.kt)
  ios/                    Swift implementation (+ generated Messages.g.swift)
  example/                minimal app using the core widgets + this provider
  test/                   Dart unit tests (mocked Pigeon host API)
  README.md               setup (Android/iOS/Firebase App Check), usage
  CHANGELOG.md
```

## Public Dart API

```dart
class NativePlaceApiProvider extends PlaceApiProvider {
  /// Must be called once (e.g. in main()) before constructing providers.
  /// Initializes the native Places SDK (New) with [mapsApiKey]. When
  /// [useAppCheck] is true, also installs the SDKs' Firebase App Check token
  /// providers — the host app must have configured firebase_core +
  /// firebase_app_check first (see README walkthrough).
  static Future<void> initialize({
    required String mapsApiKey,
    bool useAppCheck = false,
  });

  /// True on Android and iOS; false elsewhere (web/desktop use the core
  /// package's default REST backend instead).
  static bool get isSupported;

  /// Same semantics as the core widgets' componentCountry / language params.
  NativePlaceApiProvider({String? componentCountry, String? language});

  // PlaceApiProvider implementation via Pigeon:
  @override Future<List<Suggestion>> fetchSuggestions(...);
  @override Future<Place> getPlaceDetailFromId(String placeId);
}
```

Usage with the core widgets (the point of the whole design — one line changes):

```dart
await NativePlaceApiProvider.initialize(mapsApiKey: key, useAppCheck: true);
...
AddressAutocompleteTextField(
  // no mapsApiKey needed — core 2.1.0 makes it optional when a provider is injected
  placeApiProvider: NativePlaceApiProvider(componentCountry: 'us'),
  ...
)
```

Error behavior:
- Constructing/calling on unsupported platforms → `UnsupportedError` naming the
  supported platforms and the REST alternative.
- Calling fetch methods before `initialize()` → `StateError` with instructions.
- Native SDK errors surface as `Exception` with the SDK's message text (matching the
  `PlaceApiProvider` contract: throw Exception with human-readable message; empty list —
  never a throw — for zero results).

## Pigeon bridge

`pigeons/messages.dart` defines one host API and two data classes:

```dart
@HostApi()
abstract class PlacesNativeApi {
  @async void initialize(String apiKey, bool useAppCheck);
  /// Session tokens are managed natively (see Session semantics).
  @async List<NativePrediction> fetchPredictions(
      String query, List<String> includedTypes, String? countryCode, String? languageCode);
  @async NativePlaceDetails fetchPlace(String placeId, String? languageCode);
}

class NativePrediction {
  String placeId; String fullText; String? primaryText; String? secondaryText;
  List<String> types;
}

class NativeAddressComponent { List<String> types; String? longText; String? shortText; }

class NativePlaceDetails {
  String? name; String? formattedAddress; double? lat; double? lng;
  List<NativeAddressComponent> components;
}
```

## Session semantics (native-side)

The native SDKs use opaque `AutocompleteSessionToken` objects, not strings, so the token
lives on the native side: create one lazily on the first `fetchPredictions` call, reuse it
for subsequent predictions, attach it to `fetchPlace`, then discard it (a new one is
created on the next prediction). This reproduces the billing semantics of the REST
backends (details call terminates the session). The core widgets' string `sessionToken`
is simply unused by this provider — the abstract `PlaceApiProvider` contract already
permits implementations to manage sessions internally.

## Reuse from the core package (no core changes required)

- **`buildPlaceFromComponents`** (`package:google_maps_places_autocomplete_widgets/api/place_builder.dart`):
  native address components map to `RawAddressComponent(types, longText, shortText)` and
  produce a `Place` byte-identical to the REST backends' (same derived zipPlus4/synthesized
  address behavior).
- **`mapTypesToNewApi` + `validateAutocompleteTypes`**
  (`.../api/new_api_type_mapping.dart`, `.../api/autocomplete_types.dart`): the native
  Places SDK (New) accepts the same new-API type strings, so `AutoCompleteType.address`
  gets the same `street_address`+`premise`+`subpremise` expansion. Validation runs on the
  Dart side before crossing the bridge.
- `Suggestion.terms` is `null` (same as the new REST backend). `mainText`/`secondaryText`/
  `types` come from the prediction's primary/secondary text and place types.

These are deep imports of public (non-`src/`) core libraries — acceptable; if a third
party ever needs them we can add them to the core barrel in a 2.x minor.

## Native implementations

**Android** (Kotlin):
- Dependency `com.google.android.libraries.places:places` 5.x; minSdk 24 (SDK floor).
- `initialize`: `Places.initializeWithNewPlacesApiEnabled(applicationContext, apiKey)`;
  when `useAppCheck`, install the Places App Check token provider backed by
  `FirebaseAppCheck` (exact artifact/API verified at implementation — see Open items).
- `fetchPredictions`: `FindAutocompletePredictionsRequest` with query, type filter,
  country filter, session token.
- `fetchPlace`: `FetchPlaceRequest` with fields DISPLAY_NAME, FORMATTED_ADDRESS,
  ADDRESS_COMPONENTS, LOCATION (new-SDK field names verified at implementation).

**iOS** (Swift):
- Pod `GooglePlaces` 9.x; min iOS pinned at implementation to the chosen SDK version's
  floor (15 or 16).
- `initialize`: `GMSPlacesClient.provideAPIKey(...)` (new-API variant); when
  `useAppCheck`, install the SDK's App Check token provider before first client use.
- `fetchPredictions`/`fetchPlace`: `GMSPlacesClient` autocomplete + place fetch with
  `GMSAutocompleteFilter` (types, countries) and session token.

Both platforms return errors as Pigeon errors carrying the SDK's status message; the Dart
side rethrows as `Exception`.

## App Check (v1, opt-in)

- `initialize(useAppCheck: true)` installs the native token providers. Host app
  responsibilities (documented step-by-step in the plugin README): Firebase project,
  `firebase_core` + `firebase_app_check` configured, Play Integrity registration
  (Android) / App Attest (iOS), then — after monitoring — turning on **enforcement** in
  the Cloud console, which is what actually makes a scraped key useless.
- **Accepted tradeoff (confirmed by Tim 2026-07-14):** the plugin's native builds link the
  Firebase App Check libraries even for apps that never opt in — acceptable because App
  Check is the primary reason to choose the native SDK at all. A separate "-appcheck
  addon" package was rejected as complexity not yet earned.
- README carries the same honest security-tier framing as the core MIGRATION.md: native
  SDK *without* App Check ≈ REST restriction headers; App Check + enforcement is the
  actual hardening.

## Example app

Minimal app in the package's `example/`: one `AddressAutocompleteTextField` and one
`AddressAutocompleteTextFormField` with `placeApiProvider: NativePlaceApiProvider(...)`,
a details readout, and an App Check on/off note. API key via a git-ignored
`example/lib/privatekeys.dart` (same pattern as the root example).

## Testing

- **Dart unit tests** with a mocked Pigeon host API: prediction→`Suggestion` mapping,
  components→`Place` mapping (reusing the core test fixtures' component data), type
  validation/expansion crossing the bridge, uninitialized→`StateError`,
  unsupported-platform→`UnsupportedError`, native-error→`Exception` passthrough.
- **Manual device checklist** (native behavior can't run in CI):
  1. Android emulator/device: predictions + details round trip.
  2. iOS simulator/device: same.
  3. The headline test: an **Android-app-restricted key** (package name + SHA-1 in the
     Cloud console) working with zero header configuration.
  4. App Check: token flow visible in Firebase console metrics; then enforcement ON and
     verify the app still works while a raw REST call with the same key is rejected.
     (Tim has an existing Firebase project holding the test API keys, available for this.)
- `flutter analyze` + `dart pub publish --dry-run` clean from the package directory.

## Release

- Version **1.0.0**, published only after the manual device checklist passes.
- Root repo updates in the same release: root README gains a "Hardened key security
  (native SDK + App Check)" section linking to the new package; MIGRATION.md's security
  tiers section links tier 3 to it; CLAUDE.md documents the two-package layout.

## Open items (verify during implementation, not blockers)

- Exact Android App Check integration surface: artifact name and provider API
  (`setPlacesAppCheckTokenProvider` / `places-appcheck` interop) for places 5.x.
- Exact iOS App Check provider API name in GooglePlaces 9.x.
- Whether native type filters accept the `(cities)`/`(regions)` collections identically
  to REST (expected yes — same new-API type system); if not, map collections to their
  member type lists on the Dart side.
- Places SDK new-SDK field-name enums for the details fetch (DISPLAY_NAME vs NAME etc.).

## Sources

- Places SDK for Android (init, App Check): https://developers.google.com/maps/documentation/places/android-sdk/reference/com/google/android/libraries/places/api/Places
- Places SDK for Android App Check: https://developers.google.com/maps/documentation/places/android-sdk/app-check
- Places SDK for iOS (client, versions): https://developers.google.com/maps/documentation/places/ios-sdk/release-notes
- Places SDK for iOS App Check: https://developers.google.com/maps/documentation/places/ios-sdk/app-check
- Pigeon: https://pub.dev/packages/pigeon
- Prior art considered: https://pub.dev/packages/flutter_google_places_sdk
