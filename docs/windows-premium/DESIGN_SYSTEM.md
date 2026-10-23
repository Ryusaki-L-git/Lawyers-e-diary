# DESIGN_SYSTEM.md
# Lawyer's E-Diary — Windows Design System (Implemented)

**Date:** 2026-10-21  
**Scope:** Windows desktop surfaces only. Android theme (`AppTheme.light`) is untouched.  
**Source of truth:** `lib/widgets/app_palette.dart` (tokens) + `lib/widgets/windows_desktop_ui.dart` (components).

---

## 1. Visual Identity — Modern Legal Editorial

| Role | Token | Value | Use |
|---|---|---|---|
| Page background | `AppPalette.canvas` | `#F7F5F2` | Every page background |
| Primary brand | `AppPalette.primaryGreen` | `#1F3D2B` | Primary actions, headings, selected states |
| Deep brand | `AppPalette.deepGreen` | `#13382E` | Raised brand panels |
| Accent | `AppPalette.accentGold` | `#CCA046` | Selection, focus rings, careful emphasis |
| Primary text | `AppPalette.textPrimary` | `#1A1A1A` | Body + heading text |
| Secondary text | `AppPalette.textMuted` | `#6B665E` | Captions, labels, muted text |
| Surface fill | `AppPalette.cardBackground` | `#FFFFFF` | Cards / panels (**used instead of `Colors.white`**) |
| Hairline border | `AppPalette.borderLight` | `#E5DFD7` | Dividers, panel borders |
| Urgent / destructive | `AppPalette.statusDanger` | `#9A4A3F` | Overdue, urgent, destructive actions |
| Resolved / positive | `AppPalette.statusSuccess` | `#536D5A` | Completed, settled |
| Advisory / pending | `AppPalette.statusWarning` | `#9B782B` | Pending amounts |
| Neutral tinted tile | `AppPalette.statusTile` | `#E9EEE9` | Icon backgrounds |
| Destructive panel fill | `AppPalette.errorFill` | `#FFF4E8` | Error message panels |
| Forest-panel muted text | `AppPalette.onForestMuted` | `#D8E1D9` | Muted text on green |
| Forest-panel faint text | `AppPalette.onForestFaint` | `#B9C7BD` | Faint text on green |
| Forest-panel nav label | `AppPalette.onForestText` | `#E3EAE5` | Nav labels on green |
| Forest-panel border | `AppPalette.onForestBorder` | `#345640` | Border on green |
| Danger tile | `AppPalette.statusDangerTile` | `#F8E8E5` | Destructive icon tile |

**Typography:** `AppTypography.heading` (serif — Georgia on Windows) for editorial headings; `AppTypography.body` (sans-serif) for controls, tables, metadata, body text.

**Composition rule:** the application looks expensive through composition, typography, spacing, precision, and restraint — not decoration. No gradients. Gold is reserved for selected states, meaningful emphasis, and carefully chosen accents.

---

## 2. Shared Components (`lib/widgets/windows_desktop_ui.dart`)

All Windows screens use these. None are hand-rolled.

| Component | Purpose |
|---|---|
| `WindowsPageHeader` | Eyebrow (uppercase, muted, 10px), serif title (primaryGreen, 28px, w700), optional subtitle, leading back button, trailing actions, optional trailing toolbar |
| `WindowsPanel` | White surface (`AppPalette.cardBackground`), radius **15**, `AppPalette.borderLight` hairline, optional title |
| `WindowsMessageState(isError:)` | The single empty/error/informational state; `isError: true` renders destructive red accent; always paired with a retry `action` where re-subscription is possible |
| `WindowsStatusChip` | Radius 12, padding 9/4, 10px w700, tinted fill at 8% alpha + 24% border |
| `WindowsFieldLabel` | Muted, 12px, w600 form labels |
| `WindowsFieldDecoration` | Radius 12, canvas fill, `borderLight` border, **gold focused border 1.5px**, danger error border |
| `WindowsSearchField` | Search glyph + clear button + shared decoration; `onDark` variant for forest panels |
| `WindowsFilterBar` | Segmented filter control (replaces loose `ChoiceChip` rows) |
| `WindowsStatTile` | Headline figure + caption + icon; optional `onTap` makes it a button; explicit `width` for Wrap rows |
| `WindowsSectionHeading` | Uppercase muted section label (10px, letterSpacing 1.5) |
| `WindowsLoadingPanel` | Gold spinner + optional label |
| `WindowsListRow` / `WindowsListHeader` / `WindowsColumnLabel` | Structured desktop list rows with hairline separators and hover treatment |
| `WindowsButtonStyles` | `primary()` (solid forest), `secondary()` (white + forest border), `ghost()`, `danger()`, `onForest(filled:)` |
| `WindowsDesktopScrollBehavior` | `MaterialScrollBehavior` enabling **click-and-drag scrolling with mouse** on Windows only |

**Layout scale:** `WindowsLayout.breakpointOf(width)` → `compact < 820`, `medium < 1180`, `expanded >= 1180`; `WindowsLayout.statColumnsOf(width)` → 1 / 2 / 4 stat columns.

---

## 3. Desktop Layout Rules

- Windows shell sidebar collapses from a 252px label rail to a 74px icon rail below 1080px total width; arrow keys navigate, Enter/Space activate, visible focus ring.
- `LayoutBuilder` is used to pick layouts; no fixed `SizedBox(width: 500+)`.
- Text inside a `Row` is wrapped in `Expanded`/`Flexible` to prevent narrow-window overflow.
- Column widths are computed from **content width** (window width minus page gutters), not full window width.
- Fixed minimum window size 900×620 logical pixels (Win32 `WM_GETMINMAXINFO`).
- Window title: `Lawyer's E-Diary`; default size 1360×860; non-client frame pinned to light appearance.
- Android continues to use its established mobile UI unchanged.

---

## 4. States

Every surface has explicit handling for: loading (`WindowsLoadingPanel`), empty (`WindowsMessageState`), error (`WindowsMessageState(isError: true)` + retry action), and success. Load failures are never rendered as empty states.
