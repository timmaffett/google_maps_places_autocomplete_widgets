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

typedef ReportValidationFailureAndRequestFocusCallback = bool Function(
    String errorMessageForThisFailedValidation);

class AddressAutocompleteTextFormField
    extends AddresssAutocompleteStatefulWidget {
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

  ///your maps api key, must not be null
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

  /// Mark if this is a required field for basic validation.
  final bool requiredField;

  /// Key to use for the TextFormField() widget.
  final Key? textFormFieldKey;

  final ReportValidationFailureAndRequestFocusCallback?
      reportValidationFailAndRequestFocus;

  // These correspond to arguments supported by standard Flutter TextFormField
  @override
  final FocusNode? focusNode;

  @override
  final InputDecoration? decoration;

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
  final TextDirection? textDirection;

  @override
  final TextAlign textAlign;

  @override
  final TextAlignVertical? textAlignVertical;

  @override
  final bool autofocus;

  @override
  final bool readOnly;

  @override
  final bool? showCursor;

  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final bool enableSuggestions;

  @override
  final MaxLengthEnforcement? maxLengthEnforcement;

  @override
  final int? maxLines;

  @override
  final int? minLines;

  @override
  final bool expands;

  @override
  final int? maxLength;

  @override
  final ValueChanged<String>? onChanged;

  final GestureTapCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final Brightness? keyboardAppearance;
  final EdgeInsets scrollPadding;
  final bool? enableInteractiveSelection;
  final TextSelectionControls? selectionControls;
  final InputCounterWidgetBuilder? buildCounter;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;
  final AutovalidateMode? autovalidateMode;
  final ScrollController? scrollController;
  final bool enableIMEPersonalizedLearning;
  final MouseCursor? mouseCursor;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final String? Function(String?)? validator;

  static String? defaultValidator(String? testThisData) {
    return null;
  }

  const AddressAutocompleteTextFormField({
    super.key,
    required this.mapsApiKey,
    this.proxyUrl,
    this.controller,
    this.requiredField = false,
    this.validator = defaultValidator,
    this.textFormFieldKey,
    this.reportValidationFailAndRequestFocus,
    this.debounceTime = 600,
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
    this.elevation,
    this.overlayOffset = 4,
    this.showGoogleTradeMark = false,
    this.postalCodeLookup,
    this.type,
    this.types,
    this.componentCountry,
    this.language,

    // arg passthroughs to TextFormField - same defaults as TextFormField
    this.initialValue,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.style,
    this.strutStyle,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.autofocus = false,
    this.readOnly = false,
    this.showCursor,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions = true,
    this.maxLengthEnforcement,
    this.maxLines,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.onChanged,
    this.onTap,
    this.onTapOutside,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.enabled,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.enableInteractiveSelection,
    this.selectionControls,
    this.buildCounter,
    this.scrollPhysics,
    this.autofillHints,
    this.autovalidateMode,
    this.scrollController,
    this.enableIMEPersonalizedLearning = true,
    this.mouseCursor,
    this.contextMenuBuilder,
  }) : assert(
            (postalCodeLookup == true && type == null && types == null) ||
                (postalCodeLookup == false && type == null && types == null) ||
                (postalCodeLookup == null && type == null && types == null) ||
                (postalCodeLookup == null && type != null && types == null) ||
                (postalCodeLookup == null && type == null && types != null),
            'You can only supply value for [type], [types] (or deprecated `postalCodeLookup`).  No combinations allowed');

  @override
  State<StatefulWidget> createState() =>
      _AddressAutocompleteTextFormFieldState();
}

class _AddressAutocompleteTextFormFieldState
    extends State<AddressAutocompleteTextFormField>
    with SuggestionOverlayMixin
    implements OverlaySuggestionDetails {
  @override
  final LayerLink layerLink = LayerLink();
  @override
  final String sessionToken = const Uuid().v4();

  // [_controller] is not final because it is possible that the dispose() can happen
  //  if caller does setState(), so we must be able to set it to null after dispose so that any
  //  of our pending callbacks can detect if it has been disposed and not use it.
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

  void weHaveValidationErrorRequestFocusIfAvailable(String validationErrorMsg) {
    // If there is an error for this input then request focus here
    // so form scrolls to show this
    // We only do this if another widget has not *already* requested the focus,
    // so the first field with an error in the form will be the field that gets the
    // focus, instead of the last.
    bool focusRequestedAlready = false;
    if (widget.reportValidationFailAndRequestFocus != null) {
      focusRequestedAlready =
          widget.reportValidationFailAndRequestFocus!.call(validationErrorMsg);
    }
    if (!focusRequestedAlready) {
      focusNode.requestFocus();
    }
  }

  String? validatorWithFocusHandlingWrapper(String? value) {
    // first handle required field error if this is an empty value
    if (widget.requiredField && (value == null || value == '')) {
      const String validateErrorMsg = 'This field is required.';
      weHaveValidationErrorRequestFocusIfAvailable(validateErrorMsg);
      return validateErrorMsg;
    }
    // and now check value validation if there is a validation callback
    if (widget.validator != null) {
      String? validateRetMsg = widget.validator!.call(value);
      if (validateRetMsg != null) {
        // failed validation
        weHaveValidationErrorRequestFocusIfAvailable(validateRetMsg);
      }
      return validateRetMsg;
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: layerLink,
      child: Stack(
        children: [
          TextFormField(
            focusNode: focusNode,
            controller: controller,
            onChanged: onTextChanges,
            decoration: getInputDecoration(),

            key: widget.textFormFieldKey,
            validator: widget.validator != null
                ? validatorWithFocusHandlingWrapper
                : null,
            onEditingComplete: widget.onEditingComplete,

            // passthru args
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            style: widget.style,
            strutStyle: widget.strutStyle,
            textDirection: widget.textDirection,
            textAlign: widget.textAlign,
            textAlignVertical: widget.textAlignVertical,
            autofocus: widget.autofocus,
            readOnly: widget.readOnly,
            showCursor: widget.showCursor,
            smartDashesType: widget.smartDashesType,
            smartQuotesType: widget.smartQuotesType,
            enableSuggestions: widget.enableSuggestions,
            maxLengthEnforcement: widget.maxLengthEnforcement,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            expands: widget.expands,
            maxLength: widget.maxLength,
            onTap: widget.onTap,
            onTapOutside: widget.onTapOutside,
            onFieldSubmitted: widget.onFieldSubmitted,
            inputFormatters: widget.inputFormatters,
            enabled: widget.enabled,
            cursorWidth: widget.cursorWidth,
            cursorHeight: widget.cursorHeight,
            cursorRadius: widget.cursorRadius,
            cursorColor: widget.cursorColor,
            keyboardAppearance: widget.keyboardAppearance,
            scrollPadding: widget.scrollPadding,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            selectionControls: widget.selectionControls,
            buildCounter: widget.buildCounter,
            scrollPhysics: widget.scrollPhysics,
            autofillHints: widget.autofillHints,
            autovalidateMode: widget.autovalidateMode,
            scrollController: widget.scrollController,
            enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
            mouseCursor: widget.mouseCursor,
            contextMenuBuilder: widget.contextMenuBuilder,
          ),
        ],
      ),
    );
  }
}
