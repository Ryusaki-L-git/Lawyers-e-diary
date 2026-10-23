# INITIAL_AUDIT.md
# Lawyer's E-Diary — Windows Premium Mission: Initial Audit

**Date:** 2026-10-21  
**Mission:** Transform the Windows application into a premium, production-quality legal desktop experience.  
**Repository:** `C:\Users\Lawyers-e-diary-main`  
**Framework:** Flutter 3.47.7 (existing), Dart  
**Target:** Windows desktop (Android must remain untouched)

---

## 1. Repository & Environment Status

- **Git:** repo present, working tree essentially untracked (an "Initial commit" exists with almost nothing committed). No prior commits to diff against; changes are reviewed against a local baseline snapshot taken before editing.
- **Flutter:** Not on PATH. SDK located at `C:\src\flutter\flutter`. Version **3.47.7**. Dart CLI works once `bin` is on PATH.
- **Windows toolchain:** Visual Studio Community 2026 18.9.2 + Windows 11 SDK 10.0.26100.0 available. `flutter build windows --debug` and `--release` both succeed.
- **Android toolchain:** SDK 36 present (untouched by this mission).

---

## 2. Pre-existing Blocker (Fixed During Audit)

`pubspec.yaml` contained a **duplicate `flutter:` mapping key** (lines 40 and 43), which broke the entire Flutter toolchain — `flutter --version`, `flutter pub get`, `flutter analyze`, and all builds failed before any editing began.

**Fix:** merged the two `flutter:` blocks into a single block (`uses-material-design: true` + `assets:`). This is the only change to a configuration file and it unblocks everything. No dependency versions were changed.

---

## 3. Existing Architecture

The application already had a substantial, well-organized **Windows-specific implementation** under `lib/windows/` (29 screens) plus a shared desktop design system under `lib/widgets/windows_desktop_ui.dart` and `lib/widgets/app_palette.dart`.

**Shared design system (baseline):**
- `app_palette.dart`: canonical LED tokens (canvas `#F7F5F2`, forest `#1F3D2B`, gold `#CCA046`, serif `AppTypography.heading`, sans body).
- `windows_desktop_ui.dart`: `WindowsPage`, `WindowsPageHeader`, `WindowsPanel`, `WindowsMessageState`, `WindowsFieldLabel`, `WindowsStatusChip`, `WindowsFieldDecoration`.
- `windows_desktop_shell.dart`: persistent sidebar nav with all 22 destinations.
- `main.dart`: every Windows route wraps its child in `WindowsDesktopShell`; Android routes use the mobile screens.

**Key finding:** the shared design system was **documented but almost entirely bypassed** — `WindowsPage` was used by 0 of 29 screens, `WindowsPageHeader` by 1, `WindowsPanel` by 2, `WindowsMessageState` by 2, `WindowsStatusChip`/`WindowsFieldLabel`/`WindowsFieldDecoration` by 0. Every screen hand-rolled headers, panels, chips, fields, and empty/error states, producing visual drift (28 vs 29 px titles, radii 12–18 instead of 15, `Colors.white` instead of `AppPalette.cardBackground`, raw hex literals).

**Data:** all screens read from real, user-scoped sources (`CaseRepository` over local Drift DB; `FirestoreService` over Firestore for reminders/fees/team/JURIS). No mock data.

---

## 4. Screen Inventory

| Screen | Route | Location | Function | Windows problems |
|---|---|---|---|---|
| Home / command center | `/home` | `windows_home_screen.dart` | Stat tiles, today's hearings, search, quick access | Hand-rolled header/panels/cards; no search field; no reminders preview; stat grid mis-measured (4-col wraps to 3); signed-out/error states bare `Text` |
| Cases register | `/cases` | `windows_cases_screen.dart` | Filter/sort/searchable DataTable of user's cases | Hand-rolled header/filters/chips; `_StatusPill` duplicates `WindowsStatusChip`; nested scroll views; row count text overflows narrow; error = plain `Text` |
| Calendar & hearings | `/calendar` | `windows_calendar_screen.dart` | Month grid + agenda | Hand-rolled header/panels; legend text overflow risk |
| Reminders | `/reminders` | `windows_reminders_screen.dart` | User's deadline list | **Error rendered as empty (gold icon)** — load failure looks like success |
| Starred cases | `/starred` | `windows_cases_screen.dart` (initialStatus) | Starred subset of cases | Same as cases screen |
| Completed / Deleted cases | `/completed_cases`, `/deleted_cases` | `windows_cases_screen.dart`, `windows_deleted_cases_screen.dart` | Lifecycle views | **Deleted cases crashes when signed out** (`currentUserId` throws `StateError` in `build`, ungated) |
| Case detail / Add case | (no route) / `/add_case` | `windows_case_detail_screen.dart`, `windows_add_case_screen.dart` | Case file / registration | Detail uses fixed `SizedBox(width:500)`/`width:260` hero (2-row on most widths); add-case field labels wrong colour/size |
| Fees / Record payment | `/fee`, `/record_payment` | `windows_fees_screen.dart`, `windows_record_payment_screen.dart` | Fee register + payment | Fee detail shows **stale balances after a payment**; field decoration copied verbatim |
| Team | `/team` | `windows_team_screen.dart` | Team/chambers members | Member chip name can overflow; error uses gold icon |
| Profile / Settings | `/profile`, `/settings` | `windows_profile_screen.dart`, `windows_settings_screen.dart` | Account + preferences | Signed-out/load-error are bare unstyled `Text`; settings shows **fabricated "Free / 0 KB" plan while loading** |
| Cloud storage | `/cloud_storage` | `windows_cloud_storage_screen.dart` | Subscription/storage info | Same false-plan-during-loading bug |
| JURIS intelligence | `/juris` | `windows_juris_screen.dart` | AI legal research chat | **No responsive breakpoint** (fixed 270px rail + 300px confirmation card squeeze chat); **token-balance error swallowed** (`catch (_) {}`) |
| Case management | `/case_management` | `windows_case_management_screen.dart` | Operational dashboard | **"ACTIVE CASES" counts completed cases** (mislabeled metric) |
| Notifications / Support / Transfer / Upgrade / Cause list / Clients / Search / Todo / Security / App settings | various | `windows_*.dart` | Secondary modules | Mostly hand-rolled headers/panels/chips; several unlabelled dropdowns; narrow-window overflow in search screen |

---

## 5. Windows-Specific Issues Found

1. **Shared design system bypassed** on 28 of 29 screens — the single biggest consistency defect.
2. **Errors masquerading as empty states** (gold icon) on reminders, clients, fees, team, deleted cases, cause list, search screens.
3. **Deleted-cases hard crash** when signed out (`StateError` from `currentUserId`).
4. **Deleted-case "ACTIVE CASES" metric mislabeled** (includes completed).
5. **False plan data while loading** ("Free / 0 KB") on cloud storage + app settings.
6. **Stale fee balances** after a payment is recorded.
7. **JURIS not responsive; token error swallowed.**
8. **No window title** (`lawyers_e_diary` raw package name), no minimum window size, dark title bar on a light-identity app.
9. **Home screen** missing search, reminders preview, and has a mis-measured stat grid.

---

## 6. Reusable Components Discovered

- `WindowsPageHeader`, `WindowsPanel`, `WindowsMessageState`, `WindowsStatusChip`, `WindowsFieldLabel`, `WindowsFieldDecoration` (all in `windows_desktop_ui.dart`, all read-only usable).
- `WindowsPage` (unused), `AppPalette` tokens, `WindowsDesktopShell` (sidebar), `FirestoreService` (user-scoped reminders/fees/team/JURIS), `CaseRepository` (local case register).
- Existing tests: `test/windows_screens_test.dart`, `test/windows_design_system_test.dart` (both pass).

---

## 7. Risks & Implementation Priorities

**Highest value / lowest risk (done first):**
1. Fix pubspec blocker (done).
2. Design-system adoption across all 29 Windows screens (header → `WindowsPageHeader`, panels → `WindowsPanel`, errors → `WindowsMessageState(isError:true)`, chips → `WindowsStatusChip`, fields → `WindowsFieldDecoration`).
3. Correctness bugs: deleted-cases crash, false plan data, stale fee balances, mislabeled metric, JURIS token error, JURIS responsiveness.
4. Home workspace redesign (search, reminders preview, responsive stat grid).
5. Windows runner: title, min size (900x620), light title bar.

**Android compatibility rule:** zero modifications to `lib/screens/`, `lib/models/`, `lib/services/`, `lib/repositories/`, `android/`, or any Android-specific config. Reading Android code for compatibility analysis only.
