# Handoff: iOS verification of the native provider plugin (device-checklist item 2)

**Audience:** the Claude Code session running on Tim's Mac.
**Branch:** `native-provider` (do all work here; PR #10 is open from it).

## Context in one paragraph

This repo holds two pub.dev packages: the core `google_maps_places_autocomplete_widgets`
(root, pure Dart) and the new `packages/google_maps_places_autocomplete_widgets_native/`
— a Pigeon-based Flutter plugin whose `NativePlaceApiProvider` implements the core's
`PlaceApiProvider` via Google's native Places SDKs. Read `CLAUDE.md` (repo layout section)
and, if needed, the spec/plan in `doc/superpowers/`. Everything is implemented and
device-verified on Android (round trip, app-restricted key, and Firebase App Check
enforcement all PASSED). **The single remaining verification before merge/publish is iOS:
the Swift side has never been compiled — there was no Mac available.**

## Your task

1. **Compile check.** From `packages/google_maps_places_autocomplete_widgets_native/example`:
   - `cp lib/privatekeys.dart.template lib/privatekeys.dart` and have Tim paste his test
     API key into it (NEVER commit this file; it is git-ignored — verify that stays true).
   - `flutter run` on an **iOS 16+ simulator** (floor of GooglePlaces 10.x). First run
     installs pods.
2. **Round-trip check (Tim drives the simulator).** Both tabs: type an address → suggestion
   overlay appears → tap → details arrive (tab 1 shows a `Place(...)` dump; tab 2 fills
   City/State/Zip). That proves Dart → Pigeon → Swift → GooglePlaces SDK → back.
3. **Report results to Tim** clearly: compile ok / round trip ok / what failed.

## Likely failure points (fix-forward is allowed and expected)

The Swift file `ios/google_maps_places_autocomplete_widgets_native/Sources/
google_maps_places_autocomplete_widgets_native/PlacesNativePlugin.swift` was written
against docs, never compiled. If it errors:

- **Pigeon glue names**: the generated `Messages.g.swift` (same dir) defines protocol
  `PlacesNativeApi` and `PlacesNativeApiSetup.setUp(binaryMessenger:api:)` — check the
  plugin's conformance signatures against the generated file, not against assumptions.
- **`GMSFetchPlaceRequest`**: we used
  `GMSFetchPlaceRequest(placeID:placeProperties:sessionToken:)`. If GooglePlaces 10.x
  changed the initializer, adapt (property-setter style is the fallback).
- **`GMSAutocompleteRequest(query:)` / `fetchAutocompleteSuggestions(from:)`** and the
  `placeSuggestion` fields (`placeID`, `attributedFullText`, `attributedPrimaryText`,
  `attributedSecondaryText?`, `types`) — verify against the installed SDK headers.
- **Pod resolution**: podspec pins `GooglePlaces ~> 10.0`, `s.platform = :ios, '16.0'`,
  `FirebaseAppCheck`, `s.static_framework = true`. If CocoaPods can't satisfy (Google is
  sunsetting CocoaPods releases), relaxing the pin or noting the SPM path
  (`Package.swift` in the plugin's ios/ dir already declares
  googlemaps/ios-places-sdk >= 10.0 and firebase-ios-sdk >= 12.0) are both acceptable —
  prefer whatever makes `flutter run` succeed and note what you changed.
- App Check on iOS (`GMSPlacesClient.setAppCheckTokenProvider`, protocol
  `GMSPlacesAppCheckTokenProvider`, async `fetchAppCheckToken()`) — only compiled, not
  exercised: the example runs with `useAppCheck = false` by default. Do NOT try to set up
  Firebase/App Check on iOS in this session; that's deliberately out of scope today.

## Hard rules

- **NO `Co-Authored-By` or any Claude attribution in commit messages** (standing rule).
- Fixes: verify with `flutter analyze` (from the plugin dir) before committing; commit to
  `native-provider` with plain, conventional messages (e.g. `fix(native): correct
  GMSFetchPlaceRequest initializer for GooglePlaces 10.x`) and push — the Windows session
  will pull.
- Do NOT merge PR #10, do NOT tag, do NOT publish anything — that happens after this
  verification, from the coordinating session.
- Do NOT commit `example/lib/privatekeys.dart`, any `google-services.json`, or any
  `GoogleService-Info.plist`.
- If Dart-side changes seem needed (they shouldn't be), stop and report instead — the
  Dart layer is verified by 7 passing tests (`flutter test` in the plugin dir) and the
  Android device runs; the problem is almost certainly on the Swift/pod side.

## Success criteria

`flutter run` builds and launches on an iOS simulator; both example tabs complete the
type → suggest → tap → details round trip; any Swift/pod fixes are committed and pushed
to `native-provider`; Tim knows the outcome. Item 2 of the device checklist is then
complete, and the coordinating session takes over for merge → tag `v2.1.0` → publish
core 2.1.0 → publish native 1.0.0.
