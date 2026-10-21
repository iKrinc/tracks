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

### Palette (from CLAUDE.md, no harsh brights, no near-blacks as fills)

| Token | Hex | Use |
|---|---|---|
| sky | `#CBF0F8` | light: summary/secondary container |
| blue | `#AECBFA` | seed colour; light primary container |
| lilac | `#D7AEFB` | light tertiary container, accents |
| pink | `#FDCFE8` | category fills, gentle highlights |
| mint / peach / lemon | `#CCF2DD` `#FDE2C8` `#FFF4B8` | extra category fills only |

Pastels are **fills, never text**. On white they measure 1.2–1.9:1 contrast. On a pastel fill,
use dark ink (`#1F1F1F` measures 8.9–13.6:1). Never put white text on a pastel (1.65:1).

### Amount colours (measured WCAG contrast)

| Token | Light | Dark |
|---|---|---|
| income | `#276B4E` (6.4:1 white, 5.3:1 sky) | `#8FD8B4` (11.2:1 bg, 5.8:1 card) |
| expense | `#9E3F5E` (6.3:1 white, 5.2:1 sky) | `#F4A7C0` (9.9:1 bg, 5.1:1 card) |

Re-measure whenever a background or amount colour changes. Normal text needs **≥ 4.5:1**; text
≥ 24 sp, or ≥ 18.66 sp bold, needs ≥ 3:1. Don't eyeball it: run the snippet in
`checklist.md`.

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
