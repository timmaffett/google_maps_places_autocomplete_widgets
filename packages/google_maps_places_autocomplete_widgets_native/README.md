# google_maps_places_autocomplete_widgets_native

Native Places SDK (Android/iOS) backend for
[`google_maps_places_autocomplete_widgets`](https://pub.dev/packages/google_maps_places_autocomplete_widgets).
It provides `NativePlaceApiProvider`, a drop-in
[`PlaceApiProvider`](https://pub.dev/documentation/google_maps_places_autocomplete_widgets/latest/)
that routes autocomplete/details calls through Google's **native Places SDKs**
instead of REST — unlocking the two strongest client-side key protections:

- **App-restricted API keys with zero configuration** — the native SDKs
  automatically attach your app's package name / SHA-1 (Android) or bundle id
  (iOS), so keys restricted to your app in the Cloud console just work. No
  spoofable HTTP headers involved.
- **Firebase App Check attestation (opt-in)** — Play Integrity / App Attest
  tokens accompany every Places request. With enforcement enabled in the
  Cloud console, a scraped API key becomes useless outside your genuine app.

## Where this fits (key-security tiers)

| Tier | Approach | Protection |
|------|----------|-----------|
| 1 | Core package REST + `androidPackageName`/`iosBundleId` headers | Deterrent only — headers are public info and spoofable |
| 2 | **This package** (native SDK, app-restricted key) | Restriction checked by Google from SDK-attached app identity |
| 3 | **This package + App Check enforcement** | Cryptographic app attestation; scraped keys stop working |
| 4 | Backend proxy holding the key server-side | Strongest; key never ships in the app |

Use the core package alone for web/desktop (the native SDKs only exist on
Android and iOS — check `NativePlaceApiProvider.isSupported`).

## Quick start

```yaml
dependencies:
  google_maps_places_autocomplete_widgets: ^2.1.0
  google_maps_places_autocomplete_widgets_native: ^1.0.0
```

```dart
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
import 'package:google_maps_places_autocomplete_widgets_native/google_maps_places_autocomplete_widgets_native.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativePlaceApiProvider.initialize(
    mapsApiKey: 'YOUR-ANDROID/IOS-RESTRICTED-KEY',
    useAppCheck: false, // true after the App Check walkthrough below
  );
  runApp(const MyApp());
}

// Then anywhere in your widget tree — note: no mapsApiKey parameter needed,
// the provider owns the key (requires core >= 2.1.0):
AddressAutocompleteTextField(
  placeApiProvider: NativePlaceApiProvider(
    componentCountry: 'us',
    language: 'en-US',
  ),
  onSuggestionClick: (place) => print(place.formattedAddress),
)
```

Everything else about the widgets (callbacks, styling, `Place` fields,
`type`/`types` filters) is identical to the core package — the same shared
mapping code parses results, so both backends return identical `Place`
objects.

## Android setup

- `minSdkVersion 24` or higher.
- Your API key should be **application-restricted** to your Android app
  (package name + SHA-1) and **API-restricted** to "Places API (New)" in the
  [Cloud console credentials page](https://console.cloud.google.com/apis/credentials).
- No manifest changes needed — the key is supplied at runtime via
  `NativePlaceApiProvider.initialize`.

## iOS setup

- iOS 16+ (floor of the GooglePlaces 10.x SDK).
- CocoaPods: `pod install` picks up `GooglePlaces` automatically. Swift
  Package Manager builds are also supported.
- Restrict your key to your iOS bundle id + "Places API (New)".

## Firebase App Check walkthrough (recommended)

App Check is why this package exists: with enforcement on, Places API calls
require a valid attestation token from *your genuine app*, so a key scraped
from your binary or network traffic is worthless. Steps:

1. **Create (or reuse) a Firebase project** at
   [console.firebase.google.com](https://console.firebase.google.com), linked
   to the same Google Cloud project that owns your Places API key.
2. **Register your apps**: add your Android app (package name **and SHA-256**
   fingerprint) and your iOS app (bundle id).
3. **Add the config files** to your host app: `android/app/google-services.json`
   and `ios/Runner/GoogleService-Info.plist`.
4. **Add the Firebase Flutter plugins** to your app:

   ```yaml
   dependencies:
     firebase_core: ^4.0.0
     firebase_app_check: ^0.4.0
   ```

5. **Activate App Check providers** before initializing the Places provider:

   ```dart
   await Firebase.initializeApp();
   await FirebaseAppCheck.instance.activate(
     androidProvider: AndroidProvider.playIntegrity,
     appleProvider: AppleProvider.appAttest,
   );
   await NativePlaceApiProvider.initialize(
     mapsApiKey: yourKey,
     useAppCheck: true,
   );
   ```

6. **Register Places API with App Check** in the Firebase console
   (App Check → APIs → Places API) and **monitor metrics** until you see your
   real traffic attested.
7. **Enable enforcement** for Places API in the Firebase console once metrics
   look healthy.
8. **Verify**: a raw `curl` against `places.googleapis.com` with your key
   should now be rejected, while your app keeps working.

Debug builds: use `AndroidProvider.debug` / `AppleProvider.debug` and add the
printed debug token in the Firebase console (App Check → Apps → Manage debug
tokens), otherwise emulator/simulator traffic is rejected once enforcement is
on.

## Platform support

| Platform | Supported | Notes |
|----------|-----------|-------|
| Android  | ✅ (minSdk 24) | Places SDK (New) 5.x |
| iOS      | ✅ (iOS 16+) | GooglePlaces SDK 10.x |
| Web / desktop | ❌ | Use the core package's REST backend (`isSupported` is `false`) |

## Limitations

Same parity notes as the core package's Places API (New) REST backend:

- `Suggestion.terms` is always `null` (no native SDK equivalent).
- `AutoCompleteType.address` is expanded to
  `street_address` + `premise` + `subpremise` (the new Places API has no
  `address` collection); use `AutoCompleteType.geocode` for broader matches.
- The `language` parameter affects the details request per the device SDK's
  locale rules; the native SDKs primarily follow the device locale.

## Development notes

Billing session tokens are managed natively: one
`AutocompleteSessionToken`/`GMSAutocompleteSessionToken` is created lazily on
the first prediction request and consumed (discarded) by the details fetch —
matching Google's billing-session semantics exactly like the core backends.
