// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "google_maps_places_autocomplete_widgets_native",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "google-maps-places-autocomplete-widgets-native", targets: ["google_maps_places_autocomplete_widgets_native"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/googlemaps/ios-places-sdk", from: "10.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "12.0.0")
    ],
    targets: [
        .target(
            name: "google_maps_places_autocomplete_widgets_native",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "GooglePlaces", package: "ios-places-sdk"),
                .product(name: "FirebaseAppCheck", package: "firebase-ios-sdk")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
