# Native Places SDK Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `google_maps_places_autocomplete_widgets_native` — a Pigeon-based Flutter plugin whose `NativePlaceApiProvider` implements the core package's `PlaceApiProvider` via Google's native Places SDKs (Android/iOS), with opt-in Firebase App Check — plus core v2.1.0 making `mapsApiKey` optional when a provider is injected.

**Architecture:** Core 2.1.0 removes the `mapsApiKey: 'unused'` wart first. The new plugin lives in `packages/`, defines one 3-method Pigeon `@HostApi`, manages Places session tokens natively, and reuses the core's `buildPlaceFromComponents`/`mapTypesToNewApi` so results are identical to the REST backends.

**Tech Stack:** Flutter plugin (android+ios), Pigeon codegen, Kotlin + `com.google.android.libraries.places:places` 5.x + Firebase App Check (Android), Swift + `GooglePlaces` pod ≥9.2 + FirebaseAppCheck (iOS).

**Spec:** `doc/superpowers/specs/2026-07-14-native-provider-design.md` — read it first.

## Global Constraints

- Work happens on branch `native-provider` (already created; spec committed there).
- NO `Co-Authored-By` or attribution lines in commit messages.
- Exact names: package `google_maps_places_autocomplete_widgets_native`; Dart class `NativePlaceApiProvider`; Pigeon host API `PlacesNativeApi`; data classes `NativePrediction`, `NativeAddressComponent`, `NativePlaceDetails`.
- Core package stays pure Dart. Plugin declares ONLY android + ios platforms.
- During development the plugin resolves the core package via `pubspec_overrides.yaml` (path override, NOT published); its `pubspec.yaml` declares `google_maps_places_autocomplete_widgets: ^2.1.0`.
- Publishing order (final task only, after device checklist): core 2.1.0 → native 1.0.0.
- Every task ends with `flutter analyze` clean and `flutter test` green — run from the repo root for core tasks, from `packages/google_maps_places_autocomplete_widgets_native/` for plugin tasks — then a commit.
- Native SDK symbols verified 2026-07-14 from Google docs (see spec Sources); each native task still starts by confirming the current stable SDK version numbers.
- Firebase project for App Check testing: Tim's existing project holding the test keys (name/ID in private notes, NOT in repo docs).

## File Structure (end state)

```
lib/…, test/…                                  core 2.1.0 edits            [Task 1]
packages/google_maps_places_autocomplete_widgets_native/
  pubspec.yaml, pubspec_overrides.yaml          plugin manifest             [Task 2]
  pigeons/messages.dart                         Pigeon definitions          [Task 2]
  lib/google_maps_places_autocomplete_widgets_native.dart  barrel           [Task 3]
  lib/src/messages.g.dart                       generated                   [Task 2]
  lib/src/native_place_api_provider.dart        public class                [Task 3]
  test/native_place_api_provider_test.dart      mocked-bridge tests         [Task 3]
  android/…  (build.gradle, Messages.g.kt, Plugin .kt)                      [Task 4]
  ios/…      (podspec, Messages.g.swift, Plugin .swift)                     [Task 5]
  example/…                                     demo app                    [Task 6]
  README.md, CHANGELOG.md, LICENSE                                          [Task 7]
Root README.md, MIGRATION.md, CLAUDE.md         cross-links                 [Task 7]
```

---

### Task 1: Core 2.1.0 — `mapsApiKey` optional when a provider is injected

**Files:**
- Modify: `lib/widgets/address_autocomplete_generic.dart` (abstract member + doc)
- Modify: `lib/widgets/address_autocomplete_textfield.dart`
- Modify: `lib/widgets/address_autocomplete_textformfield.dart`
- Modify: `lib/service/address_service.dart`
- Modify: `test/widget_injectable_provider_test.dart` (add tests)
- Modify: `README.md`, `CHANGELOG.md`, `pubspec.yaml` (version 2.1.0)

**Interfaces:**
- Consumes: existing widgets/service.
- Produces (relied on by Tasks 3/6/7): widgets constructible WITHOUT `mapsApiKey` when `placeApiProvider:` is supplied; `AddressService` first positional param type `String?`.

- [ ] **Step 1: Add failing widget tests**

Append to `test/widget_injectable_provider_test.dart` inside `main()`:

```dart
  testWidgets('mapsApiKey can be omitted when placeApiProvider is supplied',
      (tester) async {
    final fake = FakePlaceApiProvider();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressAutocompleteTextField(
          placeApiProvider: fake,
          debounceTime: 20,
        ),
      ),
    ));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(fake.suggestionQueries, ['123']);
  });

  test('assert fires when neither mapsApiKey nor placeApiProvider supplied',
      () {
    expect(() => AddressAutocompleteTextField(), throwsAssertionError);
    expect(() => AddressAutocompleteTextFormField(), throwsAssertionError);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/widget_injectable_provider_test.dart`
Expected: FAIL — `mapsApiKey` is required / not enough positional arguments.

- [ ] **Step 3: Implement**

1. `address_autocomplete_generic.dart` — change the abstract member and doc:

```dart
  /// Your Google Maps API key. Required unless a custom [placeApiProvider]
  /// is supplied (in which case the built-in backends — and this key — are
  /// not used).
  abstract final String? mapsApiKey;
```

2. Both concrete widgets: field becomes `final String? mapsApiKey;` (keep `@override`); in the constructor change `required this.mapsApiKey,` → `this.mapsApiKey,` and extend the existing assert chain with a NEW leading assert (add as a separate `assert(...)` before the existing one):

```dart
  }) : assert(mapsApiKey != null || placeApiProvider != null,
            'mapsApiKey is required unless a custom placeApiProvider is supplied'),
       assert(
            (postalCodeLookup == true && type == null && types == null) || ...
```

3. `address_service.dart`: `final String? mapsApiKey;` and construct built-ins with `mapsApiKey!` (safe: built-ins are only constructed when `placeApiProvider == null`, and the widget assert guarantees the key in that case — but `AddressService` is also public API, so ALSO add the same assert to its constructor initializer list).

4. `README.md`: in the intro sentence about the only required parameter, add "(or omit it entirely and supply your own `placeApiProvider`)". `CHANGELOG.md`: prepend:

```markdown
## 2.1.0

* `mapsApiKey` is now optional when a custom `placeApiProvider` is supplied
  (previously callers had to pass a dummy value). It remains required for the
  built-in backends (enforced by assert).
```

5. `pubspec.yaml`: `version: 2.1.0`.

- [ ] **Step 4: Verify**

Run: `flutter test` — all pass (33). Run: `flutter analyze` — no issues.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: make mapsApiKey optional when a custom placeApiProvider is supplied (2.1.0)"
```

---

### Task 2: Scaffold the plugin package + Pigeon bridge

**Files:**
- Create: `packages/google_maps_places_autocomplete_widgets_native/` via `flutter create`
- Create/replace: its `pubspec.yaml`, `pubspec_overrides.yaml`, `pigeons/messages.dart`
- Generated: `lib/src/messages.g.dart`, `android/src/main/kotlin/.../Messages.g.kt`, `ios/Classes/Messages.g.swift`

**Interfaces:**
- Produces (used by Tasks 3-5): generated Dart class `PlacesNativeApi` with methods `initialize(String apiKey, bool useAppCheck)`, `fetchPredictions(String query, List<String> includedTypes, String? countryCode, String? languageCode) -> List<NativePrediction>`, `fetchPlace(String placeId, String? languageCode) -> NativePlaceDetails`; generated Kotlin/Swift interfaces of the same shape.

- [ ] **Step 1: Scaffold**

```bash
mkdir packages
flutter create --template=plugin --platforms=android,ios --org com.timmaffett -a kotlin -i swift packages/google_maps_places_autocomplete_widgets_native
```

Delete the template's generated example method-channel cruft: `lib/google_maps_places_autocomplete_widgets_native_method_channel.dart`, `..._platform_interface.dart`, template tests, and the template contents of the main lib file and native classes (they are fully replaced in Tasks 3-5). Keep `example/` (repurposed in Task 6).

- [ ] **Step 2: Write `pubspec.yaml`**

```yaml
name: google_maps_places_autocomplete_widgets_native
description: Native Places SDK (Android/iOS) backend for google_maps_places_autocomplete_widgets — app-restricted API keys and Firebase App Check support.
version: 1.0.0
homepage: https://github.com/timmaffett/google_maps_places_autocomplete_widgets
repository: https://github.com/timmaffett/google_maps_places_autocomplete_widgets/tree/main/packages/google_maps_places_autocomplete_widgets_native
issue_tracker: https://github.com/timmaffett/google_maps_places_autocomplete_widgets/issues

topics:
  - autocomplete
  - google-places
  - app-check
  - places-sdk

environment:
  sdk: ">=3.0.0 <4.0.0"
  flutter: ">=3.3.0"

dependencies:
  flutter:
    sdk: flutter
  google_maps_places_autocomplete_widgets: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  pigeon: ^25.3.0

flutter:
  plugin:
    platforms:
      android:
        package: com.timmaffett.google_maps_places_autocomplete_widgets_native
        pluginClass: PlacesNativePlugin
      ios:
        pluginClass: PlacesNativePlugin
```

And `pubspec_overrides.yaml` (dev-only, never published):

```yaml
dependency_overrides:
  google_maps_places_autocomplete_widgets:
    path: ../../
```

- [ ] **Step 3: Write `pigeons/messages.dart`**

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  kotlinOut:
      'android/src/main/kotlin/com/timmaffett/google_maps_places_autocomplete_widgets_native/Messages.g.kt',
  kotlinOptions: KotlinOptions(
      package: 'com.timmaffett.google_maps_places_autocomplete_widgets_native'),
  swiftOut: 'ios/Classes/Messages.g.swift',
))
class NativePrediction {
  NativePrediction({
    required this.placeId,
    required this.fullText,
    this.primaryText,
    this.secondaryText,
    this.types,
  });
  String placeId;
  String fullText;
  String? primaryText;
  String? secondaryText;
  List<String>? types;
}

class NativeAddressComponent {
  NativeAddressComponent({required this.types, this.longText, this.shortText});
  List<String> types;
  String? longText;
  String? shortText;
}

class NativePlaceDetails {
  NativePlaceDetails({
    this.name,
    this.formattedAddress,
    this.lat,
    this.lng,
    required this.components,
  });
  String? name;
  String? formattedAddress;
  double? lat;
  double? lng;
  List<NativeAddressComponent> components;
}

@HostApi()
abstract class PlacesNativeApi {
  /// Initializes the native Places SDK (New). Safe to call once at startup.
  @async
  void initialize(String apiKey, bool useAppCheck);

  /// Session tokens are managed natively: created lazily on the first call,
  /// reused until [fetchPlace] consumes them.
  @async
  List<NativePrediction> fetchPredictions(String query,
      List<String> includedTypes, String? countryCode, String? languageCode);

  @async
  NativePlaceDetails fetchPlace(String placeId, String? languageCode);
}
```

- [ ] **Step 4: Generate and verify**

```bash
cd packages/google_maps_places_autocomplete_widgets_native
dart pub get
dart run pigeon --input pigeons/messages.dart
flutter analyze
```

Expected: three generated files exist; analyze clean (the barrel/lib file may temporarily just export nothing — put `library;` placeholder if the template file was emptied).

- [ ] **Step 5: Commit**

```bash
git add packages/
git commit -m "feat(native): scaffold plugin package with Pigeon bridge definitions"
```

---

### Task 3: Dart `NativePlaceApiProvider` + mocked-bridge tests

**Files:**
- Create: `lib/src/native_place_api_provider.dart` (in the plugin package)
- Create: `lib/google_maps_places_autocomplete_widgets_native.dart` (barrel)
- Test: `test/native_place_api_provider_test.dart`

**Interfaces:**
- Consumes: generated `PlacesNativeApi`, `NativePrediction`, `NativePlaceDetails`; core's `PlaceApiProvider`, `Suggestion`, `Place`, `buildPlaceFromComponents`, `RawAddressComponent`, `validateAutocompleteTypes`, `mapTypesToNewApi`.
- Produces: `NativePlaceApiProvider` per the spec's public API (static `initialize({required String mapsApiKey, bool useAppCheck = false})`, static `bool get isSupported`, constructor `({String? componentCountry, String? language})`, plus `@visibleForTesting` constructor param `PlacesNativeApi? api` and `@visibleForTesting static void resetForTesting()`).

- [ ] **Step 1: Write failing tests**

`test/native_place_api_provider_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
import 'package:google_maps_places_autocomplete_widgets_native/google_maps_places_autocomplete_widgets_native.dart';
import 'package:google_maps_places_autocomplete_widgets_native/src/messages.g.dart';

class FakeApi implements PlacesNativeApi {
  final calls = <String>[];
  List<NativePrediction> predictions = [];
  NativePlaceDetails? details;
  Object? throwOnFetch;

  @override
  Future<void> initialize(String apiKey, bool useAppCheck) async {
    calls.add('initialize:$apiKey:$useAppCheck');
  }

  @override
  Future<List<NativePrediction>> fetchPredictions(String query,
      List<String> includedTypes, String? countryCode, String? languageCode) async {
    if (throwOnFetch != null) throw throwOnFetch!;
    calls.add('fetchPredictions:$query:${includedTypes.join('|')}:$countryCode:$languageCode');
    return predictions;
  }

  @override
  Future<NativePlaceDetails> fetchPlace(String placeId, String? languageCode) async {
    calls.add('fetchPlace:$placeId:$languageCode');
    return details!;
  }
}

void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    NativePlaceApiProvider.resetForTesting();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('initialize passes key and app-check flag to the bridge', () async {
    final api = FakeApi();
    await NativePlaceApiProvider.initialize(
        mapsApiKey: 'k1', useAppCheck: true, api: api);
    expect(api.calls, ['initialize:k1:true']);
  });

  test('fetchSuggestions maps predictions and expands the address type',
      () async {
    final api = FakeApi()
      ..predictions = [
        NativePrediction(
            placeId: 'p1',
            fullText: '678 North Market Street, Redding, CA, USA',
            primaryText: '678 North Market Street',
            secondaryText: 'Redding, CA, USA',
            types: ['premise', 'geocode']),
      ];
    await NativePlaceApiProvider.initialize(mapsApiKey: 'k', api: api);
    final provider =
        NativePlaceApiProvider(componentCountry: 'us', language: 'en-US', api: api);

    final simple = await provider
        .fetchSuggestions('678', types: [AutoCompleteType.address]);
    expect(api.calls.last,
        'fetchPredictions:678:street_address|premise|subpremise:us:en-US');
    expect(simple.single.placeId, 'p1');
    expect(simple.single.mainText, isNull); // full details not requested

    final full = await provider.fetchSuggestions('678',
        includeFullSuggestionDetails: true, types: [AutoCompleteType.address]);
    expect(full.single.mainText, '678 North Market Street');
    expect(full.single.secondaryText, 'Redding, CA, USA');
    expect(full.single.types, ['premise', 'geocode']);
    expect(full.single.terms, isNull);
  });

  test('type validation throws before crossing the bridge', () async {
    final api = FakeApi();
    await NativePlaceApiProvider.initialize(mapsApiKey: 'k', api: api);
    final provider = NativePlaceApiProvider(api: api);
    await expectLater(
        provider.fetchSuggestions('x',
            types: [AutoCompleteType.cities, AutoCompleteType.bookStore]),
        throwsException);
    expect(api.calls.where((c) => c.startsWith('fetchPredictions')), isEmpty);
  });

  test('getPlaceDetailFromId maps components to an identical Place', () async {
    final api = FakeApi()
      ..details = NativePlaceDetails(
        name: '6781 Eastside Rd',
        formattedAddress: '6781 Eastside Rd, Anderson, CA 96007, USA',
        lat: 40.4839756,
        lng: -122.34802,
        components: [
          NativeAddressComponent(
              types: ['street_number'], longText: '6781', shortText: '6781'),
          NativeAddressComponent(
              types: ['route'], longText: 'Eastside Road', shortText: 'Eastside Rd'),
          NativeAddressComponent(
              types: ['locality', 'political'],
              longText: 'Anderson',
              shortText: 'Anderson'),
          NativeAddressComponent(
              types: ['administrative_area_level_1', 'political'],
              longText: 'California',
              shortText: 'CA'),
          NativeAddressComponent(
              types: ['postal_code'], longText: '96007', shortText: '96007'),
          NativeAddressComponent(
              types: ['postal_code_suffix'], longText: '9406', shortText: '9406'),
        ],
      );
    await NativePlaceApiProvider.initialize(mapsApiKey: 'k', api: api);
    final provider = NativePlaceApiProvider(api: api);

    final place = await provider.getPlaceDetailFromId('p1');
    expect(place.name, '6781 Eastside Rd');
    expect(place.city, 'Anderson');
    expect(place.stateShort, 'CA');
    expect(place.zipCodePlus4, '96007-9406');
    expect(place.lat, 40.4839756);
  });

  test('fetch before initialize throws StateError', () async {
    final provider = NativePlaceApiProvider(api: FakeApi());
    await expectLater(
        provider.fetchSuggestions('x', types: [AutoCompleteType.address]),
        throwsStateError);
  });

  test('unsupported platform throws UnsupportedError', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(NativePlaceApiProvider.isSupported, isFalse);
    final provider = NativePlaceApiProvider(api: FakeApi());
    await expectLater(
        provider.fetchSuggestions('x', types: [AutoCompleteType.address]),
        throwsUnsupportedError);
  });

  test('native errors surface as Exception', () async {
    final api = FakeApi()..throwOnFetch = Exception('SDK says no');
    await NativePlaceApiProvider.initialize(mapsApiKey: 'k', api: api);
    final provider = NativePlaceApiProvider(api: api);
    await expectLater(
        provider.fetchSuggestions('x', types: [AutoCompleteType.address]),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'msg', contains('SDK says no'))));
  });
}
```

- [ ] **Step 2: Run to verify failure** — `flutter test` (from the package dir). Expected: compile errors (provider missing).

- [ ] **Step 3: Implement `lib/src/native_place_api_provider.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
import 'package:google_maps_places_autocomplete_widgets/api/new_api_type_mapping.dart';
import 'package:google_maps_places_autocomplete_widgets/api/place_api_provider.dart';
import 'package:google_maps_places_autocomplete_widgets/api/place_builder.dart';
import 'package:google_maps_places_autocomplete_widgets/model/place.dart';
import 'package:google_maps_places_autocomplete_widgets/model/suggestion.dart';

import 'messages.g.dart';

/// [PlaceApiProvider] backed by Google's native Places SDKs (Android/iOS).
///
/// Compared to the core package's REST backend this enables:
///  - app-restricted API keys with zero header configuration, and
///  - Firebase App Check attestation ([initialize] with `useAppCheck: true`),
///    which — with enforcement turned on — makes a scraped key useless
///    outside your genuine app.
///
/// Only Android and iOS are supported ([isSupported]); use the core REST
/// backend on web/desktop. Billing session tokens are managed natively.
class NativePlaceApiProvider extends PlaceApiProvider {
  NativePlaceApiProvider(
      {this.componentCountry, this.language, @visibleForTesting PlacesNativeApi? api})
      : _api = api ?? _sharedApi ?? PlacesNativeApi();

  final String? componentCountry;
  final String? language;
  final PlacesNativeApi _api;

  static PlacesNativeApi? _sharedApi;
  static bool _initialized = false;

  /// True on Android and iOS (the platforms the native Places SDKs exist on).
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initializes the native Places SDK (New) with [mapsApiKey]. Call once
  /// (e.g. in main()) before constructing providers. With [useAppCheck] the
  /// SDKs' Firebase App Check token providers are installed — the host app
  /// must have configured firebase_core + firebase_app_check first.
  static Future<void> initialize(
      {required String mapsApiKey,
      bool useAppCheck = false,
      @visibleForTesting PlacesNativeApi? api}) async {
    _ensureSupportedPlatform();
    _sharedApi = api ?? PlacesNativeApi();
    await _sharedApi!.initialize(mapsApiKey, useAppCheck);
    _initialized = true;
  }

  @visibleForTesting
  static void resetForTesting() {
    _sharedApi = null;
    _initialized = false;
  }

  static void _ensureSupportedPlatform() {
    if (!isSupported) {
      throw UnsupportedError(
          'NativePlaceApiProvider is only available on Android and iOS. '
          'On other platforms use the core package\'s default REST backend.');
    }
  }

  void _ensureReady() {
    _ensureSupportedPlatform();
    if (!_initialized) {
      throw StateError(
          'Call NativePlaceApiProvider.initialize(mapsApiKey: ...) before use.');
    }
  }

  @override
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types}) async {
    _ensureReady();
    validateAutocompleteTypes(types);
    final predictions = await _api.fetchPredictions(
        input, mapTypesToNewApi(types), componentCountry, language);
    return [
      for (final p in predictions)
        if (includeFullSuggestionDetails)
          Suggestion(p.placeId, p.fullText,
              mainText: p.primaryText,
              secondaryText: p.secondaryText,
              // The native SDKs have no equivalent of the legacy `terms`.
              terms: null,
              types: p.types?.whereType<String>().toList())
        else
          Suggestion(p.placeId, p.fullText),
    ];
  }

  @override
  Future<Place> getPlaceDetailFromId(String placeId) async {
    _ensureReady();
    final d = await _api.fetchPlace(placeId, language);
    return buildPlaceFromComponents(
      components: [
        for (final c in d.components)
          RawAddressComponent(
              types: c.types.whereType<String>().toList(),
              longText: c.longText,
              shortText: c.shortText),
      ],
      name: d.name,
      formattedAddress: d.formattedAddress,
      lat: d.lat,
      lng: d.lng,
    );
  }
}
```

Barrel `lib/google_maps_places_autocomplete_widgets_native.dart`:

```dart
export 'src/native_place_api_provider.dart';
```

Note: if the generated `PlacesNativeApi` is not directly implementable (Pigeon generates it as a concrete class with a `BinaryMessenger` constructor — it IS implementable via `implements`), the FakeApi in tests uses `implements PlacesNativeApi`, which works with Pigeon's generated Dart client class.

- [ ] **Step 4: Verify** — `flutter test` and `flutter analyze` from the package dir: all pass, no issues.

- [ ] **Step 5: Commit**

```bash
git add packages/
git commit -m "feat(native): NativePlaceApiProvider with mocked-bridge unit tests"
```

---

### Task 4: Android implementation (Kotlin)

**Files:**
- Modify: `packages/.../android/build.gradle` (dependencies, minSdk 24)
- Create/replace: `packages/.../android/src/main/kotlin/com/timmaffett/google_maps_places_autocomplete_widgets_native/PlacesNativePlugin.kt`

**Interfaces:**
- Consumes: generated Kotlin `PlacesNativeApi` interface + data classes from `Messages.g.kt`.
- Produces: working Android host implementation registered in `onAttachedToEngine`.

- [ ] **Step 1: Confirm current stable versions** — check https://developers.google.com/maps/documentation/places/android-sdk/release-notes for the latest `places` 5.x artifact and the Firebase BoM; use those numbers below (plan written against `places:5.1.1`).

- [ ] **Step 2: `android/build.gradle` dependencies + minSdk**

```gradle
android {
    ...
    defaultConfig { minSdkVersion 24 }
}
dependencies {
    implementation 'com.google.android.libraries.places:places:5.1.1'
    implementation platform('com.google.firebase:firebase-bom:34.0.0')
    implementation 'com.google.firebase:firebase-appcheck'
    implementation 'com.google.guava:guava:33.0.0-android'
}
```

- [ ] **Step 3: `PlacesNativePlugin.kt`**

```kotlin
package com.timmaffett.google_maps_places_autocomplete_widgets_native

import android.content.Context
import com.google.android.gms.tasks.Task
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.PlacesClient
import com.google.android.libraries.places.api.net.PlacesAppCheckTokenProvider
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.SettableFuture
import com.google.firebase.appcheck.FirebaseAppCheck
import io.flutter.embedding.engine.plugins.FlutterPlugin

class PlacesNativePlugin : FlutterPlugin, PlacesNativeApi {
  private lateinit var context: Context
  private var client: PlacesClient? = null
  // Session token lives natively: created lazily, consumed by fetchPlace.
  private var sessionToken: AutocompleteSessionToken? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    PlacesNativeApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    PlacesNativeApi.setUp(binding.binaryMessenger, null)
  }

  override fun initialize(apiKey: String, useAppCheck: Boolean, callback: (Result<Unit>) -> Unit) {
    try {
      Places.initializeWithNewPlacesApiEnabled(context, apiKey)
      if (useAppCheck) {
        Places.setPlacesAppCheckTokenProvider(FirebaseTokenProvider())
      }
      client = Places.createClient(context)
      callback(Result.success(Unit))
    } catch (e: Exception) {
      callback(Result.failure(e))
    }
  }

  private class FirebaseTokenProvider : PlacesAppCheckTokenProvider {
    override fun fetchAppCheckToken(): ListenableFuture<String> {
      val future = SettableFuture.create<String>()
      FirebaseAppCheck.getInstance()
          .getAppCheckToken(false)
          .addOnSuccessListener { future.set(it.token) }
          .addOnFailureListener { future.setException(it) }
      return future
    }
  }

  override fun fetchPredictions(
      query: String,
      includedTypes: List<String>,
      countryCode: String?,
      languageCode: String?,
      callback: (Result<List<NativePrediction>>) -> Unit
  ) {
    val c = client ?: return callback(Result.failure(IllegalStateException("Places not initialized")))
    if (sessionToken == null) sessionToken = AutocompleteSessionToken.newInstance()
    val builder = FindAutocompletePredictionsRequest.builder()
        .setQuery(query)
        .setSessionToken(sessionToken)
        .setTypesFilter(includedTypes)
    if (countryCode != null) builder.setCountries(listOf(countryCode))
    c.findAutocompletePredictions(builder.build())
        .addOnSuccessListener { response ->
          callback(Result.success(response.autocompletePredictions.map { p ->
            NativePrediction(
                placeId = p.placeId,
                fullText = p.getFullText(null).toString(),
                primaryText = p.getPrimaryText(null).toString(),
                secondaryText = p.getSecondaryText(null).toString(),
                types = p.types)   // List<String> on new SDK; use p.placeTypes.map{it.name} if absent
          }))
        }
        .addOnFailureListener { callback(Result.failure(it)) }
  }

  override fun fetchPlace(
      placeId: String,
      languageCode: String?,
      callback: (Result<NativePlaceDetails>) -> Unit
  ) {
    val c = client ?: return callback(Result.failure(IllegalStateException("Places not initialized")))
    val fields = listOf(
        Place.Field.DISPLAY_NAME, Place.Field.FORMATTED_ADDRESS,
        Place.Field.ADDRESS_COMPONENTS, Place.Field.LOCATION)
    val request = FetchPlaceRequest.builder(placeId, fields)
        .setSessionToken(sessionToken)
        .build()
    sessionToken = null  // details call terminates the billing session
    c.fetchPlace(request)
        .addOnSuccessListener { response ->
          val place = response.place
          callback(Result.success(NativePlaceDetails(
              name = place.displayName,
              formattedAddress = place.formattedAddress,
              lat = place.location?.latitude,
              lng = place.location?.longitude,
              components = place.addressComponents?.asList()?.map {
                NativeAddressComponent(
                    types = it.types, longText = it.name, shortText = it.shortName)
              } ?: emptyList())))
        }
        .addOnFailureListener { callback(Result.failure(it)) }
  }
}
```

(If `Place.Field.DISPLAY_NAME`/`LOCATION`/`place.displayName`/`place.location` don't exist in the pinned SDK version, use the pre-rename names `NAME`/`LAT_LNG`/`place.name`/`place.latLng` — one or the other set compiles, never both. Same for `p.types` vs `p.placeTypes`.)

- [ ] **Step 4: Verify it compiles** — from `packages/.../example`: `flutter build apk --debug`. Expected: BUILD SUCCESSFUL. (The example app is still template-ish until Task 6; it just needs to compile the plugin.)

- [ ] **Step 5: Commit**

```bash
git add packages/
git commit -m "feat(native): Android implementation via Places SDK (New) with App Check provider"
```

---

### Task 5: iOS implementation (Swift)

**Files:**
- Modify: `packages/.../ios/google_maps_places_autocomplete_widgets_native.podspec` (deps, platform floor)
- Create/replace: `packages/.../ios/Classes/PlacesNativePlugin.swift`

**Interfaces:**
- Consumes: generated Swift `PlacesNativeApi` protocol + data classes from `Messages.g.swift`.
- Produces: working iOS host implementation.

- [ ] **Step 1: Confirm current stable GooglePlaces pod version** (≥9.2 required for App Check) and its iOS floor; pin below (plan written against `~> 9.4`, iOS 15).

- [ ] **Step 2: Podspec**

```ruby
  s.platform = :ios, '15.0'
  s.dependency 'Flutter'
  s.dependency 'GooglePlaces', '~> 9.4'
  s.dependency 'FirebaseAppCheck'
  s.static_framework = true
```

- [ ] **Step 3: `PlacesNativePlugin.swift`**

```swift
import Flutter
import GooglePlaces
import FirebaseAppCheck

public class PlacesNativePlugin: NSObject, FlutterPlugin, PlacesNativeApi {
  private var sessionToken: GMSAutocompleteSessionToken?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PlacesNativePlugin()
    PlacesNativeApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  class TokenProvider: NSObject, GMSPlacesAppCheckTokenProvider {
    func fetchAppCheckToken() async throws -> String {
      return try await AppCheck.appCheck().token(forcingRefresh: false).token
    }
  }

  func initialize(apiKey: String, useAppCheck: Bool,
                  completion: @escaping (Result<Void, Error>) -> Void) {
    GMSPlacesClient.provideAPIKey(apiKey)
    if useAppCheck {
      GMSPlacesClient.setAppCheckTokenProvider(TokenProvider())
    }
    completion(.success(()))
  }

  func fetchPredictions(query: String, includedTypes: [String],
                        countryCode: String?, languageCode: String?,
                        completion: @escaping (Result<[NativePrediction], Error>) -> Void) {
    if sessionToken == nil { sessionToken = GMSAutocompleteSessionToken() }
    let filter = GMSAutocompleteFilter()
    filter.types = includedTypes
    if let country = countryCode { filter.countries = [country] }
    let request = GMSAutocompleteRequest(query: query)
    request.filter = filter
    request.sessionToken = sessionToken
    GMSPlacesClient.shared().fetchAutocompleteSuggestions(from: request) { results, error in
      if let error = error { return completion(.failure(error)) }
      let predictions: [NativePrediction] = (results ?? []).compactMap { r in
        guard let s = r.placeSuggestion else { return nil }
        return NativePrediction(
            placeId: s.placeID,
            fullText: s.attributedFullText.string,
            primaryText: s.attributedPrimaryText?.string,
            secondaryText: s.attributedSecondaryText?.string,
            types: s.types)
      }
      completion(.success(predictions))
    }
  }

  func fetchPlace(placeId: String, languageCode: String?,
                  completion: @escaping (Result<NativePlaceDetails, Error>) -> Void) {
    let request = GMSFetchPlaceRequest(placeID: placeId)
    request.sessionToken = sessionToken
    request.placeProperties = [
      GMSPlaceProperty.displayName, GMSPlaceProperty.formattedAddress,
      GMSPlaceProperty.addressComponents, GMSPlaceProperty.coordinate
    ].map { $0.rawValue }
    sessionToken = nil  // details call terminates the billing session
    GMSPlacesClient.shared().fetchPlace(with: request) { place, error in
      if let error = error { return completion(.failure(error)) }
      guard let place = place else {
        return completion(.failure(NSError(domain: "PlacesNative", code: 404)))
      }
      let components = (place.addressComponents ?? []).map { c in
        NativeAddressComponent(types: c.types, longText: c.name, shortText: c.shortName)
      }
      completion(.success(NativePlaceDetails(
          name: place.name,
          formattedAddress: place.formattedAddress,
          lat: place.coordinate.latitude,
          lng: place.coordinate.longitude,
          components: components)))
    }
  }
}
```

(Adjust exact generated protocol/setup names — `PlacesNativeApiSetup`, completion `Result` shapes — to whatever `Messages.g.swift` produces; Pigeon's Swift output naming is stable but version-dependent.)

- [ ] **Step 4: Verify it compiles** — needs a Mac. On this Windows machine: `flutter analyze` + `dart pub publish --dry-run` from the package (structure checks). Actual `flutter build ios` compile check happens in the Task 8 device checklist on Tim's Mac/device — flagged as a HOLD-point, not skipped silently.

- [ ] **Step 5: Commit**

```bash
git add packages/
git commit -m "feat(native): iOS implementation via GooglePlaces SDK with App Check provider"
```

---

### Task 6: Example app

**Files:**
- Replace: `packages/.../example/lib/main.dart`
- Create: `packages/.../example/lib/privatekeys.dart.template` + `.gitignore` entry for `lib/privatekeys.dart`

**Interfaces:** consumes core widgets + `NativePlaceApiProvider`.

- [ ] **Step 1: Write the example**

`example/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
import 'package:google_maps_places_autocomplete_widgets_native/google_maps_places_autocomplete_widgets_native.dart';
import 'privatekeys.dart';

// Set true after configuring Firebase (firebase_core + firebase_app_check +
// google-services.json / GoogleService-Info.plist) per the package README.
const useAppCheck = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativePlaceApiProvider.initialize(
      mapsApiKey: GOOGLE_MAPS_ACCOUNT_API_KEY, useAppCheck: useAppCheck);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Place? _place;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Places Provider Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Native Places SDK provider')),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backend: native Places SDK'
                  '${useAppCheck ? " + App Check" : ""}'),
              const SizedBox(height: 12),
              AddressAutocompleteTextField(
                // No mapsApiKey needed: the injected provider owns the key.
                placeApiProvider: NativePlaceApiProvider(
                    componentCountry: 'us', language: 'en-US'),
                onSuggestionClick: (p) => setState(() => _place = p),
                clearButton: const Icon(Icons.close),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), hintText: 'Type an address'),
              ),
              const SizedBox(height: 12),
              Text(_place?.toString() ?? 'Select a suggestion…'),
            ],
          ),
        ),
      ),
    );
  }
}
```

`example/lib/privatekeys.dart.template` (tracked) with
`const GOOGLE_MAPS_ACCOUNT_API_KEY = 'PUT-YOUR-KEY-HERE';` and a comment to copy to
`privatekeys.dart`; add `lib/privatekeys.dart` to `example/.gitignore`. Example pubspec:
path deps on both packages (`../` for the plugin, override for core via
`pubspec_overrides.yaml` pointing at `../../../`).

- [ ] **Step 2: Verify** — `flutter analyze` in package; `flutter build apk --debug` in example (with template key copied). Expected: builds.

- [ ] **Step 3: Commit**

```bash
git add packages/
git commit -m "feat(native): example app driving core widgets through the native provider"
```

---

### Task 7: Documentation

**Files:**
- Create: package `README.md`, `CHANGELOG.md`; copy root `LICENSE`
- Modify: root `README.md`, `MIGRATION.md`, `CLAUDE.md`

- [ ] **Step 1: Package README** — sections, all fully written (no stubs): What/why (security tiers table from MIGRATION.md, tier 3 = this package); Quick start (initialize + inject, no mapsApiKey); Android setup (minSdk 24); iOS setup (iOS floor, pod install); **Firebase App Check walkthrough** (create/reuse Firebase project → register Android app w/ SHA-256 + iOS app → add config files → add firebase_core/firebase_app_check → Play Integrity/App Attest providers → monitor metrics → enable enforcement in Cloud console → verify a raw curl with the key now fails); Platform support matrix; Limitations (`Suggestion.terms` null; `AutoCompleteType.address` expansion — same as core's new REST backend).

- [ ] **Step 2: Package CHANGELOG**

```markdown
## 1.0.0

* Initial release: NativePlaceApiProvider — a PlaceApiProvider for
  google_maps_places_autocomplete_widgets backed by the native Places SDKs
  (Android 5.x / iOS 9.x), with app-restricted API key support and opt-in
  Firebase App Check attestation.
```

- [ ] **Step 3: Root cross-links** — root README "Key security" feature bullet gains link to the native package; MIGRATION.md tier 3 links to it; CLAUDE.md gains a "Repo layout" note (two packages, packages/ dir, pubspec_overrides for local dev, publish order core-then-native).

- [ ] **Step 4: Verify + commit**

```bash
flutter analyze   # both packages
git add -A
git commit -m "docs(native): package README with App Check walkthrough; cross-link from core docs"
```

---

### Task 8: Verification, PR, and release — HOLD points for Tim

- [ ] **Step 1: Full local verification** — root: `flutter test` (33) + `flutter analyze`; package: `flutter test` + `flutter analyze`; both: `dart pub publish --dry-run` (expect the core clean; the plugin clean except the expected "pubspec_overrides" note if any).

- [ ] **Step 2: Push + PR** — push `native-provider`, open PR (explicit `--repo timmaffett/...` — remember the `upstream` remote gotcha), body summarizing core 2.1.0 + the new package + test status.

- [ ] **Step 3: MANUAL DEVICE CHECKLIST (Tim + Claude together — do not publish before this passes):**
  1. Android device/emulator: example app predictions + details round trip.
  2. iOS device/simulator (needs a Mac): same, and confirms the Swift side compiles.
  3. Android-app-restricted key (package name + SHA-1 registered in Cloud console): works with zero header config.
  4. App Check with Tim's Firebase project: register apps, flip `useAppCheck = true`, see tokens in Firebase console metrics; enable enforcement; app still works while `curl` with the same key gets `PERMISSION_DENIED`.
- [ ] **Step 4: Merge PR** (after checklist), tag `v2.1.0`.
- [ ] **Step 5: Publish core 2.1.0** (`dart pub publish --force` from root), then **publish native 1.0.0** (from the package dir; confirm `pubspec_overrides.yaml` is not in the upload listing), tag `native-v1.0.0`.

---

## Deferred (out of scope)

Query predictions, locationBias/origin/distance on the native path, macOS (the iOS SDK technically has no macOS variant), a Firebase-free plugin variant, exposing App Check to the REST backend (not supported by Google).
