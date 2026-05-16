# Push Setup (Point 1: Push First, Fallback Later)

This guide configures production push notifications with:
- Push as primary channel (FCM)
- WhatsApp/SMS only as fallback

## Current code status

Already implemented:
- Backend push-first strategy in `server.js`
- Fallback to Twilio only if push delivers to zero drivers
- Device-token registration endpoint:
  - `POST /api/driver/devices/register`
- Flutter driver app auto-registers token if available
- Web token retrieval supports `FIREBASE_WEB_VAPID_KEY`

## 1) Firebase project

1. Create/select a Firebase project.
2. Enable Cloud Messaging.
3. Save these values:
- Project ID
- Web app config (if using Flutter web)
- Web Push certificate key pair (VAPID key)

## 2) Backend (Node) configuration

Set env vars used by `config/firebase.js`:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY` (with `\n` escaped newlines)

Optional fallback (Twilio):
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_WHATSAPP_FROM`
- `TWILIO_SMS_FROM`

Behavior:
1. Try FCM push first.
2. If push delivered to zero drivers, fallback to WhatsApp/SMS (if enabled in ride request and Twilio env exists).

## 3) Flutter Web setup

In `flutter_app/.env` add:
- `FIREBASE_WEB_VAPID_KEY=<your_vapid_key>`

Then:
1. `flutter pub get`
2. Build/run as usual

## 4) Android/iOS note for this repository

This workspace currently does not include `flutter_app/android` or `flutter_app/ios` folders.
That means native FCM platform wiring cannot be completed in this repo state.

To enable Android/iOS push:
1. Recreate native folders (if missing), e.g. by creating a new Flutter app shell and migrating `lib/`.
2. Add Firebase platform files:
- Android: `google-services.json`
- iOS: `GoogleService-Info.plist`
3. Configure platform build files per FlutterFire docs.
4. Initialize Firebase in app entry points for each target.

## 5) Driver token registration flow

Driver app sends token via:
- `POST /api/driver/devices/register`

Payload:
```json
{
  "driverId": "DRV-1000",
  "token": "fcm-token",
  "platform": "flutter",
  "appState": "foreground"
}
```

## 6) Verification checklist

1. Start backend with Firebase env vars.
2. Open driver app and verify token registration endpoint receives data.
3. Create a ride with out-of-app notification preference enabled.
4. Confirm push arrives.
5. Disable/remove driver token and confirm fallback WhatsApp/SMS triggers.

## 7) Operational recommendations

- Keep push as default, cheap, fast channel.
- Use Twilio only as backup for critical rides or no-push scenarios.
- Monitor:
  - push success rate
  - assignment latency
  - fallback usage rate
  - messaging cost per completed ride
