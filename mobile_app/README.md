# Fin Track — Mobile App

A standalone Flutter app that connects **directly to Gmail over IMAP from
your phone** to fetch and display your last 10 HDFC UPI transaction emails —
same parsing logic as the desktop `fin_track` app, but no backend, no
database, and no server in between.

Everything for this app lives inside this `mobile_app/` folder. It does not
import anything from the rest of the repo.

## How it works

- **Profile screen**: enter your Gmail address and a Gmail **App Password**
  (16-character passcode, not your normal Gmail password). Stored only on
  the device, in the Android Keystore (via `flutter_secure_storage`) —
  never written to a plain file, never sent anywhere except directly to
  `imap.gmail.com`.
- **Home screen**: tap **"Fetch last 10 UPI transactions"** to connect live
  over IMAP and pull your most recent UPI-related emails. Results are kept
  in memory only — nothing is saved locally, so re-opening the app or
  fetching again always gets you the current state of your inbox. (No
  SQLite, no local database — keeps the app small.)
- **Tap a transaction card** to see the full parsed email body.

Amount/date/snippet parsing (`lib/services/parser_service.dart`) is a
line-for-line Dart port of the desktop app's `email_service.py` regex
patterns, so HDFC alerts parse identically.

## Requirements

You need:
- **Flutter SDK** (this project targets Flutter 3.41+/Dart 3.11+)
- **Android Studio** with the **Android SDK**, **platform-tools**, and
  **emulator** components
- A Java runtime for Gradle — Android Studio ships its own (JBR), which
  Flutter uses automatically; you don't need to install Java separately

Check your machine is ready at any time with:

```bash
flutter doctor
```

You want green checks under "Flutter" and "Android toolchain". The
"Xcode" section can be ignored — this app targets Android only.

## One-time setup

```bash
cd mobile_app
flutter pub get
```

### Get a Gmail App Password (the "app passcode")

1. Gmail → **Settings → See all settings → Forwarding and POP/IMAP** →
   enable **IMAP access**.
2. If you have 2-Step Verification on (required for app passwords): go to
   [Google Account → Security → App passwords](https://myaccount.google.com/apppasswords),
   create one for "Mail", and use that 16-character code in the Profile
   screen — not your regular Gmail password.

## Run on the Android Emulator (test on your laptop)

1. Open **Android Studio → More Actions → Virtual Device Manager** and
   make sure at least one emulator exists (create one if the list is
   empty — any recent Pixel + latest API level works fine). You can also
   list/create them from the CLI:

   ```bash
   flutter emulators
   flutter emulators --launch <emulator_id>
   ```

2. With the emulator booted, run:

   ```bash
   flutter run
   ```

   Flutter auto-detects the running emulator as the target device. Hot
   reload works as usual (`r` in the terminal, or save in your editor).

3. In the app: go to **Profile**, enter your email + app password, **Save**,
   go back to **Home**, tap **Fetch**.

## Run on your physical Android phone

1. On the phone: **Settings → About phone** → tap **Build number** 7 times
   to enable Developer Options. Then **Settings → Developer options** →
   enable **USB debugging**.
2. Connect the phone to your Mac via USB and accept the "Allow USB
   debugging?" prompt on the phone.
3. Confirm it's detected:

   ```bash
   flutter devices
   ```

   Your phone should show up in the list.
4. Run:

   ```bash
   flutter run
   ```

   This installs and launches a debug build directly on the phone (same
   experience as the emulator, but on real hardware — useful for testing
   actual network conditions).

## Build a release APK to install manually

If you'd rather build once and just copy the APK over (no cable needed
afterwards, no `flutter run` session):

```bash
flutter build apk --release
```

The APK is written to:

```
build/app/outputs/flutter-apk/app-release.apk
```

Options to get it onto your phone:
- **USB**: `adb install build/app/outputs/flutter-apk/app-release.apk`
  (with the phone connected and USB debugging on)
- **Any file transfer**: AirDrop-equivalent, email it to yourself, Google
  Drive, USB cable as a plain file copy, etc. — then open the `.apk` file
  on the phone. Android will prompt to allow "install from this source"
  the first time; allow it, since this is your own unsigned build, not a
  Play Store app.

A debug build (`flutter build apk --debug`, output at
`build/app/outputs/flutter-apk/app-debug.apk`) also works for manual
install and is faster to build, but is unoptimized — prefer `--release`
for anything you're actually going to use day-to-day.

## Notes / limitations

- **Android only** for now — no iOS build has been set up (would need
  Xcode + CocoaPods + an Apple developer profile for a physical iPhone;
  the emulator/simulator side is a separate concern from your goal of
  having this on your Android phone).
- **No persistence** — by design (per the "no database" requirement),
  every fetch talks live to Gmail; there's no offline transaction history
  yet. That's the reason for the planned Google Sheets phase below.
- IMAP connects straight from the phone to `imap.gmail.com:993` over TLS.
  No third-party server sees your email or app password.

## Future phase: Google Sheets as the transaction history

The plan is to use a personal Google Sheet as the "database" instead of
storing transactions on-device or standing up a backend — keeps the app
tiny and gives you a normal spreadsheet you can view/edit/chart outside
the app.

Key constraint: the Gmail **App Password** used for IMAP is **not**
accepted by the Google Sheets API — Sheets writes require OAuth2. Two free
options, in order of preference:

1. **Google Apps Script Web App** (recommended): deploy a small free Apps
   Script bound to your own Sheet, exposed as a Web App URL guarded by a
   shared secret you set once. The app POSTs each parsed transaction to
   that URL; the script appends a row. No OAuth screen inside the app, no
   billing, no API keys to manage — closest to the current "just enter a
   credential and go" flow.
2. **Google Sheets API with Google Sign-In**: fully OAuth-based, free
   (well under quota for personal use), but adds a one-time Google
   consent screen in the app instead of a plain passcode field.

Not implemented yet — this section is a roadmap note for the next phase
of work, not something the current app does.

## Project structure

```
mobile_app/
  lib/
    main.dart                          # app entry point
    models/
      transaction.dart                 # parsed transaction data
    services/
      imap_service.dart                # connects to Gmail IMAP, fetches mail
      parser_service.dart              # amount/date/snippet regex parsing
      credentials_service.dart         # secure read/write of email + passcode
    screens/
      home_screen.dart                 # fetch button + transaction list
      profile_screen.dart              # email + app passcode entry
      transaction_detail_screen.dart   # full email body view
  android/                             # generated Android project
  test/
    widget_test.dart
```

## Tech

- **Framework**: Flutter (Dart) — chosen over React Native specifically
  because it has a pure-Dart IMAP client (`enough_mail`) that can talk
  TLS/IMAP directly from the device; React Native has no built-in raw
  socket support, which would otherwise force a backend or native module
  just to read mail.
- **IMAP**: [`enough_mail`](https://pub.dev/packages/enough_mail)
- **Secure storage**: [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
  (Android Keystore-backed)
