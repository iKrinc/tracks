# How Tracks works

A technical walkthrough of every flow, the problems each one solves, where the
app is still weak, and what comes next. Written 2026-10-23, at schema v5.

---

## 1. The problem we're solving

Expense apps fail for one reason: **logging is a chore**, so people stop by
week three. In India it's worse, because money moves through many channels at
once: UPI apps, two or three bank accounts, credit cards, cash, autopay
mandates, EMIs, and money lent to friends. Each channel leaves a different
trace (an SMS, an in-app receipt, nothing at all).

The usual fixes have problems of their own:

| Approach | Why it falls short |
|---|---|
| Read all SMS automatically | Google Play restricts `READ_SMS`; also a privacy red flag |
| Link bank accounts (account aggregators) | Cloud and consent servers, data leaves the phone |
| Manual forms | 6–8 taps per entry, so people quit |

**Tracks' answer:** make capture *sharing*, not *form filling*, and keep
everything on the phone. Every way money shows up on a phone (a typed line, an
SMS, a payment screenshot, a CSV, a backup) is turned into the same pre-filled
**Confirm Card**, and saving it takes one tap.

---

## 2. Architecture in one picture

```
            ┌────────────── capture sources ──────────────┐
 quick-add ─┤ "chai 20 gpay"        → quick_add_parser      │
 SMS share ─┤ bank/UPI SMS text     → sms_parser            │──► CaptureDraft ──► Confirm Card ──► SQLite (drift)
 image     ─┤ GPay/PhonePe receipt  → ML Kit OCR → screenshot_parser│        ▲                       │
 bill      ─┤ recurring "Mark paid" → draft with ids        │        │                       ▼
            └──────────────────────────────────────────────┘   account match,          Riverpod streams
                                                                category guess,          │
                                                                duplicate check          ▼
                                                                              Home · Reports · Accounts
                                                                              Budgets · Bills · Reminders
```

- **Flutter + Dart 3, Material 3**. Riverpod (code-generated) for state,
  go_router for navigation, drift on SQLite for storage.
- **Pure-Dart domain layer.** Every parser and every piece of money maths is a
  plain function with no Flutter imports, tested on its own (179 tests today).
- **Feature-first folders**: `lib/features/<feature>/{domain,data,presentation}`.
- **Money is always integer paise.** `parseRupeesToPaise("1,23,456.78")` parses
  the string directly into `12345678` and never goes through `double`. The only
  `double`s are display-only (chart axes, the count-up animation) and the EMI
  rate factor (`pow`), which is rounded straight back to paise.

---

## 3. Each flow, technically

### 3.1 Quick-add ("chai 20 gpay")
`features/capture/domain/quick_add_parser.dart`
1. Splits the line into tokens. Keyword passes pull out:
   - **kind:** `lent`, `borrowed`, `transfer`, `atm`, `income`/`salary`/`refund`
   - **links:** `to X` / `from X`, an account if X is a known keyword, otherwise a person
   - **dates:** `yesterday`, weekday names, `12/10`, `12/10/26`
   - **account words:** `gpay`, `hdfc`, plus every name and match hint on the user's own accounts
2. The amount is the **last** token that reads as money (`₹249.50`, `1.5k`,
   `1,24,999`). Leftover words become the description.
3. `captureFromQuickAdd` maps the result to a `CaptureDraft`.

The problem it solves: one line replaces a form. "lent 2000 to ravi" also
carries a person, which offers the IOU flow (3.9).

### 3.2 Sharing a bank/UPI SMS
`sms_parser.dart`, `share_intake.dart`, `AndroidManifest.xml` (`SEND text/plain`)
1. Android delivers the shared text through `receive_sharing_intent`, either at
   cold start (`getInitialMedia`) or while the app is running (`getMediaStream`).
2. `parseBankSms` does the following:
   - Rejects OTPs and drops promos and balance alerts that have no transaction verb.
   - Takes the **direction** from whichever verb comes first: *debited/spent/sent/withdrawn* or *credited/received/refund*.
   - Takes the **amount** as the first currency amount that isn't preceded by "Avl Bal", "Limit" or "up to". That rule is why the available balance is never mistaken for the spend.
   - Reads the **account** (last 4 digits, preferring "from your A/c" on debits), the **bank**, the **merchant** (UPI ID first, then patterns like "trf to X", "at X" or "; X credited"), the **date** in five formats, and the **reference number**.
   - Sets the **channel** (UPI, card, ATM, NEFT, NACH) and **flags** (refund, autopay, EMI, card payment).
3. `_fromSms` handles the special cases:
   - An ATM withdrawal becomes a **transfer to Cash**.
   - A card bill payment becomes a **transfer into the card**.
   - A refund becomes **income**.

Why share instead of reading SMS automatically: Play policy forbids `READ_SMS`
for this kind of app, and sharing keeps you in control of what Tracks sees.

### 3.3 Sharing a payment screenshot (OCR)
`ocr.dart`, `screenshot_parser.dart`, `MainActivity.kt`, intent filters
`SEND image/*` and `SEND_MULTIPLE image/*`
1. Android hands Tracks a content URI. Our own `tracks/share` channel in
   `MainActivity.kt` copies it into the app cache on a background thread,
   inside try/catch, capped at 25 MB. A revoked or unreadable URI becomes the
   message "Couldn't open what was shared" instead of a crash. ML Kit's
   **on-device** Latin model then reads it (`readTextBlocksFromImage`) and
   returns one string per **block** (a receipt section, an SMS bubble). The
   image never leaves the phone.
2. `parsePaymentScreenshot` is built for receipt layouts rather than SMS
   sentences:
   - **Kind:** "Received from" makes it a credit; "Paid to", "Debited from" or "Transaction successful" make it a debit.
   - **Amount:** the first line that is just an amount (`₹349`, `Rs 349`, and OCR noise like `%349`).
   - **Payee:** "Paid to X" on the same line or the next one, or the "To:" line.
   - **Account:** the masked digits on the bank line. If OCR garbles the mask (`*** * 1234`, or drops it), it falls back to the trailing 4 digits of that bank line. Lines with a UPI ID are skipped, because `zomato@hdfcbank` names the payee's bank, not yours.
   - **Reference:** UTR, "UPI transaction ID" or "Ref No".
   - **Date:** "23 Oct 2026".
   - **GPay 2025+ layout:** "To NAME" / "From NAME" at the top with "Completed" below. If OCR drops the big ₹, it takes the bare number under the header (never a year, time or reference). Masked UPI IDs (`••••29-2@ybl`) are ignored.
3. If it isn't a receipt, `captureFromScreenshotBlocks` treats it as a
   **screenshot of an SMS thread**: every bubble is parsed as an SMS, so one
   screenshot can give several transactions. OCR sometimes splits one bubble
   into 2–4 blocks, or breaks a date across lines ("22-10-" / "26"). Blocks
   that mean nothing alone are joined with the next ones while that fills in
   more fields (amount, date, ref). Repeats are dropped by ref no.
4. Several transactions open the **batch review** sheet: one row each, ticked
   by default. Ones already in Tracks are flagged and unticked; rows with no
   amount must go through the Confirm Card. "Save N" saves the ticked ones.
   Sharing several screenshots at once merges them into one review.

Tested on 13 anonymised fixtures built from real GPay, Canara and Kotak
samples, plus real OCR runs on the emulator (a synthetic 3-message Canara
thread → 3 drafts with dates, times and refs; re-sharing it flags all three
as already saved).

### 3.4 The Confirm Card (where every capture lands)
`confirm_sheet.dart`
1. **Account matching** (`account_match.dart`) tries, in order: last 4 digits
   against each account's match hints, then the keyword, then the bank. If the
   capture names an account you don't have yet, it offers **"Add HDFC ••1234"**,
   which saves `hdfc,1234` as match hints so the next SMS matches by itself.
2. **Category guess** (`category_guess.dart`): a table of Indian spend words
   (chai → Snacks & Chai, swiggy → Food delivery, jio → Mobile recharge), then
   whole-word matches against category names.
3. **Duplicate check:** the same reference number, or else the same amount on
   the same day, shows a "Possible duplicate" banner and changes the button to
   "Save anyway". Sharing the SMS *and* the screenshot of one payment is caught
   by the reference number.
4. **Learned rules** (`rules.dart`): if you change the category or account
   the card suggested, an **Always for "swiggy"** chip appears (on by
   default). Saving stores a Rule keyed on the merchant (a UPI ID's name part,
   so `zomato@hdfcbank` → "zomato") or else the note. Next time, a rule
   matching exactly or as whole words (longest wins) fills the category and
   account *before* the word list. The capture's own account hint (XX3388)
   still beats a rule. More → Rules lists them with a use count; swipe to
   forget, with Undo.
5. **EMI interest split:** a transfer into a loan account that has a rate
   shows "₹4,515.12 lowers the loan / ₹1,050.00 interest at 10.5%". Saving
   writes the interest as an expense (EMI & Loans) and only the principal as
   the transfer, in one database transaction. The toggle turns it off for
   prepayments.
6. **Saving** writes the transaction with `source` (manual, sms, screenshot,
   quickText, recurring) and the raw text kept for audit. The SMS's own time
   of day is used when it has one.

### 3.5 Views: Daily, Monthly, Yearly, Calendar
`home_screen.dart`, `summary.dart`, `calendar_view.dart`
- **Daily:** one month as a drift stream, grouped by day, with day totals.
- **Monthly** and **Yearly:** `totalsByMonth` and `totalsByYear` over a single
  stream of all transactions. The bar on each row is scaled to the heaviest
  period, so a bad month stands out.
- **Calendar:** `calendarCells` builds the month grid (Monday first, padded to
  whole weeks). Each day shows compact amounts in Indian units (`+50k`,
  `−1.2L`).
- **Honest numbers:** every total, balance and chart figure opens a search
  pre-filtered to exactly the transactions behind it.

### 3.6 Reports (insights)
`reports.dart`, `reports_screen.dart`
- **Comparison hero:** this period against the last one ("₹2,300 (15%) less
  than September"), with a trend arrow coloured by whether the change is good.
- **Running total:** cumulative spend by day for this month, with last month
  as a dashed line. You can see whether you're ahead of or behind your usual
  pace before the month ends.
- **Month by month:** income and spending bars for the year. Tap a month to
  open it.
- **By category:** subcategories roll up to their parent, shown as ranked
  horizontal bars with direct labels, amounts and percentages (stored as basis
  points, so they stay integers).
- **Chart colours** were checked with a colour-blindness validator. The app's
  green/red pair fails for red-green colour blindness (ΔE 3.6), so charts use
  jade and saffron, which pass (ΔE ≥ 8.8).

### 3.7 Budgets
`budget_math.dart`, `budgets_screen.dart`
- `spentInMonth` counts expenses only, and includes subcategories in their
  parent's budget.
- `budgetProgress` marks a warning from 80% and over from 100%. **Rollover**
  carries last month's unspent amount forward, but never carries debt.
- `dailyAllowance` divides what's left by the days left: "about ₹223 a day".
- Budgets that are close or over show a banner on Home.

### 3.8 Bills, autopay and reminders
`schedule.dart`, `reminder_plan.dart`, `reminder_service.dart`
- **Schedules** keep the start day and clamp to the month's end:
  31 Jan → 28 Feb → **31 Mar**, never drifting to the 28th. Leap years and
  29 Feb are handled.
- `nextDue` treats a payment as settling whichever occurrence it's closest to,
  so paying rent on the 3rd for the 5th still counts.
- **Mark paid** opens a pre-filled Confirm Card. Saving it logs the
  transaction and moves `lastPaid` forward. **Skip** advances without logging.
- **Reminders:**
  - `planReminders` schedules at 9 am, 0, 1 or 3 days before the due date. It skips times already past (Home shows those) and caps at 50, because Android limits pending alarms.
  - `ReminderService` schedules **inexact** alarms, so no special alarm permission is needed. They survive a reboot through a boot receiver.
  - Autopay bills are worded "check it went through".
  - Card bills get their own reminder 3 days before the due date.

### 3.9 Credit cards, loans and IOUs: one model
`credit_card.dart`, `loan.dart`, `account_detail_sheet.dart`

The key design decision: **debts are accounts, and repayments are
transfers.** Lending ₹2,000 to Ravi moves money from Cash into a "Ravi (owes
me)" account. Your spending doesn't change, your net worth doesn't change, and
the IOU shows exactly what's outstanding. No separate ledger, and the same
balance maths covers everything.

- **Card cycle:** from the statement day and due day,
  - **billed** is what was owed at the last statement,
  - **due now** is billed minus payments made since,
  - **unbilled** is spending after the statement,
  - **utilisation** is outstanding ÷ limit. Above 30% gets a credit-score warning.
  - **Minimum due** is an *estimate* (5%, at least ₹200).
- **Loans:** the standard reducing-balance EMI. ₹5 lakh at 9.5% for 60 months
  works out to ₹10,500.93 a month. Months left is the amortisation inverse.
  Each repayment is split (`splitEmi`): interest = what's still owed × rate
  ÷ 12, in integer paise; only the rest lowers the loan. So the outstanding
  amount and "months left" follow the bank's schedule, and interest shows up
  in spending where it belongs.
- **IOUs from quick-add:** "lent 2000 to ravi" offers "Track as IOU with
  ravi", which finds or creates Ravi's account and saves a transfer.

### 3.10 Accounts, balances, net worth
`balances.dart`: balance = opening + income − expense, plus transfers in,
minus transfers out. One SQL `GROUP BY` produces the totals and a pure function
folds them into balances. Archived accounts still count, because archiving
hides an account; it doesn't erase money.

### 3.11 Data safety
- **Deleting asks first** (owner's decision): a transaction swipe, forgetting
  a rule, deleting a bill and closing a fund all show a warning naming what
  goes, then offer Undo.
- **Google Drive:** Backup & restore → *Save backup to Google Drive* opens
  Android's own Save-to screen (Drive appears there when the Drive app is
  installed). Android uploads; Tracks makes no network call. Android's
  automatic Google backup also covers Tracks (owner's decision, 2026-10-22).

- **Migrations** v1 → v5 are each tested against frozen schema snapshots
  (`drift_schemas/`), including checks that data survives every step.
- **JSON backup** holds every table. Restore is atomic, so a bad file changes
  nothing. Older backups without the newer tables still restore.
- **CSV import** guesses columns from headers (its own export, Money Manager,
  bank statements), and you can correct the mapping. Bad rows are skipped,
  with a reason.
- **New phone:** Android system backup is on (your decision), so the database
  comes back with your Google account. The welcome screen also offers
  "Restore from my old phone", and opening a backup file from Drive or Gmail
  into Tracks works too.
- **App lock:** fingerprint, face or PIN at launch, and again after 30 s in the
  background. That's long enough that the fingerprint prompt itself doesn't
  re-lock the app.

### 3.12 Cash-flow forecast ("what's left before payday")
`insights/domain/forecast.dart`, `forecast_sheet.dart`, `cashForecastProvider`
1. **Start:** today's balance of cash, bank and wallet accounts. Cards,
   loans, IOUs and every fund's money are left out.
2. **Window:** up to the day before the next salary/income bill (within 45
   days), else 30 days.
3. **Walk day by day:** each bill, EMI and income on its due dates
   (`occurrence`/`nextDue`), each card's unpaid statement on its due day
   (unless a bill already pays that card), minus typical everyday spending.
4. **Everyday spending** is the average daily expense from spendable
   accounts over the last 60 days, leaving out bills and fund spends (a
   ₹50,000 wedding caterer isn't a usual day). With less history it averages
   over the days there are.
5. **Cautious by design:** overdue bills are counted today; overdue income
   isn't (it may already have come in).
6. **Answer:** what's left on the last day, the lowest point and its date,
   and a daily allowance: what's free after bills alone, divided by the days
   left. Home shows one line ("₹12,340 left before payday · spend up to
   ₹1,760 a day") or, when money runs short, the day and whether bills or
   spending cause it. The sheet lists every step with the running balance.

### 3.13 Funds: a separate track for one purpose (a wedding, a trip)
`funds/`, schema v6 + v7. Owner's model: **the fund itself is the category**;
a fund is just money in and money out. Funds has its own bottom-bar tab.
- **Create:** name, optional budget, starting money that is either **new
  money** (typed in, never in your accounts here) or **taken from an
  account** (a real "Wedding – initial" transfer, so that account's balance
  stays true). A fund gets an account named after it, so "catering 50000
  wedding" on Home goes straight to it. Its entries have no category.
- **Not synced (default, what most people use):** tracked only on its own
  screen. Nothing shows in Home, Reports, budgets or net worth. Accounts
  shows "+ ₹70,000 kept in funds" beside net worth.
- **Sync (on and off at will):** you pick a main account, say HDFC.
  Example: Wedding starts with ₹5,00,000; catering ₹50,000 on 28 Sep;
  others ₹4,00,000 on 28 Oct; gifts ₹20,000 on 29 Oct. Synced, the main
  timeline shows *Wedding – catering* (28 Sep), *Wedding – others* (28 Oct),
  *Wedding – gifts* (29 Oct) on their own dates, then **Wedding – remaining
  ₹70,000, Wedding → HDFC**, timed right after the last entry. It is a real
  transfer, so HDFC's balance and net worth are right.
  - `remaining` is kept by the app (`AppDatabase._refreshSync`): every add
    or delete touching the fund updates its amount and date. An overspent
    fund's shortfall is covered *from* HDFC. It can't be swiped away: turn
    sync off.
  - **Unsync** deletes only `remaining`; every real entry stays.
  - Reports show a synced fund as one category slice (tap opens the fund).
- **The payday forecast never uses funds.**
- **Close:** move what's left to a cash, bank or wallet account (synced
  funds are unsynced first); the fund and its account are archived with
  their history. It asks first; Undo or Reopen bring it back.
- Tested end to end on the owner's example (`test/data/fund_sync_test.dart`).

### 3.14 Crash safety
- Every capture function runs inside `_safely`: if a parser throws on a
  format nobody foresaw, you get a blank Confirm Card with the raw text kept,
  never a crash.
- Share intake catches each step (file read, OCR, parse) and turns failures
  into a SnackBar ("Nothing was saved").
- `PlatformDispatcher.onError` logs anything uncaught instead of dying; in
  release builds a widget that fails to build shows a quiet note, not a grey
  box.
- **Fuzz tests** throw 2,100+ random and mutated real-format inputs at each
  parser. They found a real bug: 13+ digit numbers overflowed `int.parse`.
  Amounts are now capped at 12 rupee digits.

### 3.15 Design system
- **The "Marigold & chai" palette:**
  - warm cream paper and espresso ink, with a marigold → coral hero gradient
  - dark mode uses cocoa → forest
  - every text pair is measured at ≥ 4.5:1, and figures on the hero use ink (≥ 8:1)
- Direction is never shown by colour alone: amounts carry +/−, and heroes use
  arrows.
- Tokens live in `TracksTokens` (theme extension). The rules live in
  `.claude/skills/tracks-design`, and a design-reviewer subagent audits each UI
  change.

---

## 4. Where Tracks is weak today

Honest list, roughly ordered by how much it matters:

1. **Capture still needs a share.** Nothing happens automatically. That's
   deliberate (Play policy, privacy), but it's still friction.
2. **Parsers are heuristics.** They now cover real GPay, Canara and Kotak
   formats, but other banks (SBI, HDFC, ICICI, Axis, regional banks) and
   current PhonePe/Paytm layouts are only covered by synthetic fixtures.
3. **OCR is Latin-script only.** Hindi or regional-language receipts and
   dark-mode screenshots will parse less well.
4. **Rules are simple.** They match words, not patterns (a different UPI ID
   per shop branch makes a new rule each time), and they set category and
   account but not notes or tags.
5. **The EMI split assumes reducing balance and monthly interest.** Flat-rate
   loans, floating-rate changes and a first broken-period EMI will be slightly
   off; the toggle lets you book a payment entirely as principal.
6. **Card minimum due is an estimate.** Statements aren't imported.
7. **Reminders can arrive late** on phones with aggressive battery savers
   (Xiaomi, Oppo, Vivo), because they're inexact alarms. There's no
   "mark paid" action that works without opening the app.
8. **Scale:** reports load every transaction into memory. That's fine for tens
   of thousands; beyond that, the work should move to SQL.
9. **Privacy gaps:** the JSON backup isn't encrypted, and Tracks isn't hidden
   from the recent-apps screenshot (`FLAG_SECURE`).
10. **Polish:**
    - the app icon is still Flutter's default
    - large text sizes (2×) aren't fully verified on every screen
    - iOS is untested
    - INR only
11. **History:** some intermediate commits don't build on their own. Build
    from the latest commit.

---

## 5. What we can do about it: next, in order

| # | Work | Fixes |
|---|---|---|
| 1 | **Fund polish**: share a fund summary (PDF/image) with family | — |
| 2 | **More real-world fixtures**: SBI, HDFC, ICICI, Axis SMS and PhonePe/Paytm screenshots, anonymised into tests | 2, 3 |
| 3 | **Smarter rules**: UPI ID prefix patterns; notes and tags | 4 |
| 4 | **Loan schedule view**: the full amortisation table, floating-rate changes | 5 |
| 5 | **Notification-listener mode (opt-in)**: read payment notifications from GPay, PhonePe and bank apps, with clear disclosure. Removes the share step and is allowed by Play with a proper declaration | 1 |
| 6 | **Encrypted backup + FLAG_SECURE**: optional passphrase on the JSON backup; hide Tracks in recent apps when App lock is on | 9 |
| 7 | **SQL aggregations** for reports and balances | 8 |
| 8 | **Phase 3**: savings goals, Money Manager Excel import, XLSX export | — |
| 9 | **Phase 4**: home-screen quick-add widget, theme editor, a custom app icon, optional bundled fonts (needs your OK to add font files) | 10 |
| 10 | **Release prep**: real signing key, Play listing, privacy policy (easy, since nothing is collected) | — |
