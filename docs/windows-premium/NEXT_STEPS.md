# NEXT_STEPS.md
# Lawyer's E-Diary — Windows Premium Mission: Next Steps

**Date:** 2026-10-21  
**Status:** Mission Phase I complete. All safe, high-value Windows improvements implemented and verified. Remaining work listed below.

---

## 1. Highest-Priority Remaining Tasks

| # | Task | Dependencies | Owner Approval Required? |
|---|---|---|---|
| 1 | **Human visual review** of authenticated home workspace and key screens at multiple window sizes (1360×860, 1920×1080, 920×640). Requires a signed-in Firebase session with real data — not available in this session. | None | No |
| 2 | **End-to-end / integration test** for the signed-in home workspace (cases, upcoming hearings, reminders preview, search). Requires authenticated test fixtures. | Task 1 | No |
| 3 | **Release/MSIX signing build** and Windows App Certification Kit validation. Requires the signing identity / certificate, which was intentionally not exposed or used in this session. | None | **Yes** — signing identity/credential approval |
| 4 | **Microsoft Store listing** (screenshots, description, category, privacy policy). | Task 3 | **Yes** — store publishing decision |
| 5 | **Services screen**: the `/services` route exists but nothing navigates to it from the desktop nav. Decide whether to add a `WindowsServicesScreen` reusing `ServicesCatalogueService` (follows the established per-module Windows pattern) or leave documented as-is. | None | No (if building); document if not |
| 6 | Formal accessibility audit (screen-reader labels, contrast) beyond the implemented focus rings and keyboard navigation. | None | No |

## 2. Items Deliberately Left for the Owner

- **Payment / subscription backend**: The upgrade CTA is an honest dead end ("no connected payment workflow"). Implementing a payment provider was explicitly out of scope for this UI mission.
- **JURIS backend configuration**: Requires `--dart-define=JURIS_BASE_URL`; eCourts access was not added (pre-existing separation preserved).
- **Signing certificate / release**: Not executed; no secrets were exposed.
- **Golden-file visual regression suite**: Recommended but not created.

## 3. Files to Review Before Release

- `docs/windows-premium/` — all seven mission reports (this directory).
- `lib/windows/windows_home_screen.dart` — the redesigned command center (primary visible change).
- `lib/widgets/windows_desktop_ui.dart` — the extended shared design system.
- `lib/windows/windows_desktop_shell.dart` — the responsive, keyboard-navigable shell.
- `windows/runner/main.cpp`, `win32_window.cpp`, `win32_window.h` — title, min size, light title bar.
- `pubspec.yaml` — the repaired duplicate `flutter:` key (verify it is still merged).

## 4. Rollback Notes

All changes are reversible source edits. No configuration versions were changed, no secrets exposed, no irreversible actions taken. The pre-existing `pubspec.yaml` duplicate-key bug was the only structural fix and is strictly a repair.
