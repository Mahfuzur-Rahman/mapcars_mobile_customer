# Mapcars Customer — Run & Test Instructions

Flutter **customer** mobile app (`mapcars_mobile`). Feature-first structure under
`lib/src/`. Talks **only** to the Mapcars .NET API.

> ✅ Flutter is installed, native folders (`android/`, `web/`) are generated, and
> all **18 customer screens** are built as a clickable/swipeable **UI prototype**
> (no backend wired yet — sample data is hardcoded). Just run it (section 5).

## The prototype
- Opens on the **Splash → Intro (swipe) → Phone → OTP → Profile → Home** flow.
- From **Home** tap "Where to?" to walk the whole ride flow (choose → confirm →
  searching → tracking → in-progress → completed → rate). The map screens use a
  stylised vector map (real Mapbox comes later).
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
| **Mapbox** | Map rendering on device | `.env` → `MAPBOX_TOKEN` | Yes — free tier |
| (the API) | All app data | `.env` → `API_BASE_URL` | Local, free |

```powershell
copy .env.example .env   # then edit values
```

> A working `.env` with placeholders is already committed so the app runs
> immediately. Set a real `MAPBOX_TOKEN` before adding the map screen.

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

## 6. Maps (later)
Uncomment `mapbox_maps_flutter` in `pubspec.yaml`, set `MAPBOX_TOKEN`, and add the
Android `minSdkVersion 21` + Mapbox download token per the package README.
