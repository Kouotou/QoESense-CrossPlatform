# Publishing QoESense on Google Play

**Decision (owner + supervisor, 2026-11-17):** the study is **Android only**. The iOS version is
excluded because iOS gives apps almost none of the data the study needs (no RSRP/RSRQ/SINR, no cell
ID, no foreground app). The iOS code stays in the repo but isn't released or maintained.

The app is published from **a colleague's existing Google Play developer account**, which they have
agreed to let the owner use. Listing texts: [play/store-listing.md](play/store-listing.md).
Privacy policy page: [play/privacy-policy.html](play/privacy-policy.html).

## 1. What is ready (branch `release/play-store`)

| Item | State |
|---|---|
| App ID | `io.github.kouotou.qoesense`, final, never change it |
| Version | `2.0.0` (versionCode 1), from `pubspec.yaml` `version: 2.0.0+1` |
| Target SDK | 36 (Android 16), meets Play's target-API requirement |
| Release signing | upload key, see §8. The bundle is verified as signed by `CN=QoESense, O=University of Buea, C=CM` |
| Bundle | `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`. Code shrinking (R8) on, native debug symbols included for Play crash reports |
| Android 15+ fix | the collector runs as a `location` foreground service; `dataSync` is only a fallback, with a clean stop at Android's 6-hour limit (see §9) |
| App icon | new adaptive icon, no longer the Flutter logo |
| Prominent disclosure | the background-access screen opens with Google's recommended sentence: "QoESense collects location data to enable … even when the app is closed or not in use." |
| Privacy policy | written (EN + FR). **It needs a public URL**, see §3 step 2 |
| Listing texts, 512 icon, feature graphic | ready. **Screenshots still to take** |

## 2. What the account owner (your colleague) must do

Only the account owner can do these. Send them this list.

1. Play Console → **Users and permissions** → **Invite new users** → your Google account email.
2. Either give **Admin (all permissions)**, or, more limited, these **account permissions**:
   - "Create, edit, and delete draft apps"
   - "Release to production, exclude devices, and use Play App Signing"
   - "Release apps to testing tracks"
   - "Manage testing tracks and edit tester lists"
   - "Manage store presence"
   - "Manage policy declarations" (App content forms)
   - "View app information and download bulk reports"
3. Tell you which **account type** it is (Play Console → Settings → Developer account → About you):
   - **Organisation** account: you can go to production after testing.
   - **Personal** account created **after 13 November 2023**: Google requires a **closed test with at
     least 12 testers opted in for 14 days in a row** before you can apply for production (§5).
4. Make sure the account's identity verification is complete and the account isn't on hold.

Things to agree with them first:
- The store page shows **their developer name**, and they are the legal publisher under Google's
  Developer Distribution Agreement. Policy warnings for this app reach their account.
- The app's **contact email** on the listing is yours (`bilalkouotou@gmail.com`), set per app.
- Later, the app can be moved to your own developer account with Google's **app transfer** process,
  without participants reinstalling.

## 3. Before the first upload (owner)

1. **Test the release build on a phone.** Release builds are code-shrunk (R8), which can break things
   a debug build doesn't show. Checks:
   - Install `build/app/outputs/flutter-apk/app-release.apk` (uninstall the debug build first: different
     signature).
   - Onboarding to the end, sampling starts, "Upload now" succeeds, a rating reaches Firestore, the app
     restarts after a reboot.
   - **On an Android 15 or 16 phone as well, if you can borrow one**: let it run for more than 6 hours
     with the screen off and confirm it keeps sampling (that's the §9 fix).
2. **Publish the privacy policy at a public URL.** Choose one:
   - **Firebase Hosting** (free on the Spark plan, same `qoesense` project): gives
     `https://qoesense.web.app/privacy-policy.html`. Recommended, but it is a deployment, so it needs your
     go-ahead.
   - **Google Sites** (sites.google.com): paste the text, publish, and copy the URL.
3. **Record two short screen videos** with the phone (≤ 30 s each), upload them to YouTube as
   **Unlisted**:
   - **Video A (background location)**: Welcome → Consent → Location screen → Background access screen
     showing the disclosure sentence → the Android "Allow all the time" choice → Status screen with
     collection running → screen off → wake the phone and show that samples kept growing.
   - **Video B (foreground services)**: the "collection active" notification while another app is open,
     then the Status screen showing new samples.
4. **Take 4 screenshots**: Welcome, Consent, Status, rating prompt.

## 4. Create the app and do the first upload

1. Play Console → **Create app**:
   - name `QoESense`; language English (UK); **App**; **Free**;
   - accept the declarations.
2. **Test and release → Testing → Internal testing → Create new release**:
   - accept **Play App Signing** (Google keeps the app-signing key; you only keep the upload key);
   - upload `app-release.aab`; release name `2.0.0 (1)`; save and roll out to internal testers (add
     your own email).
3. Install it from the internal-testing link on your phone. This is the real Play build.
4. Fill **Grow users → Store presence → Main store listing** from `play/store-listing.md`, plus the
   graphics.
5. Fill **Policy → App content** (§6). Play Console lists exactly which forms it needs after the first
   upload.

## 5. Testing tracks before production

- **Personal account (post-Nov 2023):**
  - create a **Closed testing** track and add at least **12 testers** (their Google accounts, as an
    email list or a Google Group);
  - they must **opt in through the link and stay opted in for 14 consecutive days**;
  - then use **Apply for production** on the Dashboard; Google asks a few questions about the test.
  - **Tip:** run the study's first participants as these testers. They install from Play, they're real
    users, and the 14 days count toward the study.
- **Organisation account:** go straight to production after the internal test, if you want.
- Production review usually takes a few days, and longer for apps with sensitive permissions.

## 6. App content answers

| Form | Answer |
|---|---|
| Privacy policy | the public URL from §3 step 2 |
| App access | "All functionality is available without special access". No login: the app signs in anonymously. Note: "on first launch the app shows a consent screen and permission screens; accept them to reach the Status screen" |
| Ads | No ads |
| Content rating | Questionnaire, category **All other app types**. Answer No to violence, sexuality, gambling and the others. Users interact or exchange content: **No**. Shares the user's current location **with other users**: **No** (location goes only to the research team, which the Data safety form covers) |
| Target audience | **18 and over** only. Not designed for children |
| News app | No |
| Health apps | No health features |
| Financial features | None |
| Government app | No |
| Data safety | see below |
| Foreground service permissions | see below |
| Location permissions (background) | see below |

### Data safety

General: **collects data: Yes**. **Shares data with third parties: No** (Firebase is a service provider
acting for you, which Google says isn't "sharing"). **Encrypted in transit: Yes.** **Users can request
deletion: Yes** (by email, with the device ID). **Collection is required** (the app has no other use).

| Data type (Play category) | Collected | Purpose | Notes |
|---|---|---|---|
| Location → **Precise location** | Yes | App functionality | with every sample, also in the background |
| Location → **Approximate location** | Yes | App functionality | |
| App activity → **Installed apps** | Yes | App functionality | the package name of the app on screen |
| App activity → **Other user-generated content** | Yes | App functionality | the 1–5 ratings and the "what were you doing" answer |
| App info and performance → **Other app performance data** | Yes | App functionality | network signal and throughput/latency measurements |
| Device or other IDs | Yes | App functionality | the anonymous installation ID |

Don't choose "Analytics" or "Advertising" as the purpose for location: background location for
analytics is forbidden by policy. Data is processed **ephemerally: No** (it is stored).

### Foreground service declaration

Play Console asks for each type in the manifest. Suggested texts:

- **location**: "QoESense is a research app that measures mobile network quality. Its foreground service
  records a network measurement with the device's location about once a minute while the participant
  goes about their day, after they have opted in. Android only returns cell signal measurements to apps
  with location access, and the location maps network coverage. The task starts when the participant
  finishes onboarding, shows a persistent notification, and stops when they turn collection off in the
  app." Video: Video B.
- **dataSync**: "Fallback type for the same measurement service on phones where location isn't granted.
  The service then records network measurements without location and stops at Android's time limit."
  Video: Video B.

### Background location declaration (the main review risk)

Google allows background location only when it is the app's core feature and benefits the user. Its
guidance names "map nearby internet speeds" as a feature that should usually work in the foreground
only, so this app is **at real risk of rejection**. The honest, strongest argument is technical:

> "QoESense's single core feature is passive mobile-network measurement for a university research
> study that participants explicitly opt into. Android's TelephonyManager only returns cell signal
> readings (RSRP, RSRQ, SINR, cell identity) to apps holding location permission. The study must
> measure the network while participants use other apps (WhatsApp, Facebook, video calls), so the
> app is never in the foreground when the measurement matters. Without background location, the
> app can't record any signal readings after a reboot or service restart. The in-app consent and a
> dedicated disclosure screen explain this before the permission is requested."

Feature to name in the form (only one is allowed): **"Passive mobile network quality measurement"**.
Video: Video A.

**If it's rejected:** remove `ACCESS_BACKGROUND_LOCATION` from the manifest and the background-access
request. The service keeps its while-in-use location access while it keeps running after onboarding.
But after a reboot or a restart by Android, it runs without location and cell readings until the
participant opens the app. This change needs a new build and a device re-test before resubmitting.

## 7. After the app is live

1. **Firebase**: Project settings → Your apps → Android `io.github.kouotou.qoesense` → **Add fingerprint**
   with the **app-signing key SHA-256** from Play Console → Test and release → App integrity. App Check
   (monitoring mode) needs it to accept the Play build.
2. Play Console → App integrity → **Link the Cloud project `qoesense`** (Play Integrity API).
3. Keep App Check in monitoring mode. Enforcement steps are in [APP_CHECK.md](APP_CHECK.md).
4. Ask participants still on the old reference app (`com.example.qoesense`) to install the Play version
   and uninstall the old one.
5. The daily PC export keeps working unchanged.

## 8. Signing keys (keep these safe)

| File | Where | Notes |
|---|---|---|
| Upload keystore | `C:\Users\Ahmad\QoESense-keys\qoesense-upload.jks` | alias `upload`, valid to 2053 |
| Passwords | `android/key.properties` (gitignored) and `C:\Users\Ahmad\QoESense-keys\key.properties.backup` | |

- **Copy the whole `QoESense-keys` folder to a private, offline place** (USB drive and/or a password
  manager). Never commit or email it.
- If it's ever lost: with Play App Signing, the account owner can ask Google to reset the upload key.
  Participants aren't affected.
- Upload key certificate SHA-256: `F7:0A:2A:48:D4:43:B9:D2:C3:89:D2:BB:71:A7:B4:A4:AF:BC:A0:71:BF:51:65:F6:DD:C6:66:15:91:68:AA:C2`

## 9. Android 15+ background limits (fixed before release)

On Android 15 and later, apps targeting SDK 35+ may run a **`dataSync`** foreground service for at
most **6 hours per 24 h** in the background, and may not start one at boot. The old service type
`dataSync|location` was therefore under the limit, and the service didn't handle `onTimeout`. After
6 hours the app would have **crashed** and collection would have stopped. The test phone runs
Android 12, so this never showed in testing.

Now:
- with location granted, the service runs as **`location` only**, which has no time limit;
- `dataSync` is a fallback, tried only if Android refuses the location type;
- `onTimeout` stops the service cleanly, and any refused start is logged instead of crashing;
- opening the app restarts collection.

Unit-tested in `ForegroundTypesTest`. **Not yet run on an Android 15+ device** (§3 step 1).

## 10. Every later update

1. Raise the version in `pubspec.yaml` (e.g. `2.0.1+2`). The number after `+` must always go up.
2. `flutter build appbundle --release` (on this PC: `C:\Users\Ahmad\flutter\bin\flutter`).
3. Upload it to the same track, then promote it.
