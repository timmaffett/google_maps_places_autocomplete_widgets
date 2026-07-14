/// Selects which Google Places backend the autocomplete widgets use.
enum PlacesApiVersion {
  /// Places API (New) — `https://places.googleapis.com/v1`. The default.
  /// Requires "Places API (New)" to be enabled for your API key in the
  /// Google Cloud console.
  placesApiNew,

  /// The legacy Places API — `https://maps.googleapis.com/maps/api/place`.
  /// Google set this API to legacy status on March 1, 2025: it can no longer
  /// be enabled on new Google Cloud projects, but keeps working on projects
  /// where it was already enabled.
  legacy,
}
