import Flutter
import UIKit

public class GoogleMapsPlacesAutocompleteWidgetsNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "google_maps_places_autocomplete_widgets_native", binaryMessenger: registrar.messenger())
    let instance = GoogleMapsPlacesAutocompleteWidgetsNativePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
