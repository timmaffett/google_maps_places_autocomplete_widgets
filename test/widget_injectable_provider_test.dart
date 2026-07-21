import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';

class FakePlaceApiProvider extends PlaceApiProvider {
  final List<String> suggestionQueries = [];
  final List<String> detailRequests = [];

  @override
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types}) async {
    suggestionQueries.add(input);
    return [Suggestion('fake-place-id', '123 Fake Street, Springfield')];
  }

  @override
  Future<Place> getPlaceDetailFromId(String placeId) async {
    detailRequests.add(placeId);
    return Place(
        formattedAddress: '123 Fake Street, Springfield',
        city: 'Springfield');
  }
}

void main() {
  testWidgets(
      'injected placeApiProvider drives suggestions and selection end-to-end',
      (tester) async {
    final fake = FakePlaceApiProvider();
    Place? clickedPlace;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressAutocompleteTextField(
          mapsApiKey: 'unused-because-provider-injected',
          placeApiProvider: fake,
          debounceTime: 20,
          onSuggestionClick: (place) => clickedPlace = place,
        ),
      ),
    ));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '123');
    // let the debounce timer fire and the fake future resolve
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(fake.suggestionQueries, ['123']);
    expect(find.text('123 Fake Street, Springfield'), findsOneWidget);

    await tester.tap(find.text('123 Fake Street, Springfield'));
    await tester.pumpAndSettle();

    expect(fake.detailRequests, ['fake-place-id']);
    expect(clickedPlace?.city, 'Springfield');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '123 Fake Street, Springfield');
  });

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
}
