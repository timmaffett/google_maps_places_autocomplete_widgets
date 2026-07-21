package com.timmaffett.google_maps_places_autocomplete_widgets_native

import android.content.Context
import com.google.android.libraries.places.api.Places
import com.google.android.libraries.places.api.model.AutocompleteSessionToken
import com.google.android.libraries.places.api.model.Place
import com.google.android.libraries.places.api.net.FetchPlaceRequest
import com.google.android.libraries.places.api.net.FindAutocompletePredictionsRequest
import com.google.android.libraries.places.api.net.PlacesClient
import com.google.android.libraries.places.api.auth.PlacesAppCheckTokenProvider
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.SettableFuture
import com.google.firebase.appcheck.FirebaseAppCheck
import io.flutter.embedding.engine.plugins.FlutterPlugin

class PlacesNativePlugin : FlutterPlugin, PlacesNativeApi {
  private lateinit var context: Context
  private var client: PlacesClient? = null
  // Session token lives natively: created lazily, consumed by fetchPlace.
  private var sessionToken: AutocompleteSessionToken? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    PlacesNativeApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    PlacesNativeApi.setUp(binding.binaryMessenger, null)
  }

  override fun initialize(apiKey: String, useAppCheck: Boolean, callback: (Result<Unit>) -> Unit) {
    try {
      Places.initializeWithNewPlacesApiEnabled(context, apiKey)
      if (useAppCheck) {
        Places.setPlacesAppCheckTokenProvider(FirebaseTokenProvider())
      }
      client = Places.createClient(context)
      callback(Result.success(Unit))
    } catch (e: Exception) {
      callback(Result.failure(e))
    }
  }

  private class FirebaseTokenProvider : PlacesAppCheckTokenProvider {
    override fun fetchAppCheckToken(): ListenableFuture<String> {
      val future = SettableFuture.create<String>()
      FirebaseAppCheck.getInstance()
          .getAppCheckToken(false)
          .addOnSuccessListener { future.set(it.token) }
          .addOnFailureListener {
            // Surfaced at warning level: with enforcement on this is the
            // difference between working and rejected requests.
            android.util.Log.w("PlacesNativePlugin", "App Check token fetch failed", it)
            future.setException(it)
          }
      return future
    }
  }

  override fun fetchPredictions(
      query: String,
      includedTypes: List<String>,
      countryCode: String?,
      languageCode: String?,
      callback: (Result<List<NativePrediction>>) -> Unit
  ) {
    val c = client ?: return callback(Result.failure(IllegalStateException("Places not initialized")))
    if (sessionToken == null) sessionToken = AutocompleteSessionToken.newInstance()
    val builder = FindAutocompletePredictionsRequest.builder()
        .setQuery(query)
        .setSessionToken(sessionToken)
        .setTypesFilter(includedTypes)
    if (countryCode != null) builder.setCountries(listOf(countryCode))
    c.findAutocompletePredictions(builder.build())
        .addOnSuccessListener { response ->
          callback(Result.success(response.autocompletePredictions.map { p ->
            NativePrediction(
                placeId = p.placeId,
                fullText = p.getFullText(null).toString(),
                primaryText = p.getPrimaryText(null).toString(),
                secondaryText = p.getSecondaryText(null).toString(),
                types = p.types)
          }))
        }
        .addOnFailureListener { callback(Result.failure(it)) }
  }

  override fun fetchPlace(
      placeId: String,
      languageCode: String?,
      callback: (Result<NativePlaceDetails>) -> Unit
  ) {
    val c = client ?: return callback(Result.failure(IllegalStateException("Places not initialized")))
    val fields = listOf(
        Place.Field.DISPLAY_NAME, Place.Field.FORMATTED_ADDRESS,
        Place.Field.ADDRESS_COMPONENTS, Place.Field.LOCATION)
    val request = FetchPlaceRequest.builder(placeId, fields)
        .setSessionToken(sessionToken)
        .build()
    sessionToken = null  // details call terminates the billing session
    c.fetchPlace(request)
        .addOnSuccessListener { response ->
          val place = response.place
          callback(Result.success(NativePlaceDetails(
              name = place.displayName,
              formattedAddress = place.formattedAddress,
              lat = place.location?.latitude,
              lng = place.location?.longitude,
              components = place.addressComponents?.asList()?.map {
                NativeAddressComponent(
                    types = it.types, longText = it.name, shortText = it.shortName)
              } ?: emptyList())))
        }
        .addOnFailureListener { callback(Result.failure(it)) }
  }
}
