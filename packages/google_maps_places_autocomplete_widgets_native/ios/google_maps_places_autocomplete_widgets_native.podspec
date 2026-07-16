#
# Native Places SDK backend plugin for google_maps_places_autocomplete_widgets.
# Run `pod lib lint google_maps_places_autocomplete_widgets_native.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'google_maps_places_autocomplete_widgets_native'
  s.version          = '1.0.0'
  s.summary          = 'Native Places SDK backend for google_maps_places_autocomplete_widgets.'
  s.description      = <<-DESC
Native Places SDK (iOS) backend for the google_maps_places_autocomplete_widgets
Flutter package — app-restricted API keys and Firebase App Check support.
                       DESC
  s.homepage         = 'https://github.com/timmaffett/google_maps_places_autocomplete_widgets'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Tim Maffett' => 'timmaffett@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'google_maps_places_autocomplete_widgets_native/Sources/google_maps_places_autocomplete_widgets_native/**/*.swift'
  s.dependency 'Flutter'
  s.dependency 'GooglePlaces', '~> 10.0'
  s.dependency 'FirebaseAppCheck'
  s.static_framework = true
  s.platform = :ios, '16.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {'google_maps_places_autocomplete_widgets_native_privacy' => ['google_maps_places_autocomplete_widgets_native/Sources/google_maps_places_autocomplete_widgets_native/PrivacyInfo.xcprivacy']}
end
