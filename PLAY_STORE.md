# Publishing FieldRoute on Google Play

Background location is a sensitive permission, so Google reviews it by hand. Expect extra steps. Policies change, so check the current wording in Play Console before you submit.

## 1. Build

```bash
keytool -genkey -v -keystore ~/fieldroute.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fieldroute
# create android/key.properties and reference it in android/app/build.gradle (docs.flutter.dev/deployment/android)
flutter build appbundle --release
```
Upload `build/app/outputs/bundle/release/app-release.aab`. Turn on Play App Signing. Use your own `applicationId`, and keep targetSdk at the level Play currently requires (new Flutter versions already do).

## 2. Permissions Declaration (Play Console → App content)

You will be asked about **background location** and **foreground service (location)**.

Suggested wording for the background location declaration:

> FieldRoute is used by field sales and service staff. The app records when a worker arrives at and leaves an assigned client site (check-in and check-out) and calculates worked hours. This needs location while the app is closed or not in use, because workers keep the phone in a pocket while driving between sites. Location is only collected while the worker has an active route for the day, and a persistent notification is shown while tracking is on.

Foreground service type: **location**. Use the same explanation.

## 3. Demo video (required for background location)

Record a short screen video (unlisted YouTube link) showing, in this order:
1. The in-app **disclosure dialog** ("Allow location all the time") before the system prompt.
2. The system permission prompt and choosing "Allow all the time".
3. The persistent "Route tracking is on" notification.
4. Arriving at a site: the automatic check-in notification.
5. Where in the app the worker can see the tracking status (Profile → Tracking).

The app already contains the disclosure dialogs (`lib/services/permission_gate.dart`). Do not remove them.

## 4. Store listing and privacy

- **Privacy policy URL is required.** It must say you collect precise location (including in the background), photos (task proof), name and email, why, and how long you keep them.
- **Data safety form:** Location (precise, collected, used for app functionality), Photos, Name, Email, Device ID / push token. Data is encrypted in transit; users can request deletion.
- The app description should say that location is used for check-in/out and worked hours.

## 5. Testing track

New personal developer accounts must run a **closed test** with a minimum number of testers for a minimum number of days before production access (the requirement has been 12 testers for 14 days; check the current number). Organisation accounts may differ. Start the closed test early.

## 6. iOS

Needs a Mac, an Apple Developer account, the `Info.plist` strings and Background Modes from `platform_setup/`, and an APNs key uploaded in Firebase. `flutter build ipa --release`, upload with Transporter. No Mac: use Codemagic.
