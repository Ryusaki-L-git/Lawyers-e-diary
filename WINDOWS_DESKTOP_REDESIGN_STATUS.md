# LED Windows desktop redesign — implementation notes

Branch: windows-desktop-redesign

## Verified source baseline

- Flutter app: Ryusaki-L-git/Lawyers-e-diary
- JURIS API: Ryusaki-L-git/Juris1
- Existing Flutter routes were inspected in lib/main.dart. They include home, cases, case creation/search/management, completed/deleted/transferred/starred cases, calendar/cause list, clients, team, JURIS chat, fees, reminders, notifications, profile, settings, cloud storage, upgrade, and support.
- The repository already contains a Windows Flutter runner and a generated Windows plugin list including Firebase Core, Firebase Auth, Cloud Firestore, printing, share_plus, sqlite3_flutter_libs, and url_launcher_windows.
- The app's current case list uses the existing local Drift repository (CaseRepository) scoped to the authenticated user. The Windows home screen reads through that repository and does not introduce sample case records.
- JURIS is a separate FastAPI backend. Its documented integration uses a Firebase ID token in a Bearer header. The LED chat client requires JURIS_BASE_URL configured at build time and currently sends current_screen: unknown.

## Added on this branch

- lib/windows/windows_desktop_shell.dart: Windows-only persistent forest-green navigation sidebar with grouped links.
- lib/windows/windows_home_screen.dart: desktop-first legal command center showing real local case counts, today's hearings, recent case updates, and quick links.
- lib/windows/windows_cases_screen.dart: desktop case register using the existing user-scoped repository, with search, status filters, sorting, and a case-detail handoff.
- lib/windows/windows_case_detail_screen.dart: wide case workspace with parties, court/hearing information, notes, documents, JURIS handoff, starred toggle, and soft-delete action.
- lib/windows/windows_calendar_screen.dart: month calendar and selected-day hearing agenda from the current user's local case repository.
- lib/windows/windows_add_case_screen.dart: desktop case registration form using the existing local-first CaseRepository.
- lib/windows/windows_search_cases_screen.dart: desktop search/filter/sort over the authenticated user's local case register.
- lib/windows/windows_case_management_screen.dart: live local-docket operational summary and shortcuts.
- lib/windows/windows_deleted_cases_screen.dart: local deleted-case register with review and restore actions.
- lib/windows/windows_cause_list_screen.dart: date-specific cause list backed by the local-first case repository.
- lib/windows/windows_clients_screen.dart: desktop client directory with live user-scoped search/type filtering and existing client create/detail flows.
- lib/windows/windows_reminders_screen.dart: desktop reminder table with pending/completed filters and existing complete/delete/create operations.
- lib/windows/windows_fees_screen.dart: fee summary and register backed by the existing fee service, with existing create/detail/payment flows.
- lib/windows/windows_team_screen.dart: desktop team/chambers overview backed by TeamService and live membership data.
- lib/windows/windows_juris_screen.dart: desktop JURIS chat workspace using the existing JurisService.
- lib/windows/windows_profile_screen.dart: desktop legal profile backed by the signed-in user's Firestore profile, with existing edit flow.
- lib/windows/windows_settings_screen.dart: desktop settings hub for account, cloud storage, plans, and support.
- lib/windows/windows_notifications_screen.dart: honest empty state; does not show the old hard-coded demo alerts as if they were real notifications.
- lib/login_screen.dart: a separate Windows two-panel sign-in design with LED branding, email/password authentication, sign-up/help links; existing mobile sign-in layout remains for other platforms.
- lib/main.dart: existing named routes are preserved; Windows route entries are wrapped in the desktop shell and /home selects the new Windows home. Android and other platforms continue to use the existing Home screen and route widgets.
- lib/widgets/app_bottom_navigation.dart: existing bottom navigation is hidden on Windows; it remains unchanged on other platforms.
- lib/login_screen.dart: Google Sign-In UI is hidden on Windows, leaving email/password as the initial Windows sign-in method while retaining Google Sign-In on Android; Windows also has a password-reset email action.
- lib/signup_screen.dart: dedicated Windows account-creation layout using the existing account-creation transaction; the original mobile signup layout and Google Sign-In remain on non-Windows platforms.
- lib/main.dart: /completed_cases and /starred use the desktop case register's built-in filters; /deleted_cases uses the local deleted-case view.

## Current limitations — not yet production-ready

1. This is the first desktop foundation, not a completed redesign of every module. Existing module screens are currently reused inside the new sidebar shell; each module still needs a Windows-specific layout review and polish.
2. Detail screens opened with direct MaterialPageRoute pushes may leave the persistent shell until those flows are adapted.
3. Firebase initialization still calls Firebase.initializeApp() without DefaultFirebaseOptions.currentPlatform. A repository lookup did not find lib/firebase_options.dart. Windows Firebase initialization must be verified and configured for the actual Firebase project before running the desktop app.
4. JURIS requires a real HTTPS JURIS_BASE_URL in production. The client now allows http://127.0.0.1 or http://localhost only when running on Windows, for local development; all other non-HTTPS endpoints remain rejected.
5. Existing LED screens and JURIS are not yet compile-tested in this environment. No claim is made that Windows build, Firebase sign-in, Firestore access, or JURIS requests have been validated end to end.
6. No secrets or Firebase credentials have been added.

## Next implementation order

1. Finish the desktop transfer-case workflow and review case status transitions against the local-first repository model.
2. Replace reused mobile support, cloud-storage, upgrade, and remaining secondary screens with desktop layouts where their real workflows support it.
3. Make nested create/edit/detail flows retain the desktop shell consistently and review all route transitions.
4. Connect a persistent notification feed only after a real notification model/service exists; the current Windows page intentionally avoids fabricated alerts.
5. Improve JURIS case-context handoff only through the existing authorized backend contract; do not bypass access checks.
6. Review empty/loading/error states and keyboard/focus behavior across all desktop pages.
7. The user will run dart format, flutter analyze, flutter test, and flutter build windows locally; address findings from that run.
8. Package the verified Release build for installation only after local checks and Firebase configuration are complete.
