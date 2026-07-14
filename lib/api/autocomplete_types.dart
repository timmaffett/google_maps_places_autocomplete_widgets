/// AutoCompleteTypes
/// You can restrict results from a Place Autocomplete request to be of a certain type by passing the types parameter.
/// This parameter specifies a type or a type collection, as listed in Place Types. If nothing is specified, all types are returned.
///
/// A place can only have a single primary type from types listed in Table 1 or Table 2.
/// For example, a hotel where food is served may by returned only with types=lodging and not with types=restaurant.
///
/// For the value of the types parameter you can specify either:
///
/// Up to five values from Table 1 or Table 2. For multiple values, separate each value with a | (vertical bar). For example:
///
/// types=book_store|cafe
///
/// Any single supported filter in Table 3. You cannot mix type collections.
///
/// Note: Although geocode and establishment are part of Table 2, they cannot be combined with any other type in Tables 1, 2, or 3 in Place Autocomplete request filters.
/// The request will be rejected with an INVALID_REQUEST error if:
///
/// More than five types are specified.
/// Any unrecognized types are present.
/// Any types from in Table 1 or Table 2 are mixed with any of the filters in Table 3.
///
/// Google Places Autocomplete Types - This can be a SINGLE type from filter table (Table 3)
/// Table 3: https://developers.google.com/maps/documentation/places/web-service/supported_types#table3
/// or it can be up to 5 of
///   Table 1:  https://developers.google.com/maps/documentation/places/web-service/supported_types#table1
///   Table 2:  https://developers.google.com/maps/documentation/places/web-service/supported_types#table2
enum AutoCompleteType {
  /// MUST BE USED ALONE - `geocode` instructs the Place Autocomplete service to return only geocoding results, rather than business results. Generally, you use this request to disambiguate results where the location specified may be indeterminate.
  geocode('geocode', true),

  ///  MUST BE USED ALONE - `address` instructs the Place Autocomplete service to return only geocoding results with a precise address. Generally, you use this request when you know the user will be looking for a fully specified address.
  address('address', true),

  /// MUST BE USED ALONE - `establishment` instructs the Place Autocomplete service to return only business results.
  establishment('establishment', true),

  /// MUST BE USED ALONE - The `(regions)` type collection instructs the Places service to return any result matching the following types: `locality`, `sublocality`, `postal_code`, `country`, `administrative_area_level_1`, `administrative_area_level_2`
  regions('(regions)', true),

  /// MUST BE USED ALONE - The `(cities)` type collection instructs the Places service to return results that match locality or administrative_area_level_3.
  cities('(cities)', true),

// Table 1:  https://developers.google.com/maps/documentation/places/web-service/supported_types#table1
  accounting('accounting'),
  airport('airport'),
  amusementPark('amusement_park'),
  aquarium('aquarium'),
  artGallery('art_gallery'),
  atm('atm'),
  bakery('bakery'),
  bank('bank'),
  bar('bar'),
  beautySalon('beauty_salon'),
  bicycleStore('bicycle_store'),
  bookStore('book_store'),
  bowlingAlley('bowling_alley'),
  busStation('bus_station'),
  cafe('cafe'),
  campground('campground'),
  carDealer('car_dealer'),
  carRental('car_rental'),
  carRepair('car_repair'),
  carWash('car_wash'),
  casino('casino'),
  cemetery('cemetery'),
  church('church'),
  cityHall('city_hall'),
  clothingStore('clothing_store'),
  convenienceStore('convenience_store'),
  courthouse('courthouse'),
  dentist('dentist'),
  departmentStore('department_store'),
  doctor('doctor'),
  drugstore('drugstore'),
  electrician('electrician'),
  electronicsStore('electronics_store'),
  embassy('embassy'),
  fireStation('fire_station'),
  florist('florist'),
  funeralHome('funeral_home'),
  furnitureStore('furniture_store'),
  gasStation('gas_station'),
  gym('gym'),
  hairCare('hair_care'),
  hardwareStore('hardware_store'),
  hinduTemple('hindu_temple'),
  homeGoodsStore('home_goods_store'),
  hospital('hospital'),
  insuranceAgency('insurance_agency'),
  jewelryStore('jewelry_store'),
  laundry('laundry'),
  lawyer('lawyer'),
  library('library'),
  lightRailStation('light_rail_station'),
  liquorStore('liquor_store'),
  localGovernmentOffice('local_government_office'),
  locksmith('locksmith'),
  lodging('lodging'),
  mealDelivery('meal_delivery'),
  mealTakeaway('meal_takeaway'),
  mosque('mosque'),
  movieRental('movie_rental'),
  movieTheater('movie_theater'),
  movingCompany('moving_company'),
  museum('museum'),
  nightClub('night_club'),
  painter('painter'),
  park('park'),
  parking('parking'),
  petStore('pet_store'),
  pharmacy('pharmacy'),
  physiotherapist('physiotherapist'),
  plumber('plumber'),
  police('police'),
  postOffice('post_office'),
  primarySchool('primary_school'),
  realEstateAgency('real_estate_agency'),
  restaurant('restaurant'),
  roofingContractor('roofing_contractor'),
  rvPark('rv_park'),
  school('school'),
  secondarySchool('secondary_school'),
  shoeStore('shoe_store'),
  shoppingMall('shopping_mall'),
  spa('spa'),
  stadium('stadium'),
  storage('storage'),
  store('store'),
  subwayStation('subway_station'),
  supermarket('supermarket'),
  synagogue('synagogue'),
  taxiStand('taxi_stand'),
  touristAttraction('tourist_attraction'),
  trainStation('train_station'),
  transitStation('transit_station'),
  travelAgency('travel_agency'),
  university('university'),
  veterinaryCare('veterinary_care'),
  zoo('zoo'),
// Table 2 types  from https://developers.google.com/maps/documentation/places/web-service/supported_types#table2
  administrativeAreaLevel_1('administrative_area_level_1'),
  administrativeAreaLevel_2('administrative_area_level_2'),
  administrativeAreaLevel_3('administrative_area_level_3'),
  administrativeAreaLevel_4('administrative_area_level_4'),
  administrativeAreaLevel_5('administrative_area_level_5'),
  administrativeAreaLevel_6('administrative_area_level_6'),
  administrativeAreaLevel_7('administrative_area_level_7'),
  archipelago('archipelago'),
  colloquialArea('colloquial_area'),
  continent('continent'),
  country('country'),
//SINGLE ENTRY table 3 //establishment('establishment'),
  finance('finance'),
  floor('floor'),
  food('food'),
  generalContractor('general_contractor'),
//SINGLE ENTRY table 3 //geocode('geocode'),
  health('health'),
  intersection('intersection'),
  landmark('landmark'),
  locality('locality'),
  naturalFeature('natural_feature'),
  neighborhood('neighborhood'),
  placeOfWorship('place_of_worship'),
  plusCode('plus_code'),
  pointOfInterest('point_of_interest'),
  political('political'),
  postBox('post_box'),
  postalCode('postal_code'),
  postalCodePrefix('postal_code_prefix'),
  postalCodeSuffix('postal_code_suffix'),
  postalTown('postal_town'),
  premise('premise'),
  room('room'),
  route('route'),
  streetAddress('street_address'),
  streetNumber('street_number'),
  sublocality('sublocality'),
  sublocalityLevel_1('sublocality_level_1'),
  sublocalityLevel_2('sublocality_level_2'),
  sublocalityLevel_3('sublocality_level_3'),
  sublocalityLevel_4('sublocality_level_4'),
  sublocalityLevel_5('sublocality_level_5'),
  subpremise('subpremise'),
  townSquare('town_square'),
  ;

  final bool onlySingleValueAllowed;
  final String typeString;

  const AutoCompleteType(this.typeString,
      [this.onlySingleValueAllowed = false]);

  @override
  String toString() {
    return typeString;
  }
}

/// Validates the Google Places rules shared by both API backends:
/// a maximum of 5 type values, and "single only" values (collections such
/// as `(cities)`/`(regions)` and the legacy `address`/`geocode`/
/// `establishment` filters) must not be combined with any other value.
/// Throws [Exception] on violation (same behavior/messages as v1.x).
void validateAutocompleteTypes(List<AutoCompleteType> types) {
  for (final type in types) {
    if (type.onlySingleValueAllowed && types.length > 1) {
      throw Exception(
          'If $type is specified then it is the ONLY autocomplete type allowed by Google Places. See https://developers.google.com/maps/documentation/places/web-service/autocomplete#types');
    }
  }
  if (types.length > 5) {
    throw Exception(
        'A maximum of 5 autocomplete types are allowed by Google Places. See https://developers.google.com/maps/documentation/places/web-service/autocomplete#types');
  }
}
