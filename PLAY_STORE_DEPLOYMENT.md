# Mapcars (Customer App) — Google Play Store Deployment Tracker & History

This document serves as the live log, interactive checklist, and step-by-step record for publishing the **Mapcars** rider app (`com.mapcars.mapcars.user`) to the **Google Play Store**. Mirrors the structure of `mobile/driver_app/PLAY_STORE_DEPLOYMENT.md` — keep both in sync.

---

## 📌 App Overview & Metadata

| Field | Value |
|---|---|
| **App Name** | Mapcars |
| **Package Name (Application ID)** | `com.mapcars.mapcars.user` |
| **Target Country / Region** | United Kingdom (UK) |
| **Category** | Maps & Navigation / Travel & Local |
| **Default Language** | English (United Kingdom) – `en-GB` |
| **Privacy Policy URL** | `https://mapcars.uk/legal/privacy` (canonical — `/privacy.html` 301-redirects here, use the direct URL in Play Console) |
| **Account Deletion Support** | Via email to `info@mapcars.uk` (§10 "Delete account" on the Privacy Policy page) |

---

## 📅 Deployment Progress & History Log

| Date | Milestone / Action | Status | Notes |
|---|---|---|---|
| **2026-08-06** | Android Release Keystore Generation | ✅ Done | `upload-keystore.jks` + `key.properties` generated, backed up to `keys/mobile/customer_app/android/`. |
| **2026-08-09** | Production App Bundle (`.aab`) Build | ✅ Done | `flutter build appbundle --release` → `app-release.aab` (68.6MB), version `0.1.0+2`. |
| **Prior session** | Play Console app entry + Store Listing | ✅ Done (per user) | App created in Play Console; store listing / content rating / data safety reported as already filled in — **verify against Phase 2 checklist below**, since the driver app's equivalent items still show gaps as of 2026-08-10. |
| **2026-08-10** | App Bundle Rebuilt | ✅ Done | Picked up recent auth/profile/settings changes (`rider_auth_service.dart`, `auth_notifier.dart`, `profile_setup_screen.dart`, `edit_profile_screen.dart`, `settings_screen.dart`, etc.) predating the last build. Bumped to `0.1.0+3` → `app-release.aab` (66.1MB), confirmed signed with the release keystore (build.gradle.kts release buildType uses `signingConfigs.release` whenever `key.properties` is present). **Use this build.** |
| **Pending** | App Content & Policy Declarations (re-check) | ⬜ Pending | Confirm Data safety, Privacy Policy, Target Audience, Review Credentials are actually saved in Console (not just drafted in `mobile/docs/play-store/`). |
| **Pending** | Internal / Closed Testing Track Release | ⬜ Pending | First upload of the `0.1.0+3` `.aab` and testing setup. |
| **Pending** | Production Release & Play Store Review Submission | ⬜ Pending | Submit for final Google review. |

---

## 🛠️ Step-by-Step Deployment Roadmap

### Phase 1: Local App & Build Preparation
- [x] **1.1 Keystore Generation**: `upload-keystore.jks` present at `android/upload-keystore.jks`.
- [x] **1.2 Key Properties Setup**: `android/key.properties` present, backed up in `keys/mobile/customer_app/android/`.
- [x] **1.3 Version Code & Name**: `pubspec.yaml` → `0.1.0+3` (bumped from `0.1.0+2`).
- [x] **1.4 Package Name Verification**: `com.mapcars.mapcars.user` confirmed in `android/app/build.gradle.kts`.
- [x] **1.5 Assets & Icons**: launcher icons present under `android/app/src/main/res/mipmap-*`.
- [x] **1.6 Environment & API Keys**: `.env` present; `google-services.json` present at `android/app/`.
- [x] **1.7 Build Release Bundle**: `flutter build appbundle --release` → see history log above.

### Phase 2: Google Play Console Configuration
- [ ] **2.1 Developer Account**: same Google Play Developer account as the driver app (shared org).
- [x] **2.2 Create App**: app entry exists for "Mapcars" (per user, confirmed 2026-08-10).
- [ ] **2.3 Store Listing Setup** — verify still current:
  - [ ] App Name, Short Description, Full Description.
  - [ ] App Icon (512x512 px PNG).
  - [ ] Feature Graphic (1024x500 px PNG).
  - [ ] Phone Screenshots (Min 2, recommended 4-8).
- [ ] **2.4 App Content & Compliance** — verify still current:
  - [ ] Privacy Policy URL (`https://mapcars.uk/legal/privacy`).
  - [ ] App Access (test rider login credentials / phone number for Play review team).
  - [ ] Content Ratings Questionnaire.
  - [ ] Target Audience & Content.
  - [ ] Data Safety Form (see `mobile/docs/play-store/DATA_SAFETY.md`, "Customer app" section).
  - [ ] Government Apps & Financial Features declaration.

### Phase 3: Release & Submission
- [ ] **3.1 Internal / Closed Testing**: Upload `0.1.0+3` `.aab` bundle to Internal Testing track.
- [ ] **3.2 Tester Verification**: Install via Play Store link and verify location, login (phone OTP), profile edit/settings, and maps work.
- [ ] **3.3 Production Release**: Promote build to Production track and submit for Google Review.

---

## 💬 Q&A & Decision History

*Record of key deployment decisions, questions asked, and answers provided.*

- **Q1: Was a Play Console listing already created for the customer app before this tracker existed?**
  - *Answer (2026-08-10):* Yes — user confirmed the app entry and listing work were already done, ahead of this document being created. Phase 2 items above are marked for **re-verification** rather than assumed complete, since no prior written record exists to confirm exactly which sub-items were filled in.
