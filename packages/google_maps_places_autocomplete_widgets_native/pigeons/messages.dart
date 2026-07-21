import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  kotlinOut:
      'android/src/main/kotlin/com/timmaffett/google_maps_places_autocomplete_widgets_native/Messages.g.kt',
  kotlinOptions: KotlinOptions(
      package: 'com.timmaffett.google_maps_places_autocomplete_widgets_native'),
  swiftOut:
      'ios/google_maps_places_autocomplete_widgets_native/Sources/google_maps_places_autocomplete_widgets_native/Messages.g.swift',
  dartPackageName: 'google_maps_places_autocomplete_widgets_native',
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
