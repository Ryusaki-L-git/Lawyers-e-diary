# LED Windows desktop redesign — implementation notes

Branch: windows-desktop-redesign

## Verified source baseline

- Flutter app: Ryusaki-L-git/Lawyers-e-diary
- JURIS API: Ryusaki-L-git/Juris1
- Existing Flutter routes were inspected in lib/main.dart. They include home, cases, case creation/search/management, completed/deleted/transferred/starred cases, calendar/cause list, clients, team, JURIS chat, fees, reminders, notifications, profile, settings, cloud storage, upgrade, and support.
- The repository already contains a Windows Flutter runner and a generated Windows plugin list including Firebase Core, Firebase Auth, Cloud Firestore, printing, share_plus, sqlite3_flutter_libs, and url_launcher_windows.
- The app's current case list uses the existing local Drift repository (CaseRepository) scoped to the authenticated user. The Windows home screen reads through that repository and does not introduce sample case records.
- JURIS is a separate FastAPI backend. Its documented integration uses a Firebase ID token in a Bearer header. The LED chat client requires JURIS_BASE_URL configured at build time. The Windows client sends the documented `legal_research` or `case_detail` screen and, when opened from a case, a lightweight `active_case` reference that the JURIS context resolver must authorize.

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
- lib/windows/windows_transfer_case_screen.dart: Windows team-case assignment workflow backed by TeamService. It only lists cases belonging to a team the user can access, requires an active owner/leader role before exposing assignment, and offers active verified members of that same team. It uses the existing team assignment service rather than rewriting case ownership.
- lib/services/team_service.dart: `assignCase` now independently verifies the caller's active owner/leader membership, the target's active verified membership, and that the selected cloud case belongs to the chosen team before writing the assignment.
- lib/login_screen.dart: Windows email/password sign-in checks the signed-in user's existing `profileCompleted` flag before routing to Home; incomplete profiles continue to `/welcome`. Non-Windows routing remains `/home`.
- lib/windows/windows_case_detail_screen.dart and lib/services/juris_service.dart: the JURIS handoff sends a lightweight selected-case reference (`case` resource ID and display name) in the documented RequestContext contract, not raw case contents. JURIS must still resolve the reference and enforce authorization on the backend.
- lib/windows/windows_settings_screen.dart: added the Windows security/password-recovery shortcut.
- lib/windows/windows_case_detail_screen.dart: document links with secure HTTPS URLs can be opened externally; missing or non-HTTPS links are not treated as working attachments.
- lib/screens/clients/client_detail_screen.dart, lib/screens/team/team_entry_screen.dart, and lib/screens/fees/fee_detail_screen.dart: nested Windows client-edit, team-create, and fee-payment flows now retain the desktop shell; non-Windows navigation remains unchanged.
- lib/windows/windows_cloud_storage_screen.dart: desktop subscription/storage status view; explicitly distinguishes a stored sync timestamp from a real synchronization job.
- lib/windows/windows_upgrade_screen.dart: desktop plan comparison and upgrade request information; does not invent prices or process payments.
- lib/windows/windows_support_screen.dart: desktop knowledge center, support-ticket submission and live ticket history using SupportService.
- lib/windows/windows_app_settings_screen.dart: desktop account/settings hub that routes to existing service-backed pages without pretending unsaved preferences persist.
- lib/windows/windows_edit_profile_screen.dart: desktop professional profile editor preserving the existing Firestore user and LED ID directory update fields.
- lib/windows/windows_security_screen.dart: desktop account security and Firebase password-reset workflow, with honest wording about sync limitations.
- lib/windows/windows_edit_profile_screen.dart and /security route: Windows profile editing and password recovery have dedicated desktop layouts; Android continues to use the original screens.
- lib/windows/windows_desktop_shell.dart: removed duplicate Settings navigation item and labelled the team assignment workflow accurately.
- lib/main.dart: /security is now platform-aware and Windows uses the desktop security page.
- lib/services/firestore_service.dart: case-transfer failures now propagate to the caller so transfer UI can show failure instead of swallowing it.
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

1. Review the Windows welcome/profile-completion screen visually on a real desktop; the existing profile form and ID transaction are reused and must be validated with the actual Firebase project.
2. Make nested create/edit/detail flows retain the desktop shell consistently and review all route transitions, including back behavior.
3. Connect a persistent notification feed only after a real notification model/service exists; the current Windows page intentionally avoids fabricated alerts.
4. Confirm the JURIS backend resolves `active_case` references through its authorized context resolver in the target environment; LED sends only a reference, not case contents.
5. Review empty/loading/error states and keyboard/focus behavior across all desktop pages.
6. The user will run dart format, flutter analyze, flutter test, and flutter build windows locally; address findings from that run.
7. Package the verified Release build for installation only after local checks and Firebase configuration are complete.
