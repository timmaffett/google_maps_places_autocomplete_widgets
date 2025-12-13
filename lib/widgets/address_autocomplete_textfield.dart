library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_places_autocomplete_widgets/api/autocomplete_types.dart';
import 'package:uuid/uuid.dart';

import 'address_autocomplete_generic.dart';
import '/model/place.dart';
import '/model/suggestion.dart';
import '/service/address_service.dart';

export 'package:google_maps_places_autocomplete_widgets/model/place.dart';
export 'package:google_maps_places_autocomplete_widgets/model/suggestion.dart';

class AddressAutocompleteTextField extends AddresssAutocompleteStatefulWidget {
  /// Callback triggered before sending query to google places API.
  /// This allows the caller to prepare the query, modifying it in any way.  It might be
  /// used for adding things like City, State, Zip that may be already entered in other
  /// form elements.
  @override
  final String Function(String address)? prepareQuery;

  ///Callback triggered when user clicks clear icon.  This can be useful if the caller wants to clear other
  /// address fields that may be in their form.
  @override
  final void Function()? onClearClick;

  ///Callback triggered when a address item is selected, allows chance to
  /// clear other fields awaiting [Place] details in [onSuggestionClick]
  /// or to use the [Suggestion] information directly.
  @override
  final void Function(Suggestion suggestion)? onInitialSuggestionClick;

  ///Callback triggered when after Place has been retreived after item is selected
  @override
  final void Function(Place place)? onSuggestionClick;

  //callback triggered when losing focus but no suggestion was selected
  @override
  final void Function(String text)? onFinishedEditingWithNoSuggestion;

  ///Callback triggered when a item is selected
  @override
  final String? Function(Place place)? onSuggestionClickGetTextToUseForControl;

  ///Your Google Maps API key, this is required.
  @override
  final String mapsApiKey;

  ///your proxy url for web
  @override
  final String? proxyUrl;

  ///builder used to render each item displayed
  ///must not be null
  @override
  final Widget Function(Suggestion, int)? buildItem;

  ///Hover color around [buildItem] widget on desktop platforms.
  @override
  final Color? hoverColor;

  ///Selection color around [buildItem] widget on desktop platforms.
  @override
  final Color? selectionColor;

  ///builder used to render a clear, it can be null, but in that case, a clear button is not displayed
  @override
  final Icon? clearButton;

  ///BoxDecoration for the suggestions external container
  @override
  final BoxDecoration? suggestionsOverlayDecoration;

  ///InputDecoration, if none is given, it defaults to flutter standards
  @override
  final InputDecoration? decoration;

  ///Elevation for the suggestion list
  @override
  final double? elevation;

  ///Offset between the TextField and the Overlay
  @override
  final double overlayOffset;

  ///if true, shows "powered by google" inside the suggestion list, after its items
  @override
  final bool showGoogleTradeMark;

  ///used to narrow down address search
  @override
  final String? componentCountry;

  ///Inform Google places of desired language the results should be returned.
  @override
  final String? language;

  /// (deprecated) PostalCode lookup instead of address lookup (defaults to false)
  /// (This has now been deprecated and replaced with [type] parameter `type:AutoCompleteType.postalCode`).
  @override
  @Deprecated(
      "If passing true use `type:AutoCompleteType.postalCode` instead. (false == passing `type:AutoCompleteType.address`")
  final bool? postalCodeLookup;

  /// Single AutoCompleteType enum for type of information to autocomplete
  /// (Defaults to [AutoCompleteType.address] , use [AutoCompleteType.postalCode] for Zipcode lookup)
  /// This must be null if [types] is supplied
  @override
  final AutoCompleteType? type;

  /// Can be used as an *alternative* to [type] and allows a list of up to 5 AutoCompleteType enums
  /// to specify the types of autocomplete information to lookup.
  /// (Google places api only allows 5 types maximum)
  /// ([type] must not be supplied if [types] is used).
  @override
  final List<AutoCompleteType>? types;

  ///debounce time in milliseconds (default 600)
  @override
  final int debounceTime;

  /// Specify the [TextEditingController] to use. Should be null if [initialValue] is specified.
  @override
  final TextEditingController? controller;

  /// Specify the initialValue - this should be null if [controller] is specified.
  @override
  final String? initialValue;

  @override
  final FocusNode? focusNode;

  // inherited TextField arguments
  @override
  final TextInputType? keyboardType;

  @override
  final TextCapitalization textCapitalization;

  @override
  final TextInputAction? textInputAction;

  @override
  final TextStyle? style;

  @override
  final StrutStyle? strutStyle;

  @override
  final TextAlign textAlign;

  @override
  final TextAlignVertical? textAlignVertical;

  @override
  final TextDirection? textDirection;

  @override
  final bool autofocus;

  @override
  final bool readOnly;

  @override
  final int? maxLines;

  @override
  final int? minLines;

  @override
  final bool expands;

  @override
  final bool? showCursor;

  @override
  final int? maxLength;

  @override
  final MaxLengthEnforcement? maxLengthEnforcement;

  @override
  final ValueChanged<String>? onChanged;

  const AddressAutocompleteTextField({
    super.key,
    required this.mapsApiKey,
    this.proxyUrl,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.prepareQuery,
    this.onClearClick,
    this.onInitialSuggestionClick,
    this.onSuggestionClick,
    this.onFinishedEditingWithNoSuggestion,
    this.onSuggestionClickGetTextToUseForControl,
    this.buildItem,
    this.hoverColor,
    this.selectionColor,
    this.clearButton,
    this.suggestionsOverlayDecoration,
    this.decoration,
    this.elevation,
    this.overlayOffset = 4,
    this.showGoogleTradeMark = false,
    this.postalCodeLookup,
    this.type,
    this.types,
    this.debounceTime = 600,
    this.componentCountry,
    this.language,

    // inherited TextField arguments
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.autofocus = false,
    this.readOnly = false,
    this.showCursor,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
  }) : assert(
            (postalCodeLookup == true && type == null && types == null) ||
                (postalCodeLookup == false && type == null && types == null) ||
                (postalCodeLookup == null && type == null && types == null) ||
                (postalCodeLookup == null && type != null && types == null) ||
                (postalCodeLookup == null && type == null && types != null),
            'You can only supply value for [type], [types] (or deprecated `postalCodeLookup`).  No combinations allowed');

  @override
  State<StatefulWidget> createState() => _AddressAutocompleteTextFieldState();
}

class _AddressAutocompleteTextFieldState
    extends State<AddressAutocompleteTextField>
    with SuggestionOverlayMixin
    implements OverlaySuggestionDetails {
  @override
  final LayerLink layerLink = LayerLink();

  @override
  final String sessionToken = const Uuid().v4();

  @override
  TextEditingController? controller;

  @override
  late final FocusNode focusNode;

  @override
  late AddressService addressService;

  @override
  OverlayEntry? entry;

  @override
  List<Suggestion> suggestions = [];

  @override
  Timer? debounceTimer;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: Stack(
        children: [
          TextField(
            focusNode: focusNode,
            controller: controller,
            onChanged: onTextChanges,
            decoration: getInputDecoration(),
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            style: widget.style,
            strutStyle: widget.strutStyle,
            textAlign: widget.textAlign,
            textAlignVertical: widget.textAlignVertical,
            textDirection: widget.textDirection,
            autofocus: widget.autofocus,
            readOnly: widget.readOnly,
            showCursor: widget.showCursor,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            expands: widget.expands,
            maxLength: widget.maxLength,
            maxLengthEnforcement: widget.maxLengthEnforcement,
          ),
        ],
      ),
    );
  }
}
