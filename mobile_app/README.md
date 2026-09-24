# SpendTrack — Mobile App

*Track. Understand. Take Control.*

A standalone Flutter app that connects **directly to Gmail over IMAP from
your phone** to track your HDFC UPI transactions — no backend, no server
in between. (Internally the Android package id is still
`com.fintrack.mobile_app` — kept as-is so the Google Sign-In OAuth client
already registered for it keeps working; only the user-facing name changed.)

Everything for this app lives inside this `mobile_app/` folder. It does not
import anything from the rest of the repo.

## How it works

- **Bottom navigation**: Home · Dashboard · Sync · Profile.
  - **Home** and **Dashboard** are placeholders ("Coming soon") for later
    phases — see Backlog below.
  - **Sync**: tap **"Fetch last 10 UPI transactions"** to connect live
    over IMAP and pull your most recent UPI-related emails. New ones are
    saved into a **local SQLite database on the device** — that database,
    not Gmail, is what the list and any future dashboards are built from,
    so your categorized history survives across fetches, app restarts, etc.
    Tap a transaction to open it.
  - **Profile**: enter your Gmail address and a Gmail **App Password**
    (16-character passcode, not your normal Gmail password). Stored only
    on the device, in the Android Keystore (via `flutter_secure_storage`)
    — never written to a plain file, never sent anywhere except directly
    to `imap.gmail.com`. Also hosts the optional Google Sheets backup.
- **Transaction detail screen**: shows the amount, date, subject, and full
  parsed email body, plus an **"Add label" / "Change label"** button to
  assign a category (create new categories inline — e.g. Food, Petrol,
  Rent).
- **Google Sheets backup (optional, manual)**: in Profile, tap **"Connect
  Google account"** once (standard Google sign-in consent screen, no
  password ever touches this app). After that, tap **"Sync to Google
  Sheet"** any time to push whatever's new since the last sync — it only
  **appends** rows, never overwrites, and only runs when you tap it. The
  local database is always the source of truth; the Sheet is just a copy.

Amount/date/snippet parsing (`lib/services/parser_service.dart`) is a
line-for-line Dart port of the desktop app's `email_service.py` regex
patterns, so HDFC alerts parse identically.

## Design system

The whole app follows one design spec — light theme only, clean/minimal
"modern fintech" look. It's centralized in `lib/theme/` so new screens
stay consistent automatically:

- `lib/theme/app_colors.dart` — the full color palette (primary `#2563EB`,
  background `#F7F9FC`, card white, text/status colors). Change a value
  here and it updates everywhere.
- `lib/theme/app_text_styles.dart` — the type scale (screen title, section
  title, large amount, body, supporting text), all on Google Fonts' Inter.
- `lib/theme/app_theme.dart` — the `ThemeData` built from the above:
  button styles, input fields, chips, nav bar, snackbars, etc. Screens
  should pull styling from `Theme.of(context)` / these files rather than
  hardcoding colors or one-off styles.
- `lib/widgets/app_card.dart` — the one card component (rounded, white,
  soft shadow) used everywhere a card-like section is needed.
- `lib/widgets/coming_soon.dart` — shared empty-state placeholder.

When building new screens: reuse `AppCard`, pull colors from `AppColors`,
text styles from `AppTextStyles`, and rely on the themed
buttons/chips/inputs rather than styling widgets ad hoc.

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

### Google Cloud setup for the Sheets backup (only needed if you want that feature)

The Google Sign-In button won't work until you register the app in a free
Google Cloud project. This is a one-time, ~10 minute setup:

1. Go to the [Google Cloud Console](https://console.cloud.google.com/),
   create a project (or reuse one).
2. **APIs & Services → Library** → enable the **Google Sheets API**.
3. **APIs & Services → OAuth consent screen** → configure it (External is
   fine for personal use; add your own Google account as a test user if
   prompted).
4. **APIs & Services → Credentials → Create Credentials → OAuth client ID**
   → Application type **Android**. You'll need:
   - **Package name**: `com.fintrack.mobile_app`
   - **SHA-1 certificate fingerprint** of the signing key. For local debug
     builds (what `flutter run` uses), get it with:

     ```bash
     cd mobile_app/android
     ./gradlew signingReport
     ```

     Look for the `debug` variant's `SHA1:` line. On this machine that
     was `7B:28:35:D5:3E:AD:7E:19:00:8D:93:79:5C:2D:F1:6B:27:F7:B0:F0` —
     yours will differ once you generate/use your own debug keystore, so
     always re-check with the command above rather than trusting an old
     value.
   - No client secret needed for the Android client type.
5. Save. No app code changes needed — `google_sign_in` picks up the
   registration automatically based on package name + SHA-1 + the
   `Google Sheets API` being enabled on the project.

If you later build a **release** APK signed with your own keystore
(instead of the debug one), you'll need to add that keystore's SHA-1 as a
second OAuth client (same steps, different fingerprint) or Google Sign-In
will fail on release builds only.

No billing account is required — Sheets API is free for this scale of
personal use.

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
   go to **Sync**, tap **Fetch**.

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
for anything you're actually going to use day-to-day. Remember: a release
build is signed with a different keystore than `flutter run` uses, so
Google Sign-In needs its own OAuth client registered (see the Google
Cloud setup section above) before it'll work in a release build.

## Notes / limitations

- **Android only** for now — no iOS build has been set up (would need
  Xcode + CocoaPods + an Apple developer profile for a physical iPhone).
- **Local database, not Gmail, is the source of truth.** Fetch pulls new
  mail and inserts it into SQLite; categorization and history all live
  there. Uninstalling the app deletes this data — there's no cloud
  restore yet, which is exactly what the optional Google Sheets sync is
  for (a manual, append-only backup copy).
- IMAP connects straight from the phone to `imap.gmail.com:993` over TLS.
  No third-party server sees your email or app password.
- Google Sheets sync is a **separate credential** from the IMAP app
  passcode — Google doesn't accept app passwords for API access, so it
  needs its own one-time "Connect Google account" consent, done through
  standard Google Sign-In (no password ever seen or stored by this app).

## Backlog / known issues

Not built/fixed yet — rough priority order, but open to reordering:

- [ ] **Fix transaction time parsing** — some rows show an incorrect or
  clearly-wrong date/time (e.g. a future date pulled from unrelated text
  in the email body, like a card due-date). The regex-based date parser
  (ported from the desktop app) needs tightening, probably by trusting
  the IMAP message header date more and the in-body regex less.
- [ ] **Credit vs debit marking** — transactions aren't currently tagged
  as money in vs money out; list/detail should show a clear
  credited/debited indicator (icon/color) instead of just a raw amount.
- [ ] **Hide mail body by default** — the transaction detail screen
  currently always shows the full parsed email body. Should be
  collapsed/hidden by default with a "View mail body" action, and when
  shown, rendered as HTML (the original formatting) rather than the
  current stripped-to-plain-text version.
- [ ] **Bank-wise categorization** — categorize/filter transactions by
  bank, not just by user-defined category (currently only HDFC is
  parsed at all; this implies multi-bank parsing support too).
- [ ] **Dedicated category management section** — category creation
  currently only happens inline from the label picker sheet; add a
  proper screen to view/rename/delete categories.
- [ ] **Build out Home tab** — currently a placeholder.
- [ ] **Build out Dashboard tab** — category breakdown, spend-over-time
  charts (`fl_chart`), week/month/year filters, all reading from the
  local SQLite database.
- [ ] **Push notifications on new transactions** — periodic background
  sync (Android `WorkManager`, minimum ~15 minute interval due to OS
  battery limits) that checks for new UPI mail and fires a local
  notification prompting you to categorize it — no backend needed,
  reuses the same IMAP credentials.

## Project structure

```
mobile_app/
  lib/
    main.dart                          # app entry point
    theme/
      app_colors.dart                  # color palette
      app_text_styles.dart             # type scale
      app_theme.dart                   # ThemeData built from the above
    models/
      transaction.dart                 # UpiTransaction: parsed + categorized transaction
      category.dart                    # Category: id + name
    services/
      imap_service.dart                # connects to Gmail IMAP, fetches mail
      parser_service.dart              # amount/date/snippet regex parsing
      credentials_service.dart         # secure read/write of email + passcode
      database_service.dart            # local SQLite: transactions + categories
      google_sheets_service.dart       # Google Sign-In + append-only Sheets backup
    widgets/
      app_card.dart                    # shared card component
      coming_soon.dart                 # shared empty-state placeholder
      category_picker_sheet.dart       # bottom sheet to label a transaction
    screens/
      splash_screen.dart               # brand intro
      root_screen.dart                 # bottom-nav shell (Home/Dashboard/Sync/Profile)
      home_tab.dart                    # placeholder
      dashboard_tab.dart               # placeholder
      sync_screen.dart                 # fetch button + local transaction list
      profile_screen.dart              # email/passcode entry + Google Sheets backup
      transaction_detail_screen.dart   # full email body view + labeling
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
- **Local database**: [`sqflite`](https://pub.dev/packages/sqflite)
- **Secure storage**: [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
  (Android Keystore-backed) — for the IMAP email/app-passcode only
- **Google Sheets backup**: [`google_sign_in`](https://pub.dev/packages/google_sign_in)
  for OAuth, plain REST calls (via `http`) to the Sheets API v4
- **Typography**: [`google_fonts`](https://pub.dev/packages/google_fonts) (Inter)
