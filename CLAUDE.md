# Tracks — Personal Finance Tracker

Flutter app for tracking personal money in India. No ads, no accounts, no cloud by default.
Inspired by "Money Manager" (Realbyte) but smarter: adding a transaction should feel like
**sharing**, not **form filling**.

Owner: KRINC (Srinivas). This is a personal-first app that may be released later.

---

## Product principles

1. **Capture in under 3 seconds.** Share an SMS, share a screenshot, or type one line
   ("chai 20 gpay"). The app parses it and shows a confirm card. Forms are the fallback.
2. **Local-first & private.** All data stays on device (SQLite). No ads, no analytics SDKs,
   no network calls except optional, user-triggered backup. *Owner's decision (2026-10-22):*
   Android's own system backup stays ON (`allowBackup`, `res/xml/*backup*_rules.xml`), so a
   new phone on the same Google account restores Tracks automatically. The app itself still
   makes no network calls. Don't turn this off without asking.
3. **Never lose data.** Export/import in open formats. Auto-backup file. Migrations tested.
4. **Highly customizable.** Themes, home dashboard widgets, categories, quick-add buttons,
   number formats, start-of-month day — all user-configurable.
5. **Honest numbers.** Every figure on a chart can be tapped to see the transactions behind it.

---

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter (stable), Dart 3, Material 3 |
| State | Riverpod (riverpod_generator) |
| Database | drift (SQLite), with schema migrations + migration tests |
| Navigation | go_router |
| OCR | google_mlkit_text_recognition (on-device, free) |
| Receive shares | own `tracks/share` MethodChannel in `MainActivity.kt` (text, images, files; copies streams in try/catch so a bad URI can't crash the app). Replaced receive_sharing_intent, which crashed natively on unreadable URIs |
| Charts | fl_chart |
| Notifications / reminders | flutter_local_notifications + timezone |
| Import/export | csv, excel, file_picker, share_plus, path_provider |
| Biometric lock | local_auth |
| Optional smart parsing (later) | on-device LLM via flutter_gemma, behind a feature flag |

Target Android first (that's where SMS/UPI flows live). Keep iOS buildable but untested is fine.

---

## Core domain model

- **Account** — cash, bank, wallet (GPay/PhonePe/Paytm balance), credit card, loan. Has
  type, opening balance, currency (INR default), color, icon, archived flag.
- **Category / Subcategory** — income or expense, icon, color, order. User-editable.
- **Transaction** — id, type (expense / income / transfer), amount (store as integer paise),
  account, toAccount (for transfers), category, note, merchant, date-time, tags,
  attachments (image path), source (`manual | sms | screenshot | quick_text | recurring | import`),
  rawSourceText (keep the original SMS/OCR text for audit), linkedRecurringId, linkedDebtId.
- **Recurring / Autopay** — name, amount (fixed or variable), account, category, schedule
  (monthly on day N, weekly, yearly, custom), next due date, autopay flag (UPI mandate,
  card standing instruction, NACH), reminder offset, status (active / paused / ended).
- **Credit card** — limit, statement day, due day; tracks billed vs unbilled spend,
  minimum due, payments made.
- **Debt / Loan / EMI** — direction (I owe / owed to me), person or lender, principal,
  interest rate (optional), EMI amount, tenure, schedule; repayments are transactions
  linked to it; shows outstanding + progress.
- **Budget** — per category or overall, per period, with rollover option.
- **Rule** — merchant/keyword → category/account mapping, learned from user corrections.

Money is ALWAYS integer paise. Never use double for amounts.

---

## Smart capture pipeline

```
input (shared SMS text | shared image | quick-add text | pasted text)
  → normalise (OCR for images via ML Kit)
  → detect type (debit/credit/UPI/card/refund/autopay/EMI/OTP-ignore)
  → extract fields (amount, account hint e.g. "XX1234", merchant/VPA, date, ref no.)
  → apply Rules (merchant → category)
  → dedupe (same amount + ref no. or amount + time window → warn)
  → Confirm Card (all fields pre-filled, editable, one tap to save)
  → on correction: offer "always do this for <merchant>" → creates a Rule
```

- Parsers are **pure Dart functions** with heavy unit tests. Keep a fixtures folder of
  real-world (anonymised) Indian bank SMS formats and GPay / PhonePe / Paytm screenshot OCR text.
- **Do NOT request READ_SMS / RECEIVE_SMS.** Google Play restricts these permissions; use
  the share-intent flow instead. A notification-listener mode can be explored later as an
  opt-in feature with clear disclosure.
- Quick-add grammar examples: `chai 20`, `petrol 500 card`, `salary 50000 income`,
  `lent 2000 to ravi`, `rent 12000 hdfc yesterday`.

---

## Feature roadmap

### Phase 1 — MVP (usable daily)
- Accounts, categories (sensible Indian defaults), transactions, transfers
- Quick-add text bar on home screen
- Share-to-app for SMS text and screenshots → Confirm Card
- Daily / monthly / calendar views (like Money Manager), search & filters
- Export: CSV + JSON (full backup). Import: own JSON backup + CSV with column mapping
- App lock (biometric / PIN)

### Phase 2 — Money obligations
- Recurring & autopay tracker with reminders and "mark paid" from notification
- Credit cards: statement cycle, due reminders, utilisation
- Debts/loans/EMIs: lent/borrowed, repayments, outstanding, payoff progress
- Budgets with alerts

### Phase 3 — Insight & compare
- Compare: month vs month, period vs period, category trends, account trends
- Cash-flow forecast from recurring items
- Savings goals (e.g. emergency fund) with progress
- Import from Money Manager's Excel export (column mapping wizard)
- XLSX export

### Phase 4 — Customise & polish
- Theme editor (colors, font size, density, light/dark). *Owner's decision (2026-10-23):* no
  typical blue/purple. The default is the warm "marigold & chai" palette: cream paper
  `#FBF6EC`, espresso ink `#221C15`, marigold→coral hero `#F7C35F`→`#F29E7A`, warm pastel
  fills (sand, sage, clay, blush, jade). Exact tokens are in `lib/app/theme.dart`.
- Rearrangeable home dashboard widgets
- Android home-screen widget for quick add
- Optional encrypted backup to a user-chosen location (Drive/own server) — user-triggered only
- Optional on-device LLM for messy inputs

### Release plan (owner's decisions, 2026-10-24)
- **No Play Store release for now.** Builds are distributed as a signed APK on GitHub
  Releases, with a small download page on Vercel whose button downloads the latest APK.
- **Next release:**
  1. Opt-in capture from payment notifications (GPay, PhonePe, bank apps), with clear
     disclosure; still never READ_SMS / RECEIVE_SMS.
  2. More real bank formats (SBI, HDFC, ICICI, Axis, PhonePe/Paytm), anonymised.
  3. Savings goals (target, date, progress, monthly amount), reusing the Funds design.
  5. Privacy: optional backup passphrase; hide Tracks in recent apps (`FLAG_SECURE`)
     when App lock is on.
- **Maybe, some day:** Money Manager Excel import and XLSX export. The owner doesn't use
  Money Manager, so don't build this unless asked.
- **Done in this round:** theme editor, app icon, home-screen quick-add widget, faster
  reports (SQL aggregates and indexes).

### Status (2026-10-24), see `docs/how-tracks-works.md`
- **Phase 1 done:** quick-add, SMS and screenshot (on-device OCR) share, accounts,
  categories editor, Daily/Monthly/Yearly + calendar, search, backup/restore/CSV, app lock.
- **Phase 2 done:** bills/autopay with notification reminders, budgets, credit cards
  (cycle, due, utilisation), loans and IOUs as accounts moved by transfers.
- **Capture hardened:** real GPay/Canara/Kotak formats, SMS-thread screenshots → batch
  review, own crash-proof share channel, parser fuzz tests, rules learned from corrections.
- **Phase 3 started:** Reports tab, EMI principal/interest split, cash-flow forecast to
  payday, **Funds** (owner's request 2026-10-24: separate money for an event such as a
  wedding: the fund is its own category; unsynced by default; sync picks an account and
  adds "<Fund> – remaining"; deletes always confirm; Funds is a bottom tab; rows read
  "Fund – title"; schema v7). Next:
  notification-listener capture (opt-in), more bank fixtures, savings goals.

---

## Project structure

```
lib/
  app/            # router, theme, app shell
  core/           # money (paise) utils, date utils, result types
  data/           # drift db, tables, DAOs, migrations
  features/
    capture/      # share intake, OCR, parsers, confirm card, rules
    transactions/
    accounts/
    recurring/
    debts/
    budgets/
    insights/     # compare & charts
    backup/       # import/export
    settings/
test/
  parsers/fixtures/   # sample SMS + OCR text
```

Feature-first folders; each feature has `data/`, `domain/`, `presentation/`.

---

## Commands

- Codegen (drift + riverpod): `dart run build_runner build`. Generated files
  (`*.g.dart`, `*.drift.dart`) are committed so analyze works without running it.
- drift uses the `not_shared` builder (`build.yaml`) so its row classes exist before
  riverpod_generator runs. Don't switch back to the shared `.g.dart` part.
- Schema change: bump `schemaVersion`, add an `onUpgrade` step, then
  `dart run drift_dev schema dump lib/data/app_database.dart drift_schemas/` and
  `dart run drift_dev schema generate drift_schemas/ test/data/generated/`, then extend
  `test/data/migration_test.dart`. Never edit an old `drift_schema_vN.json`.
- Android emulator: AVD `Medium_Phone` (`flutter emulators --launch Medium_Phone_API_37.0`).
  On Windows, `flutter run` in the background can't hot reload. Restart it instead.
- Web preview (UI checks only, Android is the real target):
  `flutter run --release -d web-server --web-port 8080`. `web/sqlite3.wasm` and
  `web/drift_worker.js` are copied from the drift package. Refresh them when
  upgrading drift.

## Working conventions for Claude

- This repo is often edited from a **cloud session** without an emulator. Always run
  `flutter analyze` and `flutter test` before finishing a task. The owner runs the app on a
  real Android phone locally.
- Write tests first for parsers, money math, recurring-date math and migrations.
- Small, reviewable commits with clear messages. One feature per branch.
- Never add an ads SDK, analytics SDK, or any network call without the owner asking.
- Never store real personal SMS or screenshots in the repo — only anonymised fixtures.
- Prefer boring, well-maintained packages; ask before adding a new dependency.
- Keep UI friendly and fast: confirm cards, bottom sheets, swipe actions — avoid long forms.
- Before any UI work, load the `tracks-design` skill (`.claude/skills/tracks-design/`). After it,
  run the `design-reviewer` subagent on the diff and fix its findings before committing.
  `design-taste-frontend` and `frontend-design` are web skills: use them only as tracks-design
  describes.
- The Dart MCP server (`.mcp.json`) handles analyze, tests and pub. On Windows a local-scope
  override runs it via `cmd /c dart.bat`.
