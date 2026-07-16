import Flutter
import GooglePlaces
import FirebaseAppCheck

public class PlacesNativePlugin: NSObject, FlutterPlugin, PlacesNativeApi {
  // Session token lives natively: created lazily, consumed by fetchPlace.
  private var sessionToken: GMSAutocompleteSessionToken?
  // Retained so the SDK's weakly-held provider reference stays alive.
  private static var tokenProvider: TokenProvider?

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
      let provider = TokenProvider()
      PlacesNativePlugin.tokenProvider = provider
      GMSPlacesClient.setAppCheckTokenProvider(provider)
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
            primaryText: s.attributedPrimaryText.string,
            secondaryText: s.attributedSecondaryText?.string,
            types: s.types)
      }
      completion(.success(predictions))
    }
  }

  func fetchPlace(placeId: String, languageCode: String?,
                  completion: @escaping (Result<NativePlaceDetails, Error>) -> Void) {
    let properties = [
      GMSPlaceProperty.name, GMSPlaceProperty.formattedAddress,
      GMSPlaceProperty.addressComponents, GMSPlaceProperty.coordinate
    ].map { $0.rawValue }
    let request = GMSFetchPlaceRequest(
        placeID: placeId, placeProperties: properties, sessionToken: sessionToken)
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
