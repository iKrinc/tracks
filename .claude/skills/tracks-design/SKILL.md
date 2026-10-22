---
name: tracks-design
description: >-
  Design system and UI rules for Tracks, the Flutter personal-finance app in this repo. Load it before
  building, restyling or reviewing ANY Flutter screen, widget, sheet, chart or theme code here (anything
  under lib/app/ or lib/features/*/presentation/). It holds the soft pastel palette and tokens, money
  display rules (paise, Indian grouping, income/expense colour + sign), capture-first patterns (quick-add
  bar, Confirm Card, chips, swipe + undo), accessibility floors with measured contrast, and the review
  checklist. It also says how to use the web skills design-taste-frontend and frontend-design in Flutter.
---

# Tracks design

Tracks is an **Operate** surface: someone standing at a chai stall logs ₹20 in under three seconds,
then glances at the month. Taste here means precision and calm, not spectacle. Every screen should
feel like *sharing*, not *form filling*.

## How the web skills apply here

`design-taste-frontend` and `frontend-design` are written for web pages. Use their **judgement**,
not their machinery:

- **Keep:** decide instead of defaulting; ground choices in the subject (Indian everyday money: UPI,
  chai, petrol, rent, EMIs); visual structure must encode information; no decorative labels, numbered
  markers or all-caps eyebrows; look at what you built and fix it.
- **Ignore:** hero sections, landing-page composition, the `draw.mjs` / `inspect.mjs` / CDN / Google
  Fonts / museum-image scripts, CSS and Tailwind specifics. Never add a network font or image
  fetch: the app makes no network calls (CLAUDE.md).
- **Translate:** CSS custom properties → `ThemeData` + `ThemeExtension`; media queries →
  `MediaQuery` / `LayoutBuilder`; hover → pressed/focus states; screenshots at three widths →
  the web preview at 360 and 412 wide (small and typical Android) in light **and** dark.

## Tokens

The tokens live in `lib/app/theme.dart` (`Palette`, `buildTheme`). Widgets read colours from
`Theme.of(context)`, never as hex literals. The only exceptions are category/account colours
stored in the database.

### Palette: "Marigold & chai" (owner's choice, no blue/purple)

| Token | Light | Dark | Use |
|---|---|---|---|
| surface | `#FBF6EC` cream | `#16120E` | page |
| surfaceContainerLow / Container | `#F5EEE1` / `#EFE6D5` | `#1E1914` / `#261F18` | cards, inputs |
| primary | `#2B2118` espresso | `#F7C35F` marigold | buttons, selected segment, FAB |
| primaryContainer | `#FBE3A8` | `#4A3A1C` | nav indicator, selected chips |
| tertiaryContainer | `#F8D2C2` coral | `#4A2A20` | warning banners |
| hero gradient | `#F7C35F` → `#F29E7A` | `#3A2A1E` → `#183A31` | hero cards |
| fills | sand, marigold, butter, coral, blush, clay, sage, jade (`Palette`) | same | categories, accounts (dark ink) |

Fills are **fills, never text**. Put dark ink on them.

### Amount colours (measured WCAG contrast)

| Token | Light | Dark |
|---|---|---|
| income | `#1E6B4F` (6.0:1 cream, 5.4:1 card) | `#8FD3B0` (10.8:1 bg, 9.4:1 card) |
| expense | `#A63A2B` (6.0:1 cream, 5.2:1 card) | `#F2A08A` (9.0:1 bg, 7.9:1 card) |

Re-measure whenever a background or amount colour changes. Normal text needs **≥ 4.5:1**; text
≥ 24 sp, or ≥ 18.66 sp bold, needs ≥ 3:1. Don't eyeball it: run the snippet in
`checklist.md`.

### Hero, charts, meters

- **Hero card** (`lib/app/widgets/hero.dart`): leads each tab. It uses a gradient from
  `TracksTokens.heroGradient`: marigold → coral in light, cocoa → forest in dark. Text uses
  `heroInk` (≥ 8:1) or `heroMuted` (≥ 4.8:1). Coloured amount text is weak on coral, so hero
  amounts use ink, and direction is shown by a coloured arrow icon (3:1 is enough for icons)
  plus the +/− sign. Figures use `AnimatedAmount`, a 350 ms count-up that respects reduce-motion.
- **Charts** (fl_chart, following the dataviz skill):
  - Two-series charts use `TracksTokens.seriesA`/`seriesB`: jade `#1B8A72` + saffron `#D4672A`
    in light, `#239A7F` + `#D9692C` in dark. Both pairs pass the dataviz validator. Don't use the
    app's green/red there; that pair fails CVD separation (ΔE 3.6).
  - A previous period is a dashed `outline` line.
  - Part-to-whole is shown as ranked horizontal bars in one hue, with direct labels. No pie
    or donut with more than 3 slices.
  - Every chart has a legend for 2+ series, a tooltip, and a Semantics summary. Every
    figure opens its transactions.
- **Meters** (`lib/app/widgets/meter.dart`): one hue for the track and fill. Status always has
  an icon plus words ("85% used", "Over by ₹500"), never colour alone.

### Type, space, shape

- Font: system Roboto. Don't bundle custom fonts until Phase 4's theme editor exists.
- Scale: Material 3 text theme only (`headlineMedium` for the Confirm Card amount, `titleLarge` for
  day numbers, `titleMedium` for totals, `bodyMedium` for rows, `labelMedium` for captions).
- Amounts use `FontFeature.tabularFigures()` wherever they stack or update, so digits don't jitter.
- Spacing on a 4 dp grid: 4, 8, 12, 16, 20, 24, 32. Screen gutters are 16 (lists 20).
- Radius: 28 on inputs, the quick-add bar and sheet tops; 12 on cards; chips use the M3 default.
- Elevation: flat (`elevation: 0`), with containers separated by tone, not shadow.

## Money display

- Always `formatPaise()` from `lib/core/money.dart`, which gives Indian grouping `₹1,23,456.78`.
  Never `toStringAsFixed`, never `double`, never `intl` currency formatting.
- Hide `.00` only in dense chips or summaries (`hideZeroPaise: true`). Lists and the Confirm Card
  show paise.
- Direction is shown by **colour and position/sign**, never colour alone (colour-blind users). In a
  list the section and icon carry it; anywhere amounts mix without context, prefix `+` for income
  and `−` for expense.
- Transfers are neutral (`onSurfaceVariant`) and never count in income/expense totals.
- Honest numbers: every total must be tappable through to the transactions behind it (when that
  screen exists, wire it up, and don't leave a dead total).
- Screen-reader label for amounts: "520 rupees expense", not "₹520.00". Wrap with `Semantics`.

## Patterns

- **Capture first.** The quick-add bar stays visible at the bottom of Home. Parse → Confirm Card
  (bottom sheet, `showDragHandle`, `useSafeArea`) → one tap Save. Everything is pre-filled from
  the parser; forms are the fallback (`+` button).
- **Confirm Card order:** type segmented control → big centred amount → account chips →
  category chips (guess pulled to the front) → note → date chip → Save (full width, 52 dp).
  No more than one free-text field visible before Save.
- **Chips over dropdowns** for accounts and categories: horizontal scroll, the selected one first.
  A selected chip on a pastel fill uses dark ink.
- **Destructive = swipe + Undo SnackBar**, not a confirm dialog. Dialogs are for creation only
  (e.g. new account).
- **Empty states teach the grammar:** show a real example ("Type "chai 20" below"), not a stock
  illustration.
- **Sheets over pages** for anything under ~6 fields. New full pages only for lists or settings.
- Motion: M3 defaults only (sheet slide, chip select). No decorative animation.

## Accessibility floor

- Touch targets ≥ 48×48 dp (IconButton defaults are fine; check custom tappables).
- Works at text scale 1.3× and 2.0× without clipping. Long amounts use `FittedBox` or wrap, and
  never overflow.
- Every icon-only button has a `tooltip`. Every amount has a semantic label (above).
- Focus order follows visual order; the Confirm Card amount field gets autofocus only when empty.
- Dark mode is first-class: check both themes on every change.

## Verify

1. `flutter analyze` and `flutter test` pass.
2. Web preview (`.claude/launch.json` → `tracks-web`, release mode) at 360×800 and 412×915, in light
   and dark. Screenshot the changed screen in each.
3. Walk `checklist.md`. Then ask the **design-reviewer** subagent to review the diff.
