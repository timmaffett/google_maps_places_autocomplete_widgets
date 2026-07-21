# Handoff addendum: iOS App Check runtime verification

**Audience:** the Claude Code session on Tim's Mac (follow-up to
`2026-07-21-ios-verification-handoff.md`, whose rules all still apply).
**Branch:** `native-provider`. `git pull` first.

## Why

The Swift App Check path (`GMSPlacesClient.setAppCheckTokenProvider` +
`GMSPlacesAppCheckTokenProvider.fetchAppCheckToken()` in `PlacesNativePlugin.swift`)
compiled but has never executed. Android's equivalent passed the full enforcement test.
App Check is this package's reason to exist, so iOS must be runtime-verified before 1.0.0.

## Setup (Tim does the console part)

Tim registers an iOS app (bundle id
`com.timmaffett.googleMapsPlacesAutocompleteWidgetsNativeExample`) in the Firebase
console project and downloads `GoogleService-Info.plist`.

## Steps

1. In `packages/google_maps_places_autocomplete_widgets_native/example`:
   - **Preferred (no Xcode surgery):** do NOT add the plist to the Xcode project.
     Instead, in `lib/main.dart`, LOCALLY change the Firebase init to inline options
     using values from the plist Tim downloaded:

     ```dart
     await Firebase.initializeApp(
       options: const FirebaseOptions(
         apiKey: '<API_KEY from plist>',
         appId: '<GOOGLE_APP_ID from plist>',
         messagingSenderId: '<GCM_SENDER_ID from plist>',
         projectId: '<PROJECT_ID from plist>',
       ),
     );
     ```

     and set `useAppCheck = true`. **NEITHER change may be committed** — this is
     local-only test scaffolding (`git stash`/revert when done). Fallback if inline
     options misbehave: put the plist at `ios/Runner/GoogleService-Info.plist` and add
     it to the Runner target in Xcode — but then do NOT commit the `project.pbxproj`
     change either (it would reference a git-ignored file and break other checkouts).
2. `flutter run` on the iOS 16+ simulator. `kDebugMode` already routes to
   `AppleDebugProvider()`. Watch the console for the **App Check debug token** line
   (a UUID) — Firebase prints it on first token use; if it doesn't appear, trigger a
   lookup once (it may fail — fine) and check again.
3. Give the UUID to Tim → he registers it: Firebase console → App Check → Apps → the
   iOS app → Manage debug tokens. (Debug secrets are per-install/per-project.)
4. Verify token flow: do a lookup; there should be NO "App Check token fetch failed"
   style errors. Known gotcha from the Android round: if token exchange fails with 403
   "ExchangeDebugToken ... blocked", the API key Firebase assigned to the iOS app has
   API restrictions missing **Firebase App Check API** / **Firebase Installations API**
   — Tim adds them in Cloud console → Credentials.
5. **Enforcement test (coordinate with Tim — the Windows session flips the switch):**
   Tim tells the coordinating session to set `ENFORCED`; wait for Tim's go (propagation
   ~2–8 min, confirmed when the coordinating session's unattested curl is rejected);
   then run lookups on the simulator — suggestions AND details must work while
   enforcement is active. Report results; the coordinating session reverts to
   UNENFORCED afterward.
6. Revert ALL local test edits (main.dart options/useAppCheck; any pbxproj change),
   confirm `git status` is clean except untracked ignored files, and report:
   token minted ok / lookups under enforcement ok / any fixes needed.

If a Swift fix IS needed (e.g. the token provider is never called, or the SDK rejects
the async provider), fix `PlacesNativePlugin.swift`, verify, commit with a plain
`fix(native): ...` message, push. No attribution trailers. Do not merge or publish.

## Success criteria

iOS simulator app performs autocomplete + details WITH App Check enforcement ENFORCED
on places.googleapis.com — proving the Swift token provider feeds real tokens to the
Places SDK. After this, the release sequence (merge PR #10 → v2.1.0 → publish core →
publish native) proceeds from the coordinating session.
