# SpendTrack — Mobile App

*Track. Understand. Take Control.*

A standalone Flutter app that connects **directly to Gmail over IMAP from
your phone** to track your HDFC and Union Bank UPI transactions — no
backend, no server in between. (Internally the Android package id is still
`com.fintrack.mobile_app` — kept as-is so the Google Sign-In OAuth client
already registered for it keeps working; only the user-facing name changed.)

Everything for this app lives inside this `mobile_app/` folder. It does not
import anything from the rest of the repo.

## How it works

- **Bottom navigation**: Home · Transactions · Analytics · Settings.
  - **Home**: greeting (your name, set once in Settings → Profile), month
    selector, a Total Spent card with month-over-month change and a mini
    trend sparkline, Income/Remaining (currently a `₹—` placeholder — see
    Backlog), an unlabelled-transactions nudge that jumps straight to
    Transactions with that filter applied, and top categories with
    progress bars — tapping one jumps to Analytics → Categories, filtered
    to just that category.
  - **Analytics**: month selector + Overview / Categories / Banks / Trends
    sub-tabs, and a Filters sheet — see "Analytics" below. Tapping a row
    on Categories drills into that category's transaction list (same
    card design as Transactions).
  - **Transactions**: tap **"Fetch last 10 UPI transactions"** to connect
    live over IMAP and pull your most recent alert emails from known bank
    senders. New ones are saved into a **local SQLite database on the
    device** — that database, not Gmail, is what the list and any future
    dashboards are built from, so your categorized history survives across
    fetches, app restarts, etc. Filter chips (All / Unlabelled / per-bank)
    and date-grouped ("Today", "Yesterday", ...) cards, paginated 10 at a
    time with a **Load more** button (the local history only grows over
    time — this avoids rendering the entire thing at once). Tap a
    transaction to open it.
  - **Settings**: your name (for the Home greeting), Gmail connection
    (email + app passcode), category management, and the Google Sheets
    backup.
- **Transaction detail screen**: amount, merchant, date, a details card
  (bank, UPI ID, reference number, transaction type, status — only the
  fields that were actually present in that email are shown), a link to
  view the original email text, the assigned category (tap to change),
  notes, and a clearly-separated destructive "Delete Transaction" action.
- **Label transaction screen**: a fast, dedicated screen (not a dropdown)
  — a 3-column grid of your categories, tap to select, tap **New** to
  create one on the spot, optional notes, then **Save**.
- **Google Sheets backup (optional, manual)**: in Settings, tap **"Connect
  Google account"** once (standard Google sign-in consent screen, no
  password ever touches this app). After that, tap **"Sync to Google
  Sheet"** any time to push whatever's new since the last sync — it only
  **appends** rows, never overwrites, and only runs when you tap it. The
  local database is always the source of truth; the Sheet is just a copy.

### Supported banks & email parsing

Each bank has its own sender address and email format — see
`lib/services/bank_profiles.dart`, the single place to add a new bank:

| Bank | Sender | Format |
|---|---|---|
| HDFC Bank | `alerts@hdfcbank.bank.in` | Prose sentence: `Rs.X is debited from your account ending NNNN towards VPA <vpa> (<merchant>) on DD-MM-YY.` + a reference number line. No time of day in the body. |
| Union Bank | `noreplyubi-txn@ubi.bank.in` | Structured numbered fields: `Payee Name`, `Amount`, `Channel`, `Transaction ID/RRN`, `Transaction Status`, `Transaction Date and Time`, `Debit Account Number`. |

Fetching now matches the email's **sender address** against these known
bank senders (rather than a generic "contains the word UPI" keyword
heuristic) and dispatches to that bank's own parser — more precise, and
each bank can have a completely different body format. An email from an
address that isn't a recognised bank sender is skipped.

Since HDFC's body has no time of day, the app falls back to the mail's own
timestamp (from the IMAP header) for the time — otherwise every HDFC
transaction would incorrectly show as "12:00 AM".

### Bank badges & category colors

- Banks are shown as small colored monogram badges (e.g. "HDFC" on a navy
  chip) rather than the banks' actual logos — no trademarked logo assets
  are embedded in the app.
- Categories are entirely user-created (no fixed/curated set), so each one
  gets a deterministic color + initial-letter avatar (`lib/theme/category_colors.dart`,
  `lib/widgets/category_avatar.dart`) instead of a hand-picked icon — no
  setup required when creating a category, and it looks consistent
  everywhere (transaction cards, the label grid, the categories list).

Amount/date/merchant/reference/status extraction (`lib/services/bank_profiles.dart`)
replaces the earlier generic regex port from the desktop app's
`email_service.py` — the two supported banks' formats are different enough
that per-bank parsing is both more accurate and easier to extend.

## Analytics

`lib/screens/analytics_tab.dart` is the shell: an AppBar with a Filters
icon, a month selector (‹ September 2026 ›), and a 4-tab `TabBar` —
Overview / Categories / Banks / Trends (`lib/screens/analytics/`).

**Date scoping**: the month selector is the default range. Opening the
Filters sheet and picking a Date Range preset (Today / This Week / This
Month / Last 3 Months / Custom Range) *overrides* the month selector —
shown as a removable chip — until cleared (via the chip's ✕, the sheet's
Reset, or moving the month selector again, which always reasserts
month-selector mode). Bank / Category / Transaction Type selections from
the sheet apply on top of whichever date range is active, also shown as
chips. This logic lives in `lib/models/analytics_filter.dart`
(`AnalyticsFilter.resolveDateRange`).

**Data**: `lib/services/analytics_service.dart` holds every aggregate
query (total spend, category/bank breakdowns, daily/monthly series) as
one parameterised `WHERE` builder over the local `transactions` table —
add a new aggregate by adding one method there, not by writing ad hoc SQL
in a screen. Charts are `fl_chart` (line/pie/bar), kept deliberately
minimal (no gridlines, no axis clutter) per the design spec.

**Filters sheet** (`lib/screens/analytics/filters_sheet.dart`) is
Analytics-only — the Transactions tab keeps its own separate, simpler
All/Unlabelled/per-bank filter chips.

## Background sync & notifications

A Flutter app cannot run continuously in the background or react to
Gmail in real time — there is no persistent process to instantly detect
new mail. What's actually implemented is a **periodic poll**:

```
Android WorkManager (every ~15 min, requires network)
        │
        ▼
IMAP fetch (same path as Transactions' manual Fetch)
        │
        ▼
Diff against what's already stored → genuinely new transactions
        │
        ▼
Save locally
        │
        ▼
Local notification per new transaction (capped at 5 per sync)
```

- **`lib/services/background_sync_service.dart`** — registers a
  `WorkManager` periodic task (`registerPeriodicTask`, 15-minute
  frequency — the OS-enforced minimum for periodic work, regardless of
  what's requested; a phone in Doze can push this further out) and
  defines `callbackDispatcher`, the top-level entry point Android
  relaunches in a background isolate to run the sync. Registered after
  Gmail credentials are saved in Settings, and re-asserted (a no-op if
  already scheduled) on every app start.
- **`lib/services/notification_service.dart`** — creates the Android
  notification channel, requests the Android 13+ POST_NOTIFICATIONS
  runtime permission (also on Settings save), shows the "New
  transaction" notification with a **"Label Now"** action button, and
  routes a tap straight to the right screen:
  - Tapping the notification body → `TransactionDetailScreen`.
  - Tapping **Label Now** → `LabelTransactionScreen` directly — never
    the Transactions list first.
  - Handles both a *warm* tap (app already running — routes
    immediately) and a *cold* tap (app process was killed — the launch
    request is detected via `getNotificationAppLaunchDetails()` and
    replayed once `RootScreen` mounts and its `Navigator` exists).
- Verified live: the permission dialog appears on Settings save, and
  Android's own `dumpsys jobscheduler` confirms the periodic work is
  registered against this app with the expected ~15 minute minimum
  latency and network constraint. The actual 15-minutes-later
  fetch-and-notify firing wasn't observed live in this pass (nothing to
  trigger it against without real new mail arriving) — the sync logic
  itself is a direct reuse of the already-verified `ImapService`/
  `DatabaseService` fetch path.

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
- `lib/theme/category_colors.dart` — deterministic per-category color palette.
- `lib/widgets/app_card.dart` — the one card component (rounded, white,
  soft shadow) used everywhere a card-like section is needed.
- `lib/widgets/category_avatar.dart` — the colored initial-letter avatar
  (plus the "needs a label" warning avatar variant).
- `lib/widgets/bank_badge.dart` — the colored bank monogram chip.
- `lib/widgets/coming_soon.dart` — shared empty-state placeholder.
- `lib/widgets/transaction_card.dart` — the one transaction list-row
  design, used by Transactions and the Analytics category drilldown.
- `lib/widgets/month_selector.dart` — the "‹ September 2026 ›" control,
  used by both Home and Analytics.

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
   create one for "Mail", and use that 16-character code in the Settings
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

3. In the app: go to **Settings**, enter your email + app password, **Save**,
   go to **Transactions**, tap **Fetch**.

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
  mail and inserts it into SQLite; categorization, notes, and history all
  live there. Uninstalling the app deletes this data — there's no cloud
  restore yet, which is exactly what the optional Google Sheets sync is
  for (a manual, append-only backup copy).
- IMAP connects straight from the phone to `imap.gmail.com:993` over TLS.
  No third-party server sees your email or app password.
- Google Sheets sync is a **separate credential** from the IMAP app
  passcode — Google doesn't accept app passwords for API access, so it
  needs its own one-time "Connect Google account" consent, done through
  standard Google Sign-In (no password ever seen or stored by this app).
- Only HDFC Bank and Union Bank are recognised right now (see the table
  above). A third bank means adding one more `BankProfile` — no other
  code changes needed.
- Background notifications are **polling, not push** — up to ~15–30
  minutes behind, by Android design (WorkManager's own minimum periodic
  interval, plus Doze/battery-optimization delays on some OEMs). See
  "Background sync & notifications" above.

## Backlog / known issues

Not built/fixed yet — rough priority order, but open to reordering:

- [x] ~~Fix transaction time parsing~~ — done for the "always shows
  midnight" case (HDFC bodies have no time; the app now falls back to the
  mail's own timestamp). Broader accuracy depends on the two banks' actual
  formats, which are now parsed precisely rather than via generic regex.
- [x] ~~Bank-wise categorization~~ — done: Transactions has All /
  Unlabelled / per-bank filter chips, and both HDFC and Union Bank are
  now parsed.
- [x] ~~Dedicated category management section~~ — done: Settings →
  Categories (add/delete; deleting un-labels rather than deletes affected
  transactions).
- [ ] **Credit vs debit marking (Income tracking)** — HDFC's credit-
  notification template is now parsed correctly (amount/sender/VPA/
  reference), but there's still no `direction` (credit/debit) field
  stored per transaction, so nothing distinguishes money in from money
  out yet. Home's **Income** and **Remaining** cards are an explicit
  placeholder (`₹—`) for exactly this reason — showing a fabricated
  number would be worse than an honest dash. Needs: a `direction` column
  + migration, each `BankProfile` setting it per template, and Home/
  Analytics updated to use it (Income = sum of credits, Remaining =
  Income − Spent).
- [ ] **Render the original email as HTML** — "View Original Email"
  currently shows the plain-text body (HTML already stripped when the
  mail was fetched). True original-formatting rendering needs capturing
  the raw HTML at fetch time plus an HTML-rendering widget/package —
  bigger change, deferred.
- [x] ~~Build out Home tab~~ — done: greeting (name set once in
  Settings → Profile), month selector, Total Spent card with a mini
  trend sparkline, Income/Remaining (stubbed, see above), an unlabelled-
  transactions nudge that jumps to Transactions with that filter
  pre-applied, top categories, and recent activity.
- [x] ~~Build out Analytics tab~~ — done: Overview / Categories / Banks /
  Trends sub-tabs with a month selector and a Filters sheet (Date Range /
  Bank / Category / Transaction Type), all reading from the local SQLite
  database via `lib/services/analytics_service.dart`.
- [x] ~~Push notifications on new transactions~~ — done: periodic
  `WorkManager` background sync (see "Background sync & notifications"
  below).
- [ ] **Export local data as CSV**.
- [ ] **Google Sheets sync center** — a few related ideas for the
  Settings → Google Sheets backup section:
  - Let the user export to a **new** sheet on demand, instead of always
    reusing the one stored spreadsheet id.
  - Show sync history / last-sync-time (persisted locally, or as a column
    in the sheet itself).
  - Manage categories via a dedicated tab in the Google Sheet, not just
    in-app.
  - Restructure the sheet into proper relational tabs (transactions /
    categories / banks) instead of one flat sheet.
- [ ] **Light/dark theme option** — the design spec calls for light-only,
  but a user-facing toggle (rather than just following system theme,
  which isn't wired up either) could be worth adding.
- [x] ~~Build home page~~ — done, see the Home section above.

## Project structure

```
mobile_app/
  lib/
    main.dart                          # app entry point
    theme/
      app_colors.dart                  # color palette
      app_text_styles.dart             # type scale
      app_theme.dart                   # ThemeData built from the above
      category_colors.dart             # deterministic per-category color palette
    models/
      transaction.dart                 # UpiTransaction: parsed + categorized transaction
      category.dart                    # Category: id + name
      analytics_filter.dart            # AnalyticsFilter + DateRange/DateRangePreset
      analytics_models.dart            # CategorySpend/BankSpend/DailySpend/MonthlySpend
      analytics_category_request.dart  # Home -> Analytics "jump to this category" request
    utils/
      transaction_grouping.dart        # shared "Today"/"Yesterday"/date grouping
    services/
      bank_profiles.dart               # per-bank sender address + email parser
      imap_service.dart                # connects to Gmail IMAP, fetches + parses mail
      credentials_service.dart         # secure read/write of email + passcode
      database_service.dart            # local SQLite: transactions + categories
      google_sheets_service.dart       # Google Sign-In + append-only Sheets backup
      analytics_service.dart           # aggregate queries for the Analytics tab
      background_sync_service.dart     # WorkManager periodic sync + callbackDispatcher
      notification_service.dart        # notification channel, permission, tap routing
    widgets/
      app_card.dart                    # shared card component
      category_avatar.dart             # colored initial-letter avatar
      bank_badge.dart                  # colored bank monogram chip
      coming_soon.dart                 # shared empty-state placeholder
      transaction_card.dart            # shared transaction list-row
      month_selector.dart              # shared "‹ September 2026 ›" control
    screens/
      splash_screen.dart               # brand intro
      root_screen.dart                 # bottom-nav shell (Home/Transactions/Analytics/Settings)
      home_tab.dart                    # greeting, month selector, summary, categories
      analytics_tab.dart               # Analytics shell: month selector + sub-tabs + filters
      analytics/
        overview_tab.dart              # summary card, trend chart, KPIs, category donut
        categories_analytics_tab.dart  # category spend list, sorted, with progress bars
        category_transactions_screen.dart # drilldown: one category's transactions
        banks_tab.dart                 # bank donut + monthly comparison + bank-wise trend
        trends_tab.dart                # daily/weekly/monthly line chart + stats
        filters_sheet.dart             # Date Range / Bank / Category / Transaction Type
      transactions_screen.dart         # fetch button + filters + grouped transaction list
      transaction_detail_screen.dart   # transaction detail, notes, delete
      label_transaction_screen.dart    # category grid labeling screen
      categories_screen.dart           # add/delete categories
      original_email_screen.dart       # raw parsed email body
      settings_screen.dart             # Gmail connection + categories link + Sheets backup
  android/                             # generated Android project
  test/
    widget_test.dart
    bank_profiles_test.dart
    imap_service_test.dart
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
- **Charts**: [`fl_chart`](https://pub.dev/packages/fl_chart)
- **Background sync**: [`workmanager`](https://pub.dev/packages/workmanager)
  (Android `WorkManager` under the hood)
- **Notifications**: [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) —
  requires core library desugaring, enabled in `android/app/build.gradle.kts`
  (`isCoreLibraryDesugaringEnabled` + the `desugar_jdk_libs` dependency)
