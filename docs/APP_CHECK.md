# Firebase App Check

**Status (2026-11-16): in the app, monitoring mode. NOT enforced.**

## Why

The app's Firebase configuration (API key, project ID) ships inside every APK/IPA, so anyone
can copy it and call Firestore directly. The security rules (deployed 2026-11-16) already stop
anyone from reading or overwriting another participant's data. However, on the free plan a
script could still create junk anonymous users and use up the **daily free quotas**, which
would stall uploads for every participant until the next day. App Check closes that hole:
once it's enforced, Firebase only accepts requests carrying a token that proves they come from
the genuine app on a genuine device.

## What is in the app

`lib/src/data/backend/app_check.dart`, called from `openBackend()` in every engine (UI,
collector, upload):

| Build | Android provider | iOS provider |
|---|---|---|
| debug | Debug provider (prints a debug token in logcat) | Debug provider (token in the Xcode console) |
| release | **Play Integrity** | **DeviceCheck**. Moves to App Attest + DeviceCheck fallback once the paid Apple account adds the App Attest capability. |

It fails open: if activation fails, everything works as before. Nothing is refused while
enforcement is off.

## Why it is not enforced yet (each item blocks enforcement)

1. **Android:** Play Integrity tokens can only be checked once the app is registered in the
   Firebase console with its **app-signing SHA-256**. That key comes from Play Console (Play App
   Signing), which needs the Google Play developer account (store blocker R2).
2. **iOS:** DeviceCheck / App Attest need a key or capability from the **paid Apple Developer
   Program** (store blocker R4). The free signing team can't provide them.
3. **The reference app** (`com.example.qoesense`) has no App Check. Enforcing would refuse its
   participants' ratings and consent writes. It must be retired first (decision D-1 handover).
4. Test devices running **debug builds** must have their debug tokens added to the allow list.

## Turning enforcement on (later, in this order)

1. **Play Console:** create the app, enable Play App Signing, and copy the **app signing key
   SHA-256** (Setup → App integrity). Add it to the Firebase Android app (Project settings →
   Your apps).
2. **Firebase console → App Check → Apps:**
   - Android: register with **Play Integrity**.
   - iOS: register with **DeviceCheck** (upload the DeviceCheck key from the Apple Developer
     account), or App Attest.
   - Set the **token TTL to about 24 h**. The default is 1 h, which means ~24 token exchanges
     per phone per day. Play Integrity's default quota is 10,000 classic requests/day, so a 1 h
     TTL would cap the study at ~400 Android phones. A 24 h TTL allows ~10,000.
3. **Debug tokens:** add each test phone's debug token (App Check → Apps → ⋮ → Manage debug
   tokens). Search logcat for `DebugAppCheckProvider`, or the Xcode console for
   `App Check debug token`.
4. **Watch the metrics for at least 1–2 weeks** (App Check → APIs → Cloud Firestore). Enforce
   only when nearly all requests are **verified**. Unverified ones mean phones still running the
   reference app or an old build.
5. Enforce, one service at a time: **Cloud Firestore** first, then Cloud Storage (if billing
   returns), then Authentication. It can be switched off again instantly if something breaks.

## Cost

App Check itself is free. Play Integrity's standard quota is free (see the TTL note above).
DeviceCheck and App Attest are free with the Apple Developer Program.
