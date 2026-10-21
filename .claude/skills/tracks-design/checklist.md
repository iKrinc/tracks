# Tracks UI checklist

Each item is pass/fail. The design-reviewer subagent reports against these IDs.

## Money
- **M1** Every displayed amount goes through `formatPaise` (Indian grouping, ₹). No `double`, no
  `toStringAsFixed`, no `intl` currency.
- **M2** Income/expense use `theme.incomeColor` / `theme.expenseColor`. Transfers are neutral and
  excluded from totals.
- **M3** Direction is never shown by colour alone (sign, section or icon also carries it).
- **M4** Stacked or updating amounts use tabular figures.
- **M5** Totals are tappable through to their transactions (or a TODO is filed if the target
  screen doesn't exist yet).

## Capture flow
- **C1** The quick-add bar stays reachable on Home, also with the keyboard open.
- **C2** Parsed fields arrive pre-filled in the Confirm Card. The user can save in one tap.
- **C3** Accounts and categories are chips with the selected one first. No dropdowns.
- **C4** Deletes are swipe + Undo. No confirm dialog for reversible actions.
- **C5** Empty states show a real quick-add example.

## Visual
- **V1** No hex colour literals in widgets (theme tokens or DB-stored category/account colours only).
- **V2** Pastels are fills only. Text and icons on pastel fills use dark ink.
- **V3** Spacing on the 4 dp grid; gutters 16/20; radii 28 (inputs, sheets) / 12 (cards).
- **V4** Flat surfaces: tone separates containers, not shadows.
- **V5** No decorative labels, all-caps eyebrows, numbered markers or ornamental dividers.
- **V6** Looks right in light **and** dark.

## Accessibility
- **A1** Text contrast ≥ 4.5:1 (≥ 3:1 for ≥ 24 sp or ≥ 18.66 sp bold), measured, not guessed.
- **A2** Touch targets ≥ 48×48 dp.
- **A3** No clipping or overflow at text scale 1.3× and 2.0×, or at 360 dp width.
- **A4** Icon-only buttons have tooltips. Amounts have semantic labels ("520 rupees expense").
- **A5** Focus/tab order matches visual order.

## Engineering
- **E1** `flutter analyze` clean and `flutter test` green.
- **E2** No new dependency without the owner's OK. No network calls. No analytics.
- **E3** Widgets read state via Riverpod providers. No DB calls inside `build`.

## Contrast snippet

```bash
node -e "const L=h=>{const c=[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)/255).map(v=>v<=0.03928?v/12.92:((v+0.055)/1.055)**2.4);return .2126*c[0]+.7152*c[1]+.0722*c[2]};const [a,b]=process.argv.slice(1);const x=L(a),y=L(b);console.log(((Math.max(x,y)+.05)/(Math.min(x,y)+.05)).toFixed(2))" "#276B4E" "#CBF0F8"
```
