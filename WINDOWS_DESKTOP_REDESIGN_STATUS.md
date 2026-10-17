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
- lib/login_screen.dart: a separate Windows two-panel sign-in design with LED branding, email/password authentication, sign-up/help links; existing mobile sign-in layout remains for other platforms.
- lib/main.dart: existing named routes are preserved; Windows route entries are wrapped in the desktop shell and /home selects the new Windows home. Android and other platforms continue to use the existing Home screen and route widgets.
- lib/widgets/app_bottom_navigation.dart: existing bottom navigation is hidden on Windows; it remains unchanged on other platforms.
- lib/login_screen.dart: Google Sign-In UI is hidden on Windows, leaving email/password as the initial Windows sign-in method while retaining Google Sign-In on Android.

## Current limitations — not yet production-ready

1. This is the first desktop foundation, not a completed redesign of every module. Existing module screens are currently reused inside the new sidebar shell; each module still needs a Windows-specific layout review and polish.
2. Detail screens opened with direct MaterialPageRoute pushes may leave the persistent shell until those flows are adapted.
3. Firebase initialization still calls Firebase.initializeApp() without DefaultFirebaseOptions.currentPlatform. A repository lookup did not find lib/firebase_options.dart. Windows Firebase initialization must be verified and configured for the actual Firebase project before running the desktop app.
4. JURIS requires a real HTTPS JURIS_BASE_URL in production. The client now allows http://127.0.0.1 or http://localhost only when running on Windows, for local development; all other non-HTTPS endpoints remain rejected.
5. Existing LED screens and JURIS are not yet compile-tested in this environment. No claim is made that Windows build, Firebase sign-in, Firestore access, or JURIS requests have been validated end to end.
6. No secrets or Firebase credentials have been added.

## Next implementation order

1. Configure and verify Windows Firebase initialization against the real LED Firebase project.
2. Build a Windows-specific signup and password-recovery experience, keeping Android flows unchanged.
3. Continue desktop redesign of clients, reminders, fees, team, JURIS/drafting, profile/settings, and empty/loading/error states.
4. Replace reused mobile cause-list and secondary screens with desktop layouts.
5. Adapt nested detail navigation so the persistent desktop shell stays consistent in every workflow.
6. Configure the local JURIS URL for Windows development and verify case context is passed intentionally, without bypassing authorization.
7. The user will run dart format, flutter analyze, flutter test, and flutter build windows locally; fix any findings from that run.
8. Package the verified Release build for installation only after the local checks pass.
