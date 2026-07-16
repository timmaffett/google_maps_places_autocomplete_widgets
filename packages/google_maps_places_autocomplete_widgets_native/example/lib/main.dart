import 'package:flutter/material.dart';
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
import 'package:google_maps_places_autocomplete_widgets_native/google_maps_places_autocomplete_widgets_native.dart';
import 'privatekeys.dart';

// Set true after configuring Firebase (firebase_core + firebase_app_check +
// google-services.json / GoogleService-Info.plist) per the package README.
const useAppCheck = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NativePlaceApiProvider.initialize(
      mapsApiKey: GOOGLE_MAPS_ACCOUNT_API_KEY, useAppCheck: useAppCheck);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Place? _place;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Places Provider Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('Native Places SDK provider')),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Backend: native Places SDK'
                  '${useAppCheck ? " + App Check" : ""}'),
              const SizedBox(height: 12),
              AddressAutocompleteTextField(
                // No mapsApiKey needed: the injected provider owns the key.
                placeApiProvider: NativePlaceApiProvider(
                    componentCountry: 'us', language: 'en-US'),
                onSuggestionClick: (p) => setState(() => _place = p),
                clearButton: const Icon(Icons.close),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), hintText: 'Type an address'),
              ),
              const SizedBox(height: 12),
              Text(_place?.toString() ?? 'Select a suggestion…'),
            ],
          ),
        ),
      ),
    );
  }
}
