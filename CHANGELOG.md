# google_maps_places_autocomplete_widgets package

## 2.1.1

* Add missing type annotation flagged by pub.dev static analysis (no
  functional change).

## 2.1.0

* `mapsApiKey` is now optional when a custom `placeApiProvider` is supplied
  (previously callers had to pass a dummy value). It remains required for the
  built-in backends (enforced by assert).
* NEW companion package
  [`google_maps_places_autocomplete_widgets_native`](https://pub.dev/packages/google_maps_places_autocomplete_widgets_native)
  (v1.0.0, in `packages/` of this repo): a `PlaceApiProvider` backed by the
  native Places SDKs (Android/iOS) with app-restricted API key support and
  opt-in Firebase App Check attestation — verified end-to-end on real devices
  with App Check enforcement enabled.

## 2.0.0

* **Places API (New) is now the default backend** (`places.googleapis.com/v1`).
  The legacy Places API was set to legacy status by Google on 2025-03-01 and
  cannot be enabled on new Cloud projects. Pass
  `apiVersion: PlacesApiVersion.legacy` to keep using the legacy API where it
  is still enabled. See MIGRATION.md.
* NEW: `placeApiProvider` widget parameter + public abstract
  `PlaceApiProvider` — inject a custom backend (backend proxy, native SDK
  wrapper, or test fake).
* NEW: `androidPackageName`, `androidCertSha1Fingerprint`, `iosBundleId`
  widget parameters — support application-restricted API keys over REST.
* Behavior on the new backend: `Suggestion.terms` is `null`;
  `AutoCompleteType.address` is translated to
  `street_address`/`premise`/`subpremise` (no `address` filter in the new API).
* BREAKING (internal): the concrete class formerly named `PlaceApiProvider`
  (not exported from the barrel) is now `LegacyPlaceApiProvider`.
* Removed stray debugPrint logging from the overlay mixin.
* NEW: Flutter **web** works with the new backend (`places.googleapis.com`
  supports CORS; the legacy endpoint never did — use a referrer-restricted key).
* Example app: dropdown to select the Places API backend at runtime (with a
  warning that the legacy API cannot work on web).

## 1.3.3

* Fix dart analyze warning about using deprecated postalCodeLookup (which we use internally to allow it to continue to work
  while at the same time being deprecated.

## 1.3.2

* Correct screenshot image

## 1.3.1

* Added `screenshots:` section to `pubspec.yaml`

## 1.3.0

* Added `type` and `types` arguments for specifying the `AutoCompleteType` enum of Google Places autocomplete information to
  return.  (Defaults to `AutoCompleteType.address`).  
  This allows `AutoCompleteType.cities` as [Issue #1](https://github.com/timmaffett/google_maps_places_autocomplete_widgets/issues/1) requested.
* Deprecated the use of `postalCodeLookup` parameter, use `type:AutoCompleteType.postalCode` instead)

## 1.2.6

* Added `homepage:` and `issuetracker:` fields to pubspec.yaml

## 1.2.5

* Updated pubspec.yaml to add topics
* Fix typos in README.md, dart format

## 1.2.4

* Updated to current sdk and packages

## 1.2.3

* Updated to current packages

## 1.2.2

* Added `onFinishedEditingWithNoSuggestion` callback from [this pr](https://github.com/leandro-zanardi/maps_places_autocomplete/pull/6)

## 1.2.1

* Updated README.md, modified version number to properly reflect the number of internal versions
  iterated through before public release.

## 1.0.1

* Refactor suggestion query and overlay functionality to `SuggestionOverlayMixin`
  mixin via the clases `AddresssAutocompleteStatefulWidget` and
  `OverlaySuggestionDetails`.
* Refactor big gain is now there is a single version of all suggestiona and overlay
  functionality for both `AddressAutocompleteTextField` and
  `AddressAutocompleteTextFormField`.
* Extensive expansion of the `example/main.dart` example app to show most various
  features of the package.
* Moved to new package name and layout.

## 1.0.0

* Refactor package and create both `TextField` and `TextFormField` versions of the
  `AddressAutocompleteXXXX` widgets
* Add many more callback capabilities to allow modification of behavior in various
  ways.
* Added `TextFieldTapRegion` use for desktop support
* Extensive testing and bug fixing
* Add many more standard `Place` properties
* Change to retrieve additional formatted address info from google maps api
* Added support for zip code lookup

## 0.0.2

* Add custom layout config.

## 0.0.1

* Initial release.
