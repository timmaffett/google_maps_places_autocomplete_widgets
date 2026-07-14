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

## Flutter web support (new capability)

The new backend **works on Flutter web**: `places.googleapis.com` sends CORS
headers, so browsers can call it directly (verified 2026-07 with the example
app). Use an HTTP-referrer-restricted API key for web builds.

The legacy backend has **never** worked on the web — browsers block
`maps.googleapis.com/maps/api/place/*` responses (no CORS headers) and every
request fails with `ClientException: Failed to fetch`. On web you must use
the new API (or a backend proxy via `placeApiProvider`).

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
