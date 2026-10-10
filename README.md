# FieldRoute

Field-visit app (Flutter + Firebase + OpenStreetMap). Replaces the Expo app with a Play Store friendly build.

## What it does

**Admin**
- Plans a route for a worker and date: add stops, tap the map to choose each client site, set the **check-in radius** (50 to 500 m) and a target, add tasks (a `*` at the start of a task line means "photo required"), drag to re-order.
- **Send route** saves it and pushes a notification to the worker.
- **Live** tab: every active worker shown as a car on the map, updated every 10 seconds.

**Worker**
- **My Route**: Today / Tomorrow / Calendar, map with the planned road line, numbered stops, a circle showing each stop's radius, and a car icon for the worker's live position. Focus Vehicle, Fit Route, Optimize, Hide Map, filters, trip total / completed / remaining.
- **Automatic check-in** when the worker is inside the radius, **automatic check-out** when they leave. A notification is shown each time. The Check In button also works manually once inside the radius.
- **Worked hours** = check-out time minus check-in time, saved on the stop.
- Tasks, photo proof (camera, uploaded to Firebase Storage), notes, and a Navigate button that opens Google Maps.

## How the geofence stays accurate

- GPS fixes with accuracy worse than 50 m are ignored.
- Check-in needs 2 fixes in a row inside the radius, check-out needs 2 fixes in a row outside radius + 15 % (15 to 60 m margin). This stops GPS jitter from flipping the status.
- Check-in and check-out use the GPS fix time, not a typed or button time. The server time is stored beside it for audit.
- Both writes are Firestore transactions and are safe to repeat (no double check-in).
- Background tracking uses an Android **foreground service** (visible "Route tracking is on" notification) and the iOS background location mode.

## Setup

```bash
cd fieldroute
flutter create --org com.yourcompany --platforms=android,ios,web .
flutter pub get
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR-PROJECT-ID
```

Firebase console: enable **Authentication → Email/Password**, create **Firestore**, create **Storage**.

```bash
firebase deploy --only firestore:rules,storage
cd functions && npm install && cd ..
firebase deploy --only functions        # push notifications (needs the Blaze plan)
```

Then paste the blocks from `platform_setup/` into the Android manifest and iOS `Info.plist`, and run `flutter run`.

**First admin:** sign up in the app (creates a worker), open Firestore → `users/{uid}` and change `role` to `admin`.

## Test the geofence without walking

Android emulator: `...` (Extended controls) → **Location** → set a point or load a route (GPX). Put a stop's location (use the map picker's "my location" while the emulator is there) and move the emulator in and out of the circle. You should see the notification and the IN/OUT times fill in.

## Notes

- Map tiles come from the public OpenStreetMap server and routes from the public OSRM demo server. They are fine for development and small teams. For a real rollout, switch to a paid tile provider (MapTiler, Stadia, Mapbox) and a hosted routing API: only `TileLayer(urlTemplate...)` and `RoutingService.drivingRoute` need to change.
- "Optimize" orders the remaining stops by nearest-next-stop. It is not a perfect shortest tour for many stops.
- Some phone makers (Xiaomi, Oppo, Vivo, Samsung) stop background apps. Tell workers to set FieldRoute battery usage to **Unrestricted**. See dontkillmyapp.com.
- Web (Chrome) is only for previewing screens. Background location, push and some camera features need a real phone.

## Google Play Store Publishing Guide

Before publishing to the Google Play Console, complete the following mandatory steps:

### 1. Update Package Name (`applicationId`)
Google Play rejects generic package names (e.g. `com.yourcompany.*` or `com.example.*`).
- Open `android/app/build.gradle.kts` and change:
  ```kotlin
  defaultConfig {
      applicationId = "com.yourbrand.fieldroute" // Change to your unique package ID
      ...
  }
  ```
- Make sure to update the matching `applicationId` inside `android/app/src/main/AndroidManifest.xml` and download your updated `google-services.json` from Firebase.

---

### 2. Generate Release Keystore & Build App Bundle (.aab)
1. **Generate your production upload keystore**:
   ```bash
   keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **Build the release Android App Bundle (AAB)**:
   ```bash
   flutter build appbundle --release --no-tree-shake-icons
   ```
   *The upload-ready file will be created at:*  
   `build/app/outputs/bundle/release/app-release.aab`

---

### 3. Google Play Background Location Declaration (Policy Requirement)
Because FieldRoute tracks locations and performs automatic check-in/out in the background even when the app is closed, Google requires specific declarations in **Play Console → App content → Location permissions**:

- **Core App Functionality**: Choose **Yes**, the app needs background location for core functionality.
- **Declaration Statement (Copy-paste this into Play Console)**:
  > *"FieldRoute is a field sales and service route management application. The app automatically detects when a worker arrives at or leaves assigned client sites (automated check-in and check-out) and calculates accurate worked hours. This requires location access while the app is closed or in the background because workers travel between client locations with their phones in their pockets or mounted in vehicles. A persistent notification is displayed whenever active tracking is running."*
- **Foreground Service Type**: Select **`location`**.

---

### 4. Demo Video for Google Reviewers (Mandatory)
Record a short (30–60 second) screen recording on a phone (upload as an **Unlisted YouTube Video**) showing:
1. The prominent in-app disclosure dialog (*"Allow location all the time"*).
2. The Android system permission prompt granting *"Allow all the time"*.
3. The active foreground notification in the status bar (*"FieldRoute is active - Route tracking is on"*).
4. Entering a client site radius and seeing the instant automatic **"Checked in at [Stop Name]"** notification.

---

### 5. Privacy Policy & Data Safety Form
- **Privacy Policy URL (Required)**: Must state that precise location (foreground and background), camera photo proofs, and worker names/emails are collected strictly for route assignment and visit verification.
- **Data Safety Form**:
  - **Location**: Precise location (Collected & Encrypted in transit, ephemeral background geofence detection).
  - **Photos**: Uploaded as proof of work.
  - **Personal Info**: Name and Email for user login.

---

### 6. Closed Testing Track (New Developer Accounts)
- Personal Google Play developer accounts require **closed testing** with at least 12–20 testers for 14 days before applying for Production release.
- Upload `app-release.aab` to the **Closed Testing** track to start testing early.

---

See `PLAY_STORE.md` for additional configuration details.
