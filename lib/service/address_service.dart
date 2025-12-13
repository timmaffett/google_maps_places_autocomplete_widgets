import '/api/place_api_provider.dart';
import '/api/autocomplete_types.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

class AddressService {
  AddressService(this.sessionToken, this.mapsApiKey, this.componentCountry,
      this.language) {
    apiClient =
        PlaceApiProvider(sessionToken, mapsApiKey, componentCountry, language);
  }

  final String sessionToken;
  final String mapsApiKey;
  final String? componentCountry;
  final String? language;
  late PlaceApiProvider apiClient;

  Future<List<Suggestion>> search(String query,
      {bool includeFullSuggestionDetails = false,
      List<AutoCompleteType> types = const [AutoCompleteType.address],
      String? proxyUrl}) async {
    return await apiClient.fetchSuggestions(
      query,
      includeFullSuggestionDetails: includeFullSuggestionDetails,
      types: types,
      proxyUrl: proxyUrl,
    );
  }

  Future<Place> getPlaceDetail(String placeId, {String? proxyUrl}) async {
    Place placeDetails = await apiClient.getPlaceDetailFromId(
      placeId,
      proxyUrl: proxyUrl,
    );
    return placeDetails;
  }
}
