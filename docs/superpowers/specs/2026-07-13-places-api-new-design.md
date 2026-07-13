# Design: Places API (New) support in google_maps_places_autocomplete_widgets

Date: 2026-07-13
Status: Approved direction (rollout, key-security, and scope decisions confirmed by Tim); spec pending final review.

## Problem

Google set the legacy Places API to **legacy status on March 1, 2025** — it can no longer
be enabled on new Google Cloud projects. Existing projects keep working (no shutdown date
announced yet; Google promises ≥12 months notice), but every *new* user of this package is
dead in the water. The package must support **Places API (New)** (`places.googleapis.com/v1`).

## Decision summary

| Decision | Choice |
|---|---|
| Config option vs new package | **Same package, selectable backend.** The new API is still plain HTTPS REST, so the package stays pure Dart (`http` package, no native SDK, no plugin). |
| Rollout | **v2.0.0 defaults to the NEW API**, with `apiVersion: PlacesApiVersion.legacy` opt-out. 1.x remains on pub.dev for users who pin. |
| App-restricted keys | **Dedicated optional params** (`androidPackageName`, `androidCertSha1Fingerprint`, `iosBundleId`) that emit the `X-Android-Package` / `X-Android-Cert` / `X-Ios-Bundle-Identifier` headers. Values supplied by the developer — no added plugin dependency. |
| Scope of first release | **Parity first.** Match existing features 1:1 plus the type-mapping layer. New-API-only capabilities (locationBias/locationRestriction, origin/distanceMeters, includeQueryPredictions, regionCode) come in a follow-up 2.x minor. |
| Extensibility | **`PlaceApiProvider` is a public, injectable abstraction.** An optional `placeApiProvider:` widget parameter lets callers supply a custom backend (native SDK + App Check, backend proxy, mocks for tests) without changes to this package. Approved 2026-07-13. |

### Why not the alternatives

- **Native Places SDK plugin (Android/iOS)**: best key security, but converts a pure-Dart
  package into a federated plugin, drops desktop (and web) support, ~10× effort. REST +
  restriction headers achieves the same lock-down.
- **New package**: zero risk to 1.x users but splits maintenance, worsens the pub.dev
  namespace clutter, and makes migration *harder* (new dependency + imports) — contrary to
  the goal of an easy transition.

## Architecture

All Google-facing code is already isolated in `lib/api/place_api_provider.dart`
(2 methods), consumed only via `lib/service/address_service.dart`. Widgets, the overlay
mixin, and the `Suggestion`/`Place` models never touch the wire format.

```
lib/api/
  place_api_provider.dart        -> abstract class PlaceApiProvider (PUBLIC — exported
                                    from the barrel file)
                                    { fetchSuggestions(...), getPlaceDetailFromId(...) }
  legacy_place_api_provider.dart -> current implementation, moved verbatim
  new_place_api_provider.dart    -> Places API (New) implementation
  places_api_version.dart        -> enum PlacesApiVersion { legacy, placesApiNew }
```

`AddressService` uses the widget's `placeApiProvider` if supplied; otherwise it constructs
the built-in provider selected by `apiVersion`. `Suggestion` and `Place` models are
unchanged — all providers populate the same models.

### Injectable provider (extensibility hook)

`PlaceApiProvider` is exported as part of the public API, with doc comments defining the
contract each method must honor (session-token semantics, throw-on-error behavior, empty
list on zero results). The abstract class must therefore expose what implementations need:
the query input, mapped types, language/country settings, and session token are passed
through the existing method signatures; widget-level config reaches the provider via its
constructor (built-ins) or however a custom implementation chooses.

Rationale: this is cheap insurance that keeps the core package pure Dart while enabling,
without any future changes here:
- a native Places SDK backend (separate opt-in plugin package) — the only path to Firebase
  App Check attestation (see "Key security tiers" below);
- backend-proxy providers where the API key never ships in the app;
- test mocks and fakes for consumers' widget tests.

### New widget parameters (both TextField and TextFormField variants, declared in `AddresssAutocompleteStatefulWidget`)

```dart
/// Which Google Places backend to use. Defaults to the new API.
final PlacesApiVersion apiVersion;            // default: PlacesApiVersion.placesApiNew

/// Optional — sent as X-Android-Package / X-Android-Cert so Android-app-restricted
/// API keys work over REST. Supply your applicationId and the SHA-1 fingerprint
/// registered in the Cloud console.
final String? androidPackageName;
final String? androidCertSha1Fingerprint;

/// Optional — sent as X-Ios-Bundle-Identifier for iOS-app-restricted keys.
final String? iosBundleId;

/// Optional — inject a custom backend (native SDK wrapper, backend proxy, test mock).
/// When supplied, [apiVersion] and the built-in providers are bypassed entirely.
final PlaceApiProvider? placeApiProvider;
```

Restriction headers are attached only when non-null. They are meaningful for the new
backend; on web they are ignored (browsers use HTTP-referrer key restrictions instead).

### Key security tiers (documented in MIGRATION.md/README)

1. **REST + restriction headers** (this package's built-in new backend): package name /
   cert fingerprint / bundle ID are public strings, so a determined attacker who extracts
   the key can forge them. Deters scraping bots and accidental key reuse; pair with API
   restrictions and quota caps.
2. **Native Places SDK without App Check**: same security as tier 1 — identical
   key-restriction check, just auto-configured.
3. **Native Places SDK + Firebase App Check** (Play Integrity / App Attest): cryptographic
   app+device attestation; with enforcement on, a scraped key is useless outside the
   genuine app. Only available via the native SDKs — not raw REST. Reachable from this
   package only through an injected custom `placeApiProvider` (possible future companion
   plugin package, demand-driven).
4. **Backend proxy**: key never ships in the app; implementable today via a custom
   `placeApiProvider`.

## Wire mapping

### Autocomplete

Legacy: `GET maps.googleapis.com/maps/api/place/autocomplete/json?input=&types=&key=&sessiontoken=&language=&components=country:xx`

New: `POST places.googleapis.com/v1/places:autocomplete`
- Headers: `Content-Type: application/json`, `X-Goog-Api-Key: <key>`, optional restriction headers
- Body:
  ```json
  {
    "input": "<query>",
    "sessionToken": "<uuid, same one used today>",
    "languageCode": "<language>",              // when language != null
    "includedRegionCodes": ["<componentCountry>"],  // when componentCountry != null
    "includedPrimaryTypes": [ ...mapped types... ]  // see type mapping
  }
  ```
- Response → `Suggestion`:
  | Suggestion field | New API source (`suggestions[].placePrediction`) |
  |---|---|
  | `placeId` | `placeId` |
  | `description` | `text.text` |
  | `mainText` | `structuredFormat.mainText.text` |
  | `secondaryText` | `structuredFormat.secondaryText.text` |
  | `types` | `types` |
  | `terms` | **no equivalent — null** (documented behavior change) |
- Entries with only `queryPrediction` (no `placePrediction`) are skipped (we never request
  query predictions in the parity release).
- Zero results: new API returns HTTP 200 with empty/missing `suggestions` → return `[]`.
- Errors: no `status: OK` envelope; non-200 carries `{"error": {"message", "status"}}` →
  throw `Exception(error.message)`.

### Place details

Legacy: `GET .../place/details/json?place_id=&fields=name,formatted_address,address_component,geometry&key=&sessiontoken=`

New: `GET places.googleapis.com/v1/places/{placeId}?sessionToken=<token>&languageCode=<lang>`
- Headers: `X-Goog-Api-Key: <key>`,
  `X-Goog-FieldMask: id,displayName,formattedAddress,addressComponents,location`
- Passing the session token here **terminates the billing session** — same behavior as the
  legacy flow.
- Response → `Place`:
  | Place field | New API source |
  |---|---|
  | `name` | `displayName.text` |
  | `formattedAddress` | `formattedAddress` |
  | `lat` / `lng` | `location.latitude` / `location.longitude` |
  | components | `addressComponents[]` with `longText`/`shortText`/`types` (legacy names: `long_name`/`short_name`) — same type strings (`street_number`, `route`, `locality`, `administrative_area_level_1/2`, `sublocality(_level_1)`, `country`, `postal_code`, `postal_code_suffix`) |
- All derived-field logic (`zipCodePlus4`, synthesized `streetAddress` /
  `formattedAddress` / `formattedAddressZipPlus4`) is shared, not duplicated — extract to a
  common helper both providers call.

## Type mapping (`AutoCompleteType` → `includedPrimaryTypes`)

The public `AutoCompleteType` enum is unchanged. Each enum value gains a new-API mapping:

- **Identity mapping** for values that exist in new Table A/B (`postal_code`, `locality`,
  `establishment`, `geocode`, `(cities)`, `(regions)`, most Table 1 business types, ...).
- **`AutoCompleteType.address` (the package default) does not exist in the new API.**
  Maps to `["street_address", "premise", "subpremise"]` — precise-address prediction types.
  Documented in README/MIGRATION with the note that `AutoCompleteType.geocode` (broader)
  or an explicit `types:` list can be used instead.
- **Audit task**: during implementation, check every enum value against new Table A/B.
  Values with no new-API equivalent throw a descriptive `ArgumentError` when used with the
  new backend (naming the nearest valid alternatives) and keep working on legacy.
- Validation rule change: new API rejects `(cities)`/`(regions)` combined with anything —
  already modeled by `onlySingleValueAllowed`; max 5 values rule is identical.

## Unchanged public surface (migration cost for users: near zero)

- Widget class names, all existing constructor parameters, `Suggestion`/`Place` models,
  all callbacks (`onSuggestionClick`, `onInitialSuggestionClick`, `prepareQuery`, ...),
  session-token handling, debounce, overlay rendering.
- `componentCountry` and `language` keep their names and are translated internally.
- Only observable behavior differences on the new backend: `Suggestion.terms == null`, and
  slightly different prediction sets for `AutoCompleteType.address` (mapping above).

## Error handling

- Provider-specific error parsing lives in each provider; both surface `Exception` with
  Google's message text, preserving current behavior.
- New backend adds a clearer message for HTTP 403 `PERMISSION_DENIED` hinting
  "Is 'Places API (New)' enabled for this key?" — the #1 expected migration stumble.

## Documentation & release

- `MIGRATION.md`: enable "Places API (New)" in Cloud console; key restriction setup
  (Android SHA-1 / iOS bundle / web referrer); the `address`-type mapping note;
  `apiVersion: PlacesApiVersion.legacy` escape hatch.
- README: rewritten quick-start (new API is the default), new params documented, link to
  new-API place-type tables alongside legacy tables.
- Example app: add a runtime toggle between backends and fields for restriction params.
- `CHANGELOG.md` + version `2.0.0`.

## Testing

- Unit tests with a mocked `http.Client` injected into each provider (constructor gains an
  optional `Client` for testability):
  - request shape golden tests (URL/headers/body for both backends, all param combos);
  - response parsing tests from captured real JSON (suggestion list, details, zero-results,
    error payloads);
  - type-mapping table tests (address expansion, collections-alone validation, >5 throws,
    unsupported-on-new throws);
  - injectable-provider test: a fake `PlaceApiProvider` passed via `placeApiProvider:`
    receives the calls and its results drive the widget (also serves as the reference
    example for custom backends).
- Manual smoke test via example app with a real key (both backends, Android-restricted key).

## Risks / open items

- **Web + CORS**: legacy REST was not callable from browsers; the new API is expected to
  support browser calls with referrer-restricted keys — verify on Flutter web during
  implementation and document the result.
- Legacy `Table 1` business types whose names changed in new Table A — resolved by the
  audit task above.
- Pricing SKUs differ between legacy and new (per-session vs per-request nuances) — note in
  README; no code impact.

## Sources

- Autocomplete (New): https://developers.google.com/maps/documentation/places/web-service/place-autocomplete
- places.autocomplete reference: https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places/autocomplete
- places.get reference: https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places/get
- Migration overview: https://developers.google.com/maps/documentation/places/web-service/legacy/migrate-overview
- Autocomplete migration param table: https://developers.google.com/maps/documentation/places/web-service/migrate-autocomplete
- New place types (Table A/B): https://developers.google.com/maps/documentation/places/web-service/place-types
- Legacy status: https://developers.google.com/maps/legacy
- API-key app restrictions over REST: https://docs.cloud.google.com/api-keys/docs/add-restrictions-api-keys
