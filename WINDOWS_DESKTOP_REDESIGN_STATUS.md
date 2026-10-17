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
- lib/main.dart: existing named routes are preserved; Windows route entries are wrapped in the desktop shell and /home selects the new Windows home. Android and other platforms continue to use the existing Home screen and route widgets.
- lib/widgets/app_bottom_navigation.dart: existing bottom navigation is hidden on Windows; it remains unchanged on other platforms.
- lib/login_screen.dart: Google Sign-In UI is hidden on Windows, leaving email/password as the initial Windows sign-in method while retaining Google Sign-In on Android.

## Current limitations — not yet production-ready

1. This is the first desktop foundation, not a completed redesign of every module. Existing module screens are currently reused inside the new sidebar shell; each module still needs a Windows-specific layout review and polish.
2. Detail screens opened with direct MaterialPageRoute pushes may leave the persistent shell until those flows are adapted.
3. Firebase initialization still calls Firebase.initializeApp() without DefaultFirebaseOptions.currentPlatform. A repository lookup did not find lib/firebase_options.dart. Windows Firebase initialization must be verified and configured for the actual Firebase project before running the desktop app.
4. JURIS requires a real HTTPS JURIS_BASE_URL; local http://127.0.0.1:8000 is not accepted by the current service's HTTPS-only validation. A deliberate, Windows-development-only localhost configuration would be needed for local testing; production must remain HTTPS.
5. Existing LED screens and JURIS are not yet compile-tested in this environment. No claim is made that Windows build, Firebase sign-in, Firestore access, or JURIS requests have been validated end to end.
6. No secrets or Firebase credentials have been added.

## Next implementation order

1. Verify Flutter/Dart and Windows Firebase setup on the actual Windows development machine.
2. Add a proper Windows authentication layout, preserving email/password first and keeping Android Google Sign-In intact.
3. Redesign cases list and case detail around desktop tables, filters, and a multi-panel workspace while preserving existing repository behavior.
4. Redesign calendar/hearings and client workflows.
5. Redesign reminders, fees, team, JURIS/drafting, profile/settings, and all empty/loading/error states.
6. Adapt nested detail navigation so the desktop shell remains persistent.
7. Run dart format, flutter analyze, flutter test, and flutter build windows on Windows; fix all introduced errors and report pre-existing errors separately.
8. Package the verified Release build for installation only after the checks pass.
