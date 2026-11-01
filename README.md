# Ledger

*Track. Understand. Take Control.*

A Flutter Android app that connects **directly to your Gmail over IMAP from
your phone** and tracks your HDFC Bank and Union Bank UPI transactions — no
backend, no server in between, nothing to host. It reads your bank alert
emails, parses amount/date/merchant, stores everything locally on-device,
and lets you categorize and analyze your spending.

The real, maintained app is in [`mobile_app/`](mobile_app/) — that's what
you build, install, and run. (The Python/Flask files at the repo root —
`app.py`, `email_service.py`, `templates/`, `fin_track.db` — are an early
desktop prototype that predates the mobile app and is **no longer
maintained**. It's left in the repo for reference only; ignore it unless
you specifically want to look at the original prototype.)

This README has everything needed to pick this project back up later:
how to configure it, install it, and run/build it from scratch. For deeper
technical/architecture notes (screens, services, design system, known
backlog), see [`mobile_app/README.md`](mobile_app/README.md).

## What it does

- Connects to Gmail via IMAP and fetches your HDFC/Union Bank UPI alert
  emails directly on your phone.
- Parses amount, date, merchant, reference number, and bank from each
  email and stores it in a local SQLite database on the device.
- Lets you categorize transactions (custom categories, not a fixed list),
  add notes, and browse/filter your history.
- Shows spending analytics: totals, category/bank breakdowns, and trends,
  all computed from the local database.
- Runs a periodic background sync (~every 15 min via Android WorkManager)
  that fetches new mail and shows a notification per new transaction.
- Optional, manual, append-only backup to a Google Sheet.

Your email and the IMAP app password are the only two credentials this
app ever handles, and the app password is stored in Android's encrypted
Keystore via `flutter_secure_storage`. No third-party server ever sees
your email or your mail.

## Requirements

- **Flutter SDK** (this project targets Flutter 3.41+ / Dart 3.11+)
- **Android Studio** with the **Android SDK**, **platform-tools**, and
  **emulator** components installed
- A Java runtime for Gradle — Android Studio ships its own (JBR), and
  Flutter uses it automatically, so you don't need to install Java
  separately

Check your machine is ready at any time:

```bash
flutter doctor
```

You want green checks under "Flutter" and "Android toolchain". The
"Xcode" section can be ignored — this app is Android only.

## One-time project setup

```bash
cd mobile_app
flutter pub get
```

Everything below (credentials, running, building) happens inside
`mobile_app/`.

### Get a Gmail App Password (the "app passcode")

The app needs this to log into Gmail over IMAP — it is **not** your normal
Gmail password.

1. In Gmail: **Settings → See all settings → Forwarding and POP/IMAP** →
   enable **IMAP access**.
2. You need 2-Step Verification turned on for your Google account (app
   passwords require it). Then go to
   [Google Account → Security → App passwords](https://myaccount.google.com/apppasswords),
   create one for **"Mail"**, and copy the 16-character code it gives you.
3. In the app: **Settings → Gmail connection**, enter your Gmail address
   and paste that 16-character app password, then Save.

If you ever revoke or regenerate the app password in your Google Account,
you'll need to re-enter the new one in the app's Settings screen.

### (Optional) Google Cloud setup, only if you want Google Sheets backup

The in-app **"Connect Google account"** / **"Sync to Google Sheet"**
feature needs the app registered in a free Google Cloud project. Skip this
section entirely if you don't need that backup — everything else works
without it.

1. Go to the [Google Cloud Console](https://console.cloud.google.com/),
   create a project (or reuse one).
2. **APIs & Services → Library** → enable the **Google Sheets API**.
3. **APIs & Services → OAuth consent screen** → configure it (External is
   fine for personal use; add your own Google account as a test user if
   prompted).
4. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   → Application type **Android**:
   - **Package name**: `com.fintrack.mobile_app` (this is the app's
     Android package id — it stays this even though the app itself is now
     called "Ledger"; keep it as-is, since this registration and any
     already-signed installs depend on it).
   - **SHA-1 certificate fingerprint** of the signing key. For debug
     builds (what `flutter run` uses):

     ```bash
     cd mobile_app/android
     ./gradlew signingReport
     ```

     Look for the `debug` variant's `SHA1:` line and use that value — it's
     specific to the machine/keystore that generated it, so always
     re-check with this command rather than trusting an old value from
     notes.
   - No client secret needed for the Android client type.
5. Save. No app code changes are needed — `google_sign_in` picks up the
   registration automatically from package name + SHA-1 + the Sheets API
   being enabled on the project.

If you later build a **release** APK signed with a different keystore than
the debug one, add that keystore's SHA-1 as a second OAuth client (same
steps) or Google Sign-In will fail only in release builds.

No billing account is required — the Sheets API is free at this scale.

## Running it

### On the Android Emulator (test on your laptop)

1. Open **Android Studio → More Actions → Virtual Device Manager** and
   make sure at least one emulator exists (any recent Pixel + latest API
   level is fine). Or from the CLI:

   ```bash
   flutter emulators
   flutter emulators --launch <emulator_id>
   ```

2. With the emulator running:

   ```bash
   cd mobile_app
   flutter run
   ```

   Flutter auto-detects the emulator as the target. Hot reload works as
   usual (`r` in the terminal, or save in your editor).

3. In the app: **Settings** → enter email + app password → **Save** →
   **Transactions** → **Fetch**.

### On a physical Android phone

1. On the phone: **Settings → About phone** → tap **Build number** 7
   times to unlock Developer Options, then **Settings → Developer
   options** → enable **USB debugging**.
2. Connect the phone via USB and accept the "Allow USB debugging?" prompt
   on the phone.
3. Confirm it's detected:

   ```bash
   flutter devices
   ```

4. Run:

   ```bash
   cd mobile_app
   flutter run
   ```

   This installs and launches a debug build directly on the phone.

### Running/opening the project in Android Studio

You don't have to use Android Studio at all (the `flutter run` CLI above
is enough), but if you want the IDE:

1. Open Android Studio → **Open** → select the `mobile_app` folder (not
   the repo root).
2. Install the **Flutter** and **Dart** plugins if prompted
   (**Settings/Preferences → Plugins**).
3. Pick a target device/emulator from the device dropdown in the toolbar,
   then press **Run** (▶) or **Debug** (🐞).
4. The `android/` subfolder is the generated native Android project —
   Android Studio can also open just that folder directly if you ever need
   to touch native Android code (Gradle files, manifest, etc.), but for
   everyday Flutter work open `mobile_app/` itself.

## Building a release APK to install manually

If you'd rather build once and just copy the APK over (no cable or
`flutter run` session needed afterwards):

```bash
cd mobile_app
flutter build apk --release
```

Output:

```
mobile_app/build/app/outputs/flutter-apk/app-release.apk
```

Getting it onto your phone:
- **USB**: `adb install build/app/outputs/flutter-apk/app-release.apk`
  (phone connected, USB debugging on)
- **Any file transfer**: email it to yourself, Google Drive, AirDrop
  equivalent, plain USB file copy, etc. — then open the `.apk` on the
  phone. Android will prompt to allow "install from this source" the
  first time; allow it, since this is your own build, not a Play Store
  app.

A debug build (`flutter build apk --debug`) also installs and is faster to
build, but unoptimized — prefer `--release` for anything you'll actually
use day to day.

**Updating an already-installed copy**: install the new APK the same way,
*without* uninstalling the old one first. As long as the Android package
id (`com.fintrack.mobile_app`) hasn't changed, Android treats it as an
in-place update and all your local data (transactions, categories, notes)
is preserved. Uninstalling first wipes that data — there is no cloud
restore built in (the optional Google Sheets sync is a manual backup, not
automatic restore).

## Project layout (quick orientation)

```
fin_track/
  mobile_app/        the actual app — everything lives here, see mobile_app/README.md
  app.py, email_service.py, templates/, fin_track.db, requirements.txt
                      legacy Flask desktop prototype — unmaintained, kept for reference only
```

## Tech stack

- **Framework**: Flutter (Dart) — chosen specifically because of
  [`enough_mail`](https://pub.dev/packages/enough_mail), a pure-Dart IMAP
  client that can talk TLS/IMAP directly from the device without a
  backend.
- **Local database**: [`sqflite`](https://pub.dev/packages/sqflite) (SQLite)
- **Secure storage**: [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
  (Android Keystore-backed) for the IMAP email/app-passcode
- **Google Sheets backup**: [`google_sign_in`](https://pub.dev/packages/google_sign_in) +
  Sheets API v4 over plain REST
- **Charts**: [`fl_chart`](https://pub.dev/packages/fl_chart)
- **Background sync**: [`workmanager`](https://pub.dev/packages/workmanager) (Android `WorkManager`)
- **Notifications**: [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)

## Limitations to remember

- **Android only** — no iOS build is set up.
- **Local database is the source of truth.** Uninstalling the app (not
  updating it) deletes all data permanently — backups are deliberately
  disabled at the OS level (see the comment in
  `mobile_app/android/app/src/main/AndroidManifest.xml`), so the only
  recovery path is the manual Google Sheets sync if you've been using it.
- Only **HDFC Bank** and **Union Bank** UPI alert formats are parsed
  today. Adding a bank means adding one `BankProfile` entry — see
  `mobile_app/lib/services/bank_profiles.dart`.
- Background sync is **polling** (~15–30 min behind), not real-time push —
  an Android WorkManager / Doze limitation, not a bug.
- There's a known data-integrity bug in how fetched emails are
  de-duplicated (keyed by IMAP sequence number instead of UID) — see the
  "Known issues" note in the legacy section of this repo's history, or
  search `email_id` in `mobile_app/lib/services/imap_service.dart`. Worth
  fixing before adding more features that depend on accurate
  de-duplication.

For the full feature tour, screen-by-screen behavior, analytics design,
background sync details, design system, and the up-to-date backlog, see
[`mobile_app/README.md`](mobile_app/README.md).
