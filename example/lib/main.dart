import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
import '/privatekeys.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Address AutoComplete Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            bottom: const TabBar(
              tabs: [
                Tab(text: 'TextField'),
                Tab(text: 'TextFormField'),
              ],
            ),
            title: const Center(
                child: Text('Google_Map_Places_AutoComplete_Widgets Demo',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ),
          body: const TabBarView(
            children: [
              AddressAutocompleteTextFieldExample(title: 'TextField Example'),
              AddressAutocompleteTextFormFieldExample(),
            ],
          ),
        ),
      ),
    );
  }
}

class AddressAutocompleteTextFieldExample extends StatefulWidget {
  const AddressAutocompleteTextFieldExample({super.key, required this.title});

  final String title;

  @override
  State<AddressAutocompleteTextFieldExample> createState() =>
      _AddressAutocompleteTextFieldExampleState();
}

class _AddressAutocompleteTextFieldExampleState
    extends State<AddressAutocompleteTextFieldExample> {
  String? _suggestionPlaceId;
  String? _suggestionDescription;
  String? _name;
  String? _formattedAddress;
  String? _formattedAddressZipPlus4;
  String? _streetAddress;
  String? _streetNumber;
  String? _street;
  String? _streetShort;
  String? _city;
  String? _county;
  String? _state;
  String? _stateShort;
  String? _zipCode;
  String? _zipCodeSuffix;
  String? _zipCodePlus4;
  String? _vicinity;
  String? _country;
  double? _lat;
  double? _lng;

  // write optional function to determine what is placed in the textfield
  // control when the user chooses an address.  The default is the `formattedAddress`
  String? onSuggestionClickGetTextToUseForControl(Place placeDetails) {
    //  we just want the street address here, for example if we were using
    //  the address line of the form to trigger the address autocomplete
    return placeDetails.streetAddress;
  }

  String? onSuggestionClickFillZipCodeControl(Place placeDetails) {
    //  we just want the zipCodePlus4, for example if we were using
    //  the zipcode field controll in the form to trigger the zipcode
    //  autocomplete
    return placeDetails.zipCodePlus4;
  }

  String? onSuggestionClickFillCitiesCodeControl(Place placeDetails) {
    //  Format the city, state and country from autocomplete info
    return '${placeDetails.city}, ${placeDetails.state}, ${placeDetails.country}';
  }

  String? onSuggestionClickFillEstablishmentCodeControl(Place placeDetails) {
    //  Print name and formatted address of place
    return '${placeDetails.name}, ${placeDetails.formattedAddress}';
  }

  // This is called Immediatelly when user clicks suggestion and BEFORE
  // the async request to get place
  void onInitialSuggestionClick(Suggestion suggestion) {
    debugPrint('onInitialSuggestionClick( suggestion:$suggestion )');
    setState(() {
      _suggestionDescription = suggestion.description;
      _suggestionPlaceId = suggestion.placeId;
      // clear these until they are loaded...
      _name = _formattedAddress = _formattedAddressZipPlus4 = _streetAddress =
          _streetNumber = _street = _streetShort = _city = _county = _state =
              _stateShort = _zipCode = _zipCodeSuffix =
                  _zipCodePlus4 = _country = _vicinity = '....';
      _lat = _lng = 0.0;
    });
  }

  // write a function to receive the place details callback
  void onSuggestionClick(Place placeDetails) {
    debugPrint('onSuggestionClick( placeDetails:$placeDetails )');
    setState(() {
      _name = placeDetails.name;
      _formattedAddress = placeDetails.formattedAddress;
      _formattedAddressZipPlus4 = placeDetails.formattedAddressZipPlus4;
      _streetAddress = placeDetails.streetAddress;
      _streetNumber = placeDetails.streetNumber;
      _street = placeDetails.street;
      _streetShort = placeDetails.streetShort;
      _city = placeDetails.city;
      _county = placeDetails.county;
      _state = placeDetails.state;
      _stateShort = placeDetails.stateShort;
      _zipCode = placeDetails.zipCode;
      _zipCodeSuffix = placeDetails.zipCodeSuffix;
      _zipCodePlus4 = placeDetails.zipCodePlus4;
      _country = placeDetails.country;
      _vicinity = placeDetails.vicinity;
      _lat = placeDetails.lat;
      _lng = placeDetails.lng;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Postalcode lookup TextField example
              const Text('Example of ZipCode/Postal Code lookup:'),
              SizedBox(
                height: 60,
                child: AddressAutocompleteTextField(
                  type: AutoCompleteType.postalCode,
                  keyboardType: TextInputType.number,
                  proxyUrl: PROXY_URL,
                  maxLength: 5,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  // create a `privatekeys.dart` file and add your API key there
                  //   `const GOOGLE_MAPS_ACCOUNT_API_KEY = 'YourGoogleMapsApiKey_XXXXyyyzzzz';`
                  // the .gitignore file is set so this does not go into source repository.
                  mapsApiKey: GOOGLE_MAPS_ACCOUNT_API_KEY,

                  // optional callback arg for use when you do not want `formattedAddress`
                  // to be used to fill the autocomplete textfield when an address is chosen.
                  onSuggestionClickGetTextToUseForControl:
                      onSuggestionClickFillZipCodeControl,
                  onInitialSuggestionClick: onInitialSuggestionClick,
                  onSuggestionClick: onSuggestionClick,
                  hoverColor: Colors.blue, // for desktop platforms with mouse
                  selectionColor:
                      Colors.green, // for desktop platforms with mouse
                  onFinishedEditingWithNoSuggestion: (text) {
                    // you should invalidate the last entry of onSuggestionClick if you really need a valid location,
                    // otherwise decide what to do based on what the user typed, can be an empty string
                    debugPrint(
                        'onFinishedEditingWithNoSuggestion()  text typed: $text');
                  },
                  buildItem: (Suggestion suggestion, int index) {
                    return Container(
                        margin: const EdgeInsets.fromLTRB(2, 2, 2,
                            2), //<<This area will get hoverColor/selectionColor on desktop
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.centerLeft,
                        color: const Color.fromARGB(255, 220, 220, 220),
                        child: Text(suggestion.description,
                            style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)));
                  },
                  clearButton: const Icon(Icons.close),
                  componentCountry: 'us',
                  language: 'en-Us',
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(8),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    hintText: 'Enter Zipcode to lookup',
                    //errorText: 'Zip code must be 5 digits max',
                    //errorStyle: TextStyle(color:Colors.red),
                  ),
                ),
              ),

              // Cities autocompletion TextField example
              const Text('Example of City autocompletion:'),
              SizedBox(
                height: 60,
                child: AddressAutocompleteTextField(
                  type: AutoCompleteType.cities,
                  keyboardType: TextInputType.name,
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  // create a `privatekeys.dart` file and add your API key there
                  //   `const GOOGLE_MAPS_ACCOUNT_API_KEY = 'YourGoogleMapsApiKey_XXXXyyyzzzz';`
                  // the .gitignore file is set so this does not go into source repository.
                  mapsApiKey: GOOGLE_MAPS_ACCOUNT_API_KEY,

                  // optional callback arg for use when you do not want `formattedAddress`
                  // to be used to fill the autocomplete textfield when an address is chosen.
                  onSuggestionClickGetTextToUseForControl:
                      onSuggestionClickFillCitiesCodeControl,
                  onInitialSuggestionClick: onInitialSuggestionClick,
                  onSuggestionClick: onSuggestionClick,
                  hoverColor: Colors.blue, // for desktop platforms with mouse
                  selectionColor:
                      Colors.green, // for desktop platforms with mouse
                  onFinishedEditingWithNoSuggestion: (text) {
                    // you should invalidate the last entry of onSuggestionClick if you really need a valid location,
                    // otherwise decide what to do based on what the user typed, can be an empty string
                    debugPrint(
                        'onFinishedEditingWithNoSuggestion()  text typed: $text');
                  },
                  buildItem: (Suggestion suggestion, int index) {
                    return Container(
                        margin: const EdgeInsets.fromLTRB(2, 2, 2,
                            2), //<<This area will get hoverColor/selectionColor on desktop
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.centerLeft,
                        color: const Color.fromARGB(255, 220, 220, 220),
                        child: Text(suggestion.description,
                            style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)));
                  },
                  clearButton: const Icon(Icons.close),
                  componentCountry: 'us',
                  language: 'en-Us',
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(8),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    hintText: 'Enter city name',
                  ),
                ),
              ),

              // Cities autocompletion TextField example
              const Text('Example of Business autocompletion:'),
              SizedBox(
                height: 60,
                child: AddressAutocompleteTextField(
                  type: AutoCompleteType.establishment,
                  keyboardType: TextInputType.name,
                  style: const TextStyle(
                      color: Colors.cyan,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  // create a `privatekeys.dart` file and add your API key there
                  //   `const GOOGLE_MAPS_ACCOUNT_API_KEY = 'YourGoogleMapsApiKey_XXXXyyyzzzz';`
                  // the .gitignore file is set so this does not go into source repository.
                  mapsApiKey: GOOGLE_MAPS_ACCOUNT_API_KEY,

                  // optional callback arg for use when you do not want `formattedAddress`
                  // to be used to fill the autocomplete textfield when an address is chosen.
                  onSuggestionClickGetTextToUseForControl:
                      onSuggestionClickFillEstablishmentCodeControl,
                  onInitialSuggestionClick: onInitialSuggestionClick,
                  onSuggestionClick: onSuggestionClick,
                  hoverColor: Colors.blue, // for desktop platforms with mouse
                  selectionColor:
                      Colors.green, // for desktop platforms with mouse
                  onFinishedEditingWithNoSuggestion: (text) {
                    // you should invalidate the last entry of onSuggestionClick if you really need a valid location,
                    // otherwise decide what to do based on what the user typed, can be an empty string
                    debugPrint(
                        'onFinishedEditingWithNoSuggestion()  text typed: $text');
                  },
                  buildItem: (Suggestion suggestion, int index) {
                    return Container(
                        margin: const EdgeInsets.fromLTRB(2, 2, 2,
                            2), //<<This area will get hoverColor/selectionColor on desktop
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.centerLeft,
                        color: const Color.fromARGB(255, 220, 220, 220),
                        child: Text(suggestion.description,
                            style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)));
                  },
                  clearButton: const Icon(Icons.close),
                  componentCountry: 'us',
                  language: 'en-Us',
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(8),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    hintText: 'Enter business name',
                  ),
                ),
              ),

              // Address lookup TextField example
              const Text('Example of address lookup:'),
              SizedBox(
                height: 40,
                child: AddressAutocompleteTextField(
                  // create a `privatekeys.dart` file and add your API key there
                  //   `const GOOGLE_MAPS_ACCOUNT_API_KEY = 'YourGoogleMapsApiKey_XXXXyyyzzzz';`
                  // the .gitignore file is set so this does not go into source repository.
                  mapsApiKey: GOOGLE_MAPS_ACCOUNT_API_KEY,

                  // optional callback arg for use when you do not want `formattedAddress`
                  // to be used to fill the autocomplete textfield when an address is chosen.
                  onSuggestionClickGetTextToUseForControl:
                      onSuggestionClickGetTextToUseForControl,
                  onInitialSuggestionClick: onInitialSuggestionClick,
                  onSuggestionClick: onSuggestionClick,
                  onFinishedEditingWithNoSuggestion: (text) {
                    // you should invalidate the last entry of onSuggestionClick if you really need a valid location,
                    // otherwise decide what to do based on what the user typed, can be an empty string
                    debugPrint(
                        'onFinishedEditingWithNoSuggestion()  text typed: $text');
                  },
                  hoverColor: Colors.purple, // for desktop platforms with mouse
                  selectionColor:
                      Colors.red, // for desktop platforms with mouse
                  buildItem: (Suggestion suggestion, int index) {
                    return Container(
                        margin: const EdgeInsets.fromLTRB(1, 1, 1,
                            1), //<<This area will get hoverColor/selectionColor on desktop
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.centerLeft,
                        color: Colors.white,
                        child: Text(suggestion.description));
                  },
                  clearButton: const Icon(Icons.close),
                  componentCountry: 'us',
                  language: 'en-Us',
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(8),
                      border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      hintText: "Address",
                      errorText: null),
                ),
              ),
              /*********/

              /******** */
              // Use the details from callback
              Container(
                padding: const EdgeInsets.all(8),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Suggestion PlaceId: ${_suggestionPlaceId ?? '---'}'),
                        Text(
                            'Suggestion Description: ${_suggestionDescription ?? '---'}'),
                        Text('Name: ${_name ?? '---'}'),
                        Text('FormattedAddress: ${_formattedAddress ?? '---'}'),
                        Text(
                            'FormattedAddressZipPlus4: ${_formattedAddressZipPlus4 ?? '---'}'),
                        Text('StreetAddress: ${_streetAddress ?? '---'}'),
                        Text('StreetNumber: ${_streetNumber ?? '---'}'),
                        Text('Street: ${_street ?? '---'}'),
                        Text('StreetShort: ${_streetShort ?? '---'}'),
                        Text('Vicinity: ${_vicinity ?? '---'}'),
                        Text('City: ${_city ?? '---'}'),
                        Text('County: ${_county ?? '---'}'),
                        Text('State: ${_state ?? '---'}'),
                        Text('StateShort: ${_stateShort ?? '---'}'),
                        Text('Country: ${_country ?? '---'}'),
                        Text('ZipCode: ${_zipCode ?? '---'}'),
                        Text('ZipCodeSuffix: ${_zipCodeSuffix ?? '---'}'),
                        Text('ZipCodePlus4: ${_zipCodePlus4 ?? '---'}'),
                        Text('Latitude: ${_lat ?? '---'}'),
                        Text('Longitude: ${_lng ?? '---'}'),
                      ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddressAutocompleteTextFormFieldExample extends StatefulWidget {
  const AddressAutocompleteTextFormFieldExample({super.key});

  @override
  State<AddressAutocompleteTextFormFieldExample> createState() =>
      _AddressAutocompleteTextFormFieldExampleState();
}

class _AddressAutocompleteTextFormFieldExampleState
    extends State<AddressAutocompleteTextFormFieldExample> {
  final _formKey = GlobalKey<FormState>();
  late FocusNode addressFocusNode;
  late FocusNode cityFocusNode;
  late FocusNode stateFocusNode;
  late FocusNode zipFocusNode;

  late TextEditingController addressTextController;
  late TextEditingController cityTextController;
  late TextEditingController stateTextController;
  late TextEditingController zipTextController;

  @override
  void initState() {
    debugPrint('_LocationInformationPageState() init()');

    super.initState();

    addressFocusNode = FocusNode();
    cityFocusNode = FocusNode();
    stateFocusNode = FocusNode();
    zipFocusNode = FocusNode();

    addressTextController = TextEditingController();
    cityTextController = TextEditingController();
    stateTextController = TextEditingController();
    zipTextController = TextEditingController();
  }

  @override
  void dispose() {
    addressFocusNode.dispose();
    cityFocusNode.dispose();
    stateFocusNode.dispose();
    zipFocusNode.dispose();

    addressTextController.dispose();
    cityTextController.dispose();
    stateTextController.dispose();
    zipTextController.dispose();

    super.dispose();
  }

  // This callback returns what we want to be put into the text control
  // when they choose an address
  String? onSuggestionClickGetTextToUseForControl(Place placeDetails) {
    String? forOurAddressBox = placeDetails.streetAddress;
    if (forOurAddressBox == null || forOurAddressBox.isEmpty) {
      forOurAddressBox = placeDetails.streetNumber ?? '';
      forOurAddressBox += (forOurAddressBox.isNotEmpty ? ' ' : '');
      forOurAddressBox += placeDetails.streetShort ?? '';
    }
    return forOurAddressBox;
  }

  /// This method really does not seem to help...
  /// But i left the ability in because it might help more in
  /// countries other than the united states.
  String prepareQuery(String baseAddressQuery) {
    debugPrint('prepareQuery() baseAddressQuery=$baseAddressQuery');
    String built = baseAddressQuery;
    String city = cityTextController.text;
    String state = stateTextController.text;
    String zip = zipTextController.text;
    if (city.isNotEmpty) {
      built += ', $city';
    }
    if (state.isNotEmpty) {
      built += ', $state';
    }
    if (zip.isNotEmpty) {
      built += ' $zip';
    }
    built += ', USA';
    debugPrint('prepareQuery made built="$built"');
    return built;
  }

  void onClearClick() {
    debugPrint('onClearClickInAddressAutocomplete() clearing form');
    addressTextController.clear();
    cityTextController.clear();
    stateTextController.clear();
    zipTextController.clear();

    if (!addressFocusNode.hasFocus) {
      // if address does not have focus unfocus everything to close keyboard
      // and show the cleared form.
      FocusScopeNode currentFocus = FocusScope.of(context);
      currentFocus.unfocus();
    }
  }

  // This gets us an IMMEDIATE form fill but address has no abbreviations
  // and we must wait for the zipcode.
  void onInitialSuggestionClick(Suggestion suggestion) {
    final description = suggestion.description;

    debugPrint('onInitialSuggestionClick()  description=$description');
    debugPrint('  suggestion = $suggestion');
    /* COULD BE USED TO SHOW IMMEDIATE values in form
       BEFORE PlaceDetails arrive from API

    var parts = description.split(',');

    if(parts.length<4) {
      parts = [ '','','','' ];
    }
    addressTextController.text = parts[0];
    cityTextController.text = parts[1];
    stateTextController.text = parts[2].trim();
    zipTextController.clear(); // we wont have zip until details come thru
    */
  }

  // write a function to receive the place details callback
  void onSuggestionClick(Place placeDetails) {
    debugPrint('onSuggestionClick() placeDetails:$placeDetails');

    cityTextController.text = placeDetails.city ?? '';
    stateTextController.text = placeDetails.state ?? '';
    zipTextController.text = placeDetails.zipCode ?? '';
  }

  InputDecoration getInputDecoration(String hintText) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.grey),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(
          color: Colors.purple,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
        borderSide: const BorderSide(
          color: Colors.black12,
          width: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                const LeftAlignedLabelRow('Address'),
                AddressAutocompleteTextFormField(
                  // following args specific to AddressAutocompleteTextFormField()
                  mapsApiKey: GOOGLE_MAPS_ACCOUNT_API_KEY,
                  proxyUrl: PROXY_URL,
                  debounceTime: 200,
                  //In practice this does not seem to help United States address//prepareQuery: prepareQuery,
                  onClearClick: onClearClick,
                  onSuggestionClickGetTextToUseForControl:
                      onSuggestionClickGetTextToUseForControl,
                  onInitialSuggestionClick: onInitialSuggestionClick,
                  onSuggestionClick: onSuggestionClick,
                  onFinishedEditingWithNoSuggestion: (text) {
                    // you should invalidate the last entry of onSuggestionClick if you really need a valid location,
                    // otherwise decide what to do based on what the user typed, can be an empty string
                    debugPrint(
                        'onFinishedEditingWithNoSuggestion()  text typed: $text');
                  },
                  hoverColor: Colors.purple, // for desktop platforms with mouse
                  selectionColor:
                      Colors.purpleAccent, // for desktop platforms with mouse
                  buildItem: (Suggestion suggestion, int index) {
                    return Container(
                        margin: const EdgeInsets.fromLTRB(2, 2, 2,
                            2), //<<This area will get hoverColor/selectionColor on desktop
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.centerLeft,
                        color: Colors.white,
                        child: Text(suggestion.description,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)));
                  },
                  clearButton: const Icon(Icons.close),
                  componentCountry: 'us',
                  language: 'en-Us',

                  // 'normal' TextFormField arguments:
                  autofocus: true,
                  scrollPadding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  autovalidateMode: AutovalidateMode.disabled,
                  keyboardType: TextInputType.streetAddress,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onEditingComplete: () {
                    debugPrint('onEditingComplete() for TextFormField');
                  },
                  onChanged: (newText) {
                    debugPrint('onChanged() for TextFormField got "$newText"');
                  },
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: getInputDecoration(
                      'Start typing address for Autocomplete..'),
                ),
                const LeftAlignedLabelRow('City'),
                TextFormField(
                  controller: cityTextController,
                  focusNode: cityFocusNode,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: getInputDecoration('New York'),
                  validator: (value) {
                    // validation logic
                    return null;
                  },
                ),
                const LeftAlignedLabelRow('State'),
                TextFormField(
                  controller: stateTextController,
                  focusNode: stateFocusNode,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: getInputDecoration('NY'),
                  validator: (value) {
                    // validation logic
                    return null;
                  },
                ),
                const LeftAlignedLabelRow('Zip'),
                TextFormField(
                  controller: zipTextController,
                  focusNode: zipFocusNode,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: getInputDecoration('10001'),
                  validator: (value) {
                    // validation logic
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LeftAlignedLabelRow extends StatelessWidget {
  final String label;
  final double fontSize;
  final FontWeight fontWeight;

  const LeftAlignedLabelRow(this.label,
      {this.fontSize = 16.0, this.fontWeight = FontWeight.normal, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
        ),
      ],
    );
  }
}
