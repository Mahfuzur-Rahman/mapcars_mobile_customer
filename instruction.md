# Mapcars Customer — Run & Test Instructions

Flutter **customer** mobile app (`mapcars_mobile`). Feature-first structure under
`lib/src/`. Talks **only** to the Mapcars .NET API.

> ✅ Flutter is installed, native folders (`android/`, `web/`) are generated, and
> all **18 customer screens** are built as a clickable/swipeable **UI prototype**
> (no backend wired yet — sample data is hardcoded). Just run it (section 5).

## The prototype
- Opens on the **Splash → Intro (swipe) → Phone → OTP → Profile → Home** flow.
- From **Home** tap "Where to?" to walk the whole ride flow (choose → confirm →
  searching → tracking → in-progress → completed → rate). The home screen uses live Google Maps.
- The splash has a **"Browse all screens"** link (route `/screens`) to jump to
  any screen directly.
- Design system lives in `lib/src/core/` (theme `brand.dart` / `app_theme.dart`,
  components `widgets/mc.dart`, map `widgets/map_background.dart`); screens are in
  `lib/src/features/<onboarding|ride|account>/presentation/`.

## 1. Install Flutter (already done on this machine)

```powershell
winget install --id=Google.Flutter -e
winget install --id=Google.AndroidStudio -e   # Android SDK + adb + emulator
flutter doctor
```

## 2. Native folders — already generated
If you ever need to regenerate them (back up `pubspec.yaml` + `lib/main.dart` first):

```powershell
cd mobile/customer_app
flutter create --platforms=android,web --org com.mapcars --project-name mapcars_mobile .
flutter pub get
```

## 3. Config / accounts you will need

| Service | What for | Where it goes | Free to start? |
|---------|----------|---------------|----------------|
| **Google Maps** | Map rendering + places search | `.env` → `GOOGLE_MAPS_KEY` | Yes — free tier |
| **Mapcars API** | All app data | `.env` → `API_BASE_URL` | Live / Local |

```powershell
copy .env.example .env   # then edit values
```

> A working `.env` with default values is already committed so the app runs immediately.

## 4. Point the app at your API

- **Android emulator:** `API_BASE_URL=http://10.0.2.2:5126` (already the default).
- **Physical Android phone:** use your PC's LAN IP, e.g.
  `API_BASE_URL=http://192.168.1.20:5126`. Find it with `ipconfig`. Phone and PC
  must be on the same Wi-Fi. (Also run the API on HTTP, not HTTPS, for easy local testing.)

## 5. Run & test on your Android phone

1. Phone: Settings → About → tap **Build number** ×7 → enable **USB debugging**.
2. Plug in via USB, accept the debugging prompt.
3. ```powershell
   flutter devices    # confirm your phone shows up
   flutter run
   ```
4. The home screen shows an **API connection** indicator. Green = it reached
   `/api/v1/ping`. Start the API first (`../../api/instruction.md`).

> 💡 You can run **both apps at once** on two devices/emulators — start this
> customer app here and the driver app from `mobile/driver_app`.

Hot reload: press `r` (reload) / `R` (restart) / `q` (quit) in the terminal.

## 6. Maps — Google Maps + current location (wired)

The home screen shows a live **Google map** centered on the device's current
location (blue dot + re-center button), via `google_maps_flutter` + `geolocator`.

**One-time setup — add your API key:**

1. In **Google Cloud Console**: create/select a project → **APIs & Services →
   Library** → enable **"Maps SDK for Android"**. (Enable *Maps SDK for iOS* too
   once iOS is generated.)
2. **APIs & Services → Credentials → Create credentials → API key.** Restrict it
   to Android apps + the Maps SDK for Android for production.
3. Put the key in `android/local.properties` (gitignored):
   ```properties
   MAPS_API_KEY=AIza...your key...
   ```
   Gradle injects it into `AndroidManifest.xml` as `${MAPS_API_KEY}` at build
   time — the key is never committed.
4. `flutter pub get` then `flutter run`. On first launch the app asks for the
   **location permission**; grant it to see your position.

> If the map is a blank grey grid, the key is missing/invalid or the Maps SDK
> for Android isn't enabled — check `flutter run` logs for a Maps auth error.

### iOS (requires a Mac + Xcode to build)

The `ios/` project is wired the same way. **Building iOS only works on macOS.**

1. Google Cloud Console → enable **"Maps SDK for iOS"** (in addition to Android).
   You can reuse the same project; restrict the key to iOS apps for production.
2. Put the key in `ios/Flutter/Maps.xcconfig` (gitignored):
   ```
   MAPS_API_KEY=AIza...your key...
   ```
   It flows into `Info.plist` as `GMSApiKey` (`$(MAPS_API_KEY)`), which
   `AppDelegate.swift` reads and passes to `GMSServices.provideAPIKey(...)`.
3. On the Mac: `flutter pub get && cd ios && pod install && cd ..`, then
   `flutter run` on a device/simulator. Deployment target is **iOS 14**
   (required by the Maps SDK); the location prompt uses
   `NSLocationWhenInUseUsageDescription` in `Info.plist`.

## 7. "Continue with Google" — what's still needed

The button is on the sign-in and sign-up screens and is fully wired
(`google_sign_in` → ID token → `POST /api/v1/auth/riders/google` → session). It is **not
functional yet** — until the two IDs below exist, tapping it says
"Google sign-in isn't set up yet" instead of failing silently.

1. **Google Cloud console** (project `mapcars-2b5a8`, the same one as Firebase) →
   *APIs & Services → Credentials*:
   - Create an **Android** OAuth client — package name `com.mapcars.mapcars.user` plus the
     **SHA-1** of both the debug keystore and the upload keystore.
     ```powershell
     keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
     ```
   - Create (or reuse) a **Web** OAuth client. Its ID is the one the app needs.
2. **`.env`** → `GOOGLE_SERVER_CLIENT_ID=<the **Web** client ID>`.
   Counter-intuitive but correct: Android passes the *Web* client ID as
   `serverClientId`, and that is what makes Google mint an ID token our API can
   verify. Mirror the edit into `keys/mobile/customer_app/.env`.
3. **API** → `Google:ClientId` must include that same Web client ID, or the API
   rejects the token. On the GCE VM it is the `Google__ClientId` env var in
   `~/mapcars-api.env`.

Until step 3 is done the API skips the audience check entirely, so don't enable
Google sign-in in production before setting it.
