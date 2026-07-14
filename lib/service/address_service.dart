import '/api/legacy_place_api_provider.dart';
import '/api/new_place_api_provider.dart';
import '/api/place_api_provider.dart';
import '/api/places_api_version.dart';
import '/api/autocomplete_types.dart';
import '/model/place.dart';
import '/model/suggestion.dart';

class AddressService {
  AddressService(
    this.sessionToken,
    this.mapsApiKey,
    this.componentCountry,
    this.language, {
    PlacesApiVersion apiVersion = PlacesApiVersion.placesApiNew,
    PlaceApiProvider? placeApiProvider,
    String? androidPackageName,
    String? androidCertSha1Fingerprint,
    String? iosBundleId,
  }) {
    apiClient = placeApiProvider ??
        switch (apiVersion) {
          PlacesApiVersion.legacy => LegacyPlaceApiProvider(
              sessionToken, mapsApiKey, componentCountry, language),
          PlacesApiVersion.placesApiNew => NewPlaceApiProvider(
              sessionToken, mapsApiKey, componentCountry, language,
              androidPackageName: androidPackageName,
              androidCertSha1Fingerprint: androidCertSha1Fingerprint,
              iosBundleId: iosBundleId),
        };
  }

  final String sessionToken;
  final String mapsApiKey;
  final String? componentCountry;
  final String? language;
  late PlaceApiProvider apiClient;

  Future<List<Suggestion>> search(String query,
      {bool includeFullSuggestionDetails = false,
      List<AutoCompleteType> types = const [AutoCompleteType.address]}) async {
    return await apiClient.fetchSuggestions(query,
        includeFullSuggestionDetails: includeFullSuggestionDetails,
        types: types);
  }

  Future<Place> getPlaceDetail(String placeId) async {
    Place placeDetails = await apiClient.getPlaceDetailFromId(placeId);
    return placeDetails;
  }
}
