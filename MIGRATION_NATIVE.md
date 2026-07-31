# Migrating an app to the native Places SDK provider

Step-by-step guide for converting a Flutter app that uses
`google_maps_places_autocomplete_widgets` (any version) to the native
Android/iOS backend provided by
[`google_maps_places_autocomplete_widgets_native`](https://pub.dev/packages/google_maps_places_autocomplete_widgets_native).

Written to be followed by a human **or handed verbatim to an AI coding agent**
("read MIGRATION_NATIVE.md in the google_maps_places_autocomplete_widgets
repo and apply it to this project"). Steps are ordered; don't skip the
verification steps.

## Why migrate

The REST backends require your Google Maps API key to ship inside the app,
protected at best by spoofable restriction headers. The native Places SDKs
attach your app's real identity (package name + signing certificate / bundle
id), so **app-restricted keys work with zero configuration**, and optionally
**Firebase App Check** adds cryptographic attestation (Play Integrity /
App Attest) — with enforcement on, a leaked or scraped key is rejected
everywhere except your genuine app.

## Step 0 — Determine the starting point

Check `pubspec.yaml` for the current `google_maps_places_autocomplete_widgets`
version:

- **`>=2.1.0`** → go to Step 1.
- **`2.0.x`** → bump to `^2.1.2` (no code changes needed), then Step 1.
- **`1.x`** → first migrate to 2.x by following
  [MIGRATION.md](MIGRATION.md). For most apps this is only the version bump —
  the widget API is unchanged; the default backend becomes Places API (New).
  Two behavior notes: `Suggestion.terms` is always `null` on the new backend,
  and `AutoCompleteType.address` is translated to
  `street_address`/`premise`/`subpremise`. Then continue below.
  (Only if the app subclassed the internal `PlaceApiProvider` class from 1.x:
  it was renamed `LegacyPlaceApiProvider`; the public abstract contract is now
  `PlaceApiProvider`.)

Also confirm platform floors — the native package requires:

- Android `minSdkVersion` **24** or higher
- iOS deployment target **16.0** or higher (GooglePlaces SDK 10.x floor) —
  check `ios/Runner.xcodeproj/project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET`)
  and `ios/Podfile` (`platform :ios`); raise both if lower.

## Step 1 — Add the native package

```yaml
dependencies:
  google_maps_places_autocomplete_widgets: ^2.1.2
  google_maps_places_autocomplete_widgets_native: ^1.0.0
```

`flutter pub get`. No manifest/Info.plist changes are required — the API key
is supplied at runtime.

## Step 2 — Initialize the native SDK at startup

In `main()` before `runApp`, guarded so the app still runs on platforms the
native SDKs don't exist on:

```dart
import 'package:google_maps_places_autocomplete_widgets_native/google_maps_places_autocomplete_widgets_native.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (NativePlaceApiProvider.isSupported) {   // true only on Android/iOS
    await NativePlaceApiProvider.initialize(
      mapsApiKey: kMobileMapsApiKey,          // see Step 4 about keys
      useAppCheck: false,                     // flip in Step 5 (optional)
    );
  }
  runApp(const MyApp());
}
```

## Step 3 — Switch the widgets to the injected provider

Find every `AddressAutocompleteTextField` / `AddressAutocompleteTextFormField`.
Replace the `mapsApiKey:` (and any `apiVersion:`, `androidPackageName:`,
`androidCertSha1Fingerprint:`, `iosBundleId:` parameters — the native path
makes them redundant) with `placeApiProvider:`.

**Mobile-only app** (simplest):

```dart
AddressAutocompleteTextField(
  placeApiProvider: NativePlaceApiProvider(
    componentCountry: 'us',   // carry over the widget's previous
    language: 'en-US',        // componentCountry / language values, if any
  ),
  // ...all other existing parameters stay exactly the same...
)
```

**App that also targets web/desktop** — keep the REST backend there
(`places.googleapis.com` supports CORS on web; use a *separate*
referrer-restricted key):

```dart
AddressAutocompleteTextField(
  mapsApiKey: kWebMapsApiKey,               // used only when provider is null
  placeApiProvider: NativePlaceApiProvider.isSupported
      ? NativePlaceApiProvider(componentCountry: 'us', language: 'en-US')
      : null,                               // null → built-in REST backend
  // ...
)
```

`componentCountry`/`language` move from the widget to the provider's
constructor when the provider is used. All callbacks, styling, `Place`
fields and `type`/`types` filters are unchanged — both backends share the
same parsing code and return identical `Place` objects.

## Step 4 — Restrict the API key (the point of all this)

In [Cloud console → Credentials](https://console.cloud.google.com/apis/credentials)
create (or tighten) the mobile key:

- **Application restrictions → Android apps**: package name + SHA-1 of every
  signing cert (debug AND release/Play-signing).
- **Application restrictions** cannot cover both Android and iOS on one key —
  use one key per platform if you restrict by app, or one key restricted to
  both APIs sets. (Separate Android and iOS keys is Google's recommendation.)
- **API restrictions**: Places API (New) only — plus, if this key also serves
  as the app's Firebase config key, add **Firebase App Check API** and
  **Firebase Installations API** (see gotchas).
- Keep the web/desktop key separate (HTTP-referrer restricted).

Verify: the app works; `curl -X POST https://places.googleapis.com/v1/places:autocomplete
-H "X-Goog-Api-Key: <mobile key>" ...` from a terminal is **rejected**
(`API_KEY_ANDROID_APP_BLOCKED` / equivalent).

## Step 5 (optional but recommended) — Firebase App Check

Follow the App Check walkthrough in the
[native package README](https://pub.dev/packages/google_maps_places_autocomplete_widgets_native).
Condensed, with the gotchas that actually bite:

1. **The Firebase project MUST be the same Google Cloud project that owns the
   Places API key.** Tokens are project-scoped: a mismatch means "Firebase App
   Check token is invalid" under enforcement and permanently empty metrics.
   When creating the Firebase project, *select the existing Cloud project in
   the dropdown* — typing a name creates a new, separate project.
2. Register the Android app (package + SHA-256) and/or iOS app (bundle id) in
   Firebase; download `google-services.json` / `GoogleService-Info.plist` into
   the app (keep them out of public repos).
3. Add `firebase_core` + `firebase_app_check`; before
   `NativePlaceApiProvider.initialize`, run:

   ```dart
   await Firebase.initializeApp();
   await FirebaseAppCheck.instance.activate(
     providerAndroid: kDebugMode
         ? const AndroidDebugProvider()
         : const AndroidPlayIntegrityProvider(),
     providerApple: kDebugMode
         ? const AppleDebugProvider()
         : const AppleAppAttestProvider(),
   );
   ```

   then pass `useAppCheck: true` to `initialize`.
4. Debug builds print a **debug token** UUID on first run — register it in
   Firebase console → App Check → Apps → Manage debug tokens. Debug secrets
   are per-install *per project*; a new one appears if the Firebase project
   changes.
5. If token fetch fails with 403 `ExchangeDebugToken ... blocked`: the API key
   in the Firebase config file has API restrictions missing **Firebase App
   Check API** / **Firebase Installations API** — add them.
6. Watch App Check metrics until real traffic shows as verified, then enable
   **enforcement** for Places API in the Firebase console. Propagation takes
   ~2–8 minutes. Verify the app still works while a raw `curl` with the same
   key gets `401 "Firebase App Check token is invalid"`.
7. Enforcement is project-wide per API: it will also block any REST traffic
   (e.g. this package's REST backend on web) using keys from the same project
   without attestation. If the app has a web build calling Places API (New)
   REST from the same project, do NOT enable enforcement, or serve web through
   a backend proxy instead.

## Verification checklist (run all)

1. `flutter analyze` — clean.
2. `flutter test` — existing widget tests still pass (the widgets' behavior is
   backend-independent; tests using fakes are unaffected).
3. Android device/emulator: type an address → suggestions appear → tap →
   details populate (proves the full native round trip).
4. iOS device/simulator: same.
5. If the app targets web: `flutter run -d chrome` still works via REST.
6. Key restriction negative test (Step 4 curl).
7. If App Check enabled: enforcement negative test (Step 5.6).

## Behavior parity notes

Identical to the core package's Places API (New) REST backend:
`Suggestion.terms` is always `null`; `AutoCompleteType.address` expands to
`street_address` + `premise` + `subpremise` (use `AutoCompleteType.geocode`
for broader matches); billing session tokens are handled natively with the
same autocomplete-then-details session semantics.
