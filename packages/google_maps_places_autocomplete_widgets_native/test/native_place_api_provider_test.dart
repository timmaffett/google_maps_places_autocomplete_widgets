import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show BinaryMessenger;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
import 'package:google_maps_places_autocomplete_widgets_native/google_maps_places_autocomplete_widgets_native.dart';
import 'package:google_maps_places_autocomplete_widgets_native/src/messages.g.dart';

class FakeApi implements PlacesNativeApi {
  // Pigeon's generated client class exposes these; unused by the fake.
  @override
  // ignore: non_constant_identifier_names
  BinaryMessenger? get pigeonVar_binaryMessenger => null;
  @override
  // ignore: non_constant_identifier_names
  String get pigeonVar_messageChannelSuffix => '';

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
    calls.add(
        'fetchPredictions:$query:${includedTypes.join('|')}:$countryCode:$languageCode');
    return predictions;
  }

  @override
  Future<NativePlaceDetails> fetchPlace(
      String placeId, String? languageCode) async {
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
    final provider = NativePlaceApiProvider(
        componentCountry: 'us', language: 'en-US', api: api);

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
              types: ['route'],
              longText: 'Eastside Road',
              shortText: 'Eastside Rd'),
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
              types: ['postal_code_suffix'],
              longText: '9406',
              shortText: '9406'),
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
