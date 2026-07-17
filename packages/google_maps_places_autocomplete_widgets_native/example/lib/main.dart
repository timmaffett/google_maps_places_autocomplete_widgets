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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Places Provider Demo',
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('Native Places SDK provider'
                '${useAppCheck ? " + App Check" : ""}'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'TextField'),
                Tab(text: 'Form (TextFormField)'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              SimpleTextFieldExample(),
              FormFillExample(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal demo: one autocomplete field, dumps the selected [Place].
class SimpleTextFieldExample extends StatefulWidget {
  const SimpleTextFieldExample({super.key});
  @override
  State<SimpleTextFieldExample> createState() => _SimpleTextFieldExampleState();
}

class _SimpleTextFieldExampleState extends State<SimpleTextFieldExample> {
  Place? _place;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    );
  }
}

/// Form demo (mirrors the core package's example): the address
/// [AddressAutocompleteTextFormField] fills the City/State/Zip fields from
/// the selected suggestion's [Place] details, and the clear button empties
/// the whole form.
class FormFillExample extends StatefulWidget {
  const FormFillExample({super.key});
  @override
  State<FormFillExample> createState() => _FormFillExampleState();
}

class _FormFillExampleState extends State<FormFillExample> {
  final _formKey = GlobalKey<FormState>();
  final addressTextController = TextEditingController();
  final cityTextController = TextEditingController();
  final stateTextController = TextEditingController();
  final zipTextController = TextEditingController();

  @override
  void dispose() {
    addressTextController.dispose();
    cityTextController.dispose();
    stateTextController.dispose();
    zipTextController.dispose();
    super.dispose();
  }

  // What goes into the address control itself when a suggestion is chosen.
  String? onSuggestionClickGetTextToUseForControl(Place placeDetails) {
    String? forOurAddressBox = placeDetails.streetAddress;
    if (forOurAddressBox == null || forOurAddressBox.isEmpty) {
      forOurAddressBox = placeDetails.streetNumber ?? '';
      forOurAddressBox += (forOurAddressBox.isNotEmpty ? ' ' : '');
      forOurAddressBox += placeDetails.streetShort ?? '';
    }
    return forOurAddressBox;
  }

  void onSuggestionClick(Place placeDetails) {
    cityTextController.text = placeDetails.city ?? '';
    stateTextController.text = placeDetails.state ?? '';
    zipTextController.text = placeDetails.zipCode ?? '';
  }

  void onClearClick() {
    addressTextController.clear();
    cityTextController.clear();
    stateTextController.clear();
    zipTextController.clear();
    FocusScope.of(context).unfocus();
  }

  InputDecoration getInputDecoration(String hintText) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.purple),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(color: Colors.black12, width: 1.0),
      ),
    );
  }

  Widget label(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child:
              Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            label('Address'),
            AddressAutocompleteTextFormField(
              // No mapsApiKey needed: the injected provider owns the key.
              placeApiProvider: NativePlaceApiProvider(
                  componentCountry: 'us', language: 'en-US'),
              controller: addressTextController,
              debounceTime: 200,
              onClearClick: onClearClick,
              onSuggestionClickGetTextToUseForControl:
                  onSuggestionClickGetTextToUseForControl,
              onSuggestionClick: onSuggestionClick,
              clearButton: const Icon(Icons.close),
              keyboardType: TextInputType.streetAddress,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              scrollPadding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              decoration:
                  getInputDecoration('Start typing address for Autocomplete..'),
            ),
            label('City'),
            TextFormField(
              controller: cityTextController,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              decoration: getInputDecoration('New York'),
            ),
            label('State'),
            TextFormField(
              controller: stateTextController,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              decoration: getInputDecoration('NY'),
            ),
            label('Zip'),
            TextFormField(
              controller: zipTextController,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              decoration: getInputDecoration('10001'),
            ),
          ],
        ),
      ),
    );
  }
}
