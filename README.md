# Google_Maps_Places_Autocomplete_Widgets

Feature complete, 'drop in' replacements for Flutter `TextField` or `TextFormField` widgets, providing address autocompletion using the Google Maps Places API.
The only required additional parameter is your Google Maps API key.
Just rename `TextField` -> `AddressAutocompleteTextField`,
(or `TextFormField` -> `AddressAutocompleteTextFormField`),
and add your `mapsApiKey:'YOUR_GOOGLE_MAPS_API_KEY'` as the only required additional parameter.

If desired customize any look/behavior of the autocompletion using the additional optional parameters.

Additionally any of the other Google Places autocomplete information can be retrieved.

- Postal code/Zip code autocompletion is supported using the `type:AutoCompleteType.postalCode` parameter.
- Cities autocompletion is supported using the `type:AutoCompleteType.cities` parameter.  
   (`type:AutoCompleteType.cities` returns any `AutoCompleteType.locality` or `AutoCompleteType.administrativeAreaLevel_3` matched).
- Businesses and Establishment autocompletion is supported using the `type:AutoCompleteType.establishment` parameter.
- Region autocompletion is supported using the `type:AutoCompleteType.regions` parameter.  
    (`AutoCompleteType.regions` returns any `AutoCompleteType.locality`, `AutoCompleteType.sublocality`, `AutoCompleteType.postal_code`,
    `AutoCompleteType.country`, `AutoCompleteType.administrativeAreaLevel_1` or `AutoCompleteType.administrativeAreaLevel_2` matched)
- Or you can combine up to 5 of the `AutoCompleteType` enums using the `types` parameter  
    (eg. `types:[AutoCompleteType.bookStore,AutoCompleteType.bicycleStore,AutoCompleteType.school]`).

 (See [Table 3](https://developers.google.com/maps/documentation/places/web-service/supported_types#table3),
 [Table 1](https://developers.google.com/maps/documentation/places/web-service/supported_types#table1), and [Table 2](https://developers.google.com/maps/documentation/places/web-service/supported_types#table2)).

Easily incorporated into existing forms which contain multiple fields for capturing address information.

## Demo

![Short Demo of Included Example](media/small_demo.gif)

## Features

- Support for most common `TextField` and `TextFormField` parameters (and any
  less common parameter can easily be added).
- Support for both address and postal/zip code autocompletion. (`type:AutoCompleteType.address` or `type:AutoCompleteType.postalCode`)
- Support for ANY of other the Google Places autocompletion types (See [Table 3](https://developers.google.com/maps/documentation/places/web-service/supported_types#table3), [Table 1](https://developers.google.com/maps/documentation/places/web-service/supported_types#table1), and [Table 2](https://developers.google.com/maps/documentation/places/web-service/supported_types#table2))
- Robust set of optional callbacks that all customizing behavior in virtually any way.
- Easy 'drop in' replacement of address field in any flutter form.
- Easy customization of virtually every look and feel display/behavior property.
- Hooks allow filling multiple form fields (City, State, Zip, etc.) from results
  of user's address selection from the initial address form field autocomplete
  suggestions.
- Hooks to allow clearing of multiple other form fields when the clear button
  is used in the address autocomplete widget.
- Ability to customize the search query string with contents of other form fields
  before querying google maps places api.
- Ability to use the contents of the autocomplete suggestion without additional
  google maps places details api request.
- The base classes and mixin generics provided in this package allow for the addition
  of address autocompletion to virtually any of custom widgets.

## Usage

You can find a complete example of usage in `example/main.dart`.

import the package:

```dart
import 'package:google_maps_places_autocomplete_widgets/address_autocomplete_widgets.dart';
```

Add your google places api key, optional `onSuggestionClick` callback,
and optional language and country restrictions parameters:

```dart
AddressAutocompleteTextField(
    mapsApiKey: 'YOUR GOOGLE MAPS API KEY HERE',
    onSuggestionClick: onSuggestionClick,
    componentCountry: 'us',
    language: 'en-US'

    //..any other arguments that you would use with a TextField..

),
```

or

```dart
AddressAutocompleteTextFormField(
    mapsApiKey: 'YOUR GOOGLE MAPS API KEY HERE',
    onSuggestionClick: onSuggestionClick,
    componentCountry: 'us',
    language: 'en-US'

    //..any other arguments that you would use with a TextFormField..
),


```

To utilize any of the robust set of retrieved `Place` details write a
`onSuggestionClick` callback function:

```dart
void onSuggestionClick(Place placeDetails) {
    setState(() {
      // examples of the returned address details
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
```

## More complex use and customization examples

A complete example mobile/desktop applications illustrates the use of both common
and optional parameters.
This includes the use of the address autocomplete TextFormField widget to fill
multiple other TextFormFields from the user's selected address suggestion.

## Proxy Example
This code shows an example of a proxy created using Firebase Cloud Functions.

```javascript

const corsHandler = cors({ origin: true });
export const placesApiProxy = onRequest(async (req: any, res: any) => {
  corsHandler(req, res, async () => {
    if (req.method === "OPTIONS") {
      return res.status(204).send("");
    }
    try {
      const { input, place_id: placeId } = req.query;

      const apiKey = process.env.GOOGLE_MAPS_API_KEY;
      let googleRes = await got(
        "https://maps.googleapis.com/maps/api/place/autocomplete/json",
        {
          searchParams: { input, "types": "address", "key": apiKey },
          responseType: "json",
        }
      );
      // If the place_id is set, we hit the details api instead.
      if (placeId) {
        googleRes = await got(
          "https://maps.googleapis.com/maps/api/place/details/json",
          {
            searchParams: {
              "placeid": placeId, "types": "address",
              "key": apiKey,
            },
            responseType: "json",
          }
        );
      }

      logger.debug("placesApiProxy | googleRes:", googleRes);
      const body = googleRes.body as any;
      logger.debug("placesApiProxy | response:", body);

      return res.status(200).json(body);
    } catch (err: any) {
      logger.error("placesApiProxy | caught error:", {
        message: err.message,
        stack: err.stack,
        responseBody: err.response?.body,
      });
      return res
        .status(500)
        .json({ error: "Internal error", details: err.message });
    }
  });
});
```

## Additional information

This package implements the official documentation of Google Maps Places API
and use address as types and receive a detail with address_component and geometry as fields only

GitHub Repo: [https://github.com/timmaffett/google_maps_places_autocomplete_widgets]( https://github.com/timmaffett/google_maps_places_autocomplete_widgets)

## Acknowledgements

This package was originally based on source code from the package
`maps_places_autocomplete 0.0.2` by @leandro-zanardi.  As I customized my use case
within my own apps the source code diverged significantly from the original package
and it was easiest for me to create my own new package.

The rather unfortunate (and long) name for this package is a result of the
pub.dev namespace clutter of various packages also using Google Maps Places API.
