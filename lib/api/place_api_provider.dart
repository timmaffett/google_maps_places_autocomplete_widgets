import '/api/autocomplete_types.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

/// The contract for a Google Places backend used by the autocomplete widgets.
///
/// Two implementations are built in: `LegacyPlaceApiProvider` (legacy Places
/// API) and `NewPlaceApiProvider` (Places API (New)), selected by the
/// widgets' `apiVersion` parameter. Supply your own implementation via the
/// widgets' `placeApiProvider` parameter to use a different backend entirely
/// (a native Places SDK wrapper, a backend proxy that holds your API key
/// server side, or a test fake).
///
/// Implementations must:
///  - return an empty list from [fetchSuggestions] when there are no results
///    (never throw for "no matches");
///  - throw an [Exception] with a human-readable message on API errors;
///  - honor Google billing-session semantics: all [fetchSuggestions] calls
///    for one user interaction share a session token, and
///    [getPlaceDetailFromId] terminates that session.
abstract class PlaceApiProvider {
  /// Returns autocomplete suggestions for [input], restricted to [types].
  ///
  /// [includeFullSuggestionDetails] asks for [Suggestion.mainText],
  /// [Suggestion.secondaryText], [Suggestion.terms] and [Suggestion.types]
  /// to be populated when the backend can supply them. (It is set when the
  /// widget's `onInitialSuggestionClick` callback is in use.)
  Future<List<Suggestion>> fetchSuggestions(String input,
      {bool includeFullSuggestionDetails = false,
      required List<AutoCompleteType> types});

  /// Returns full address details for the suggestion with [placeId].
  Future<Place> getPlaceDetailFromId(String placeId);
}
