# Windows UI Renovation Map — Lawyer's E-Diary

Branch: `feat/prestige-home-dashboard`

## Design contract
- Canonical palette: warm ivory `#F7F5F2`, forest green `#1F3D2B`, antique gold `#CCA046`, white cards, charcoal text and warm borders.
- Shared Windows shell: `lib/windows/windows_desktop_shell.dart`.
- Shared primitives: `lib/widgets/windows_desktop_ui.dart` and `lib/widgets/app_palette.dart`.
- Desktop-specific route selection: `lib/main.dart`; Android routes remain on their existing mobile screens.
- Preserve existing data, permissions, service calls, navigation and billing; no mock records.

## Route and screen map

| Area | Windows destination | Route | Renovation focus |
|---|---|---|---|
| Command center | `WindowsHomeScreen` | `/home` | Reference layout; real cases, hearings and reminders |
| Matter register | `WindowsCasesScreen` | `/cases`, `/completed_cases`, `/starred` | Filters, search, status, row/card hierarchy |
| Case creation | `WindowsAddCaseScreen` | `/add_case` | Form rhythm, validation and actions |
| Case management | `WindowsCaseManagementScreen` | `/case_management` | Management actions and status clarity |
| Deleted matters | `WindowsDeletedCasesScreen` | `/deleted_cases` | Recovery/destructive action hierarchy |
| Case search | `WindowsSearchCasesScreen` | `/search_cases` | Search-first results and empty states |
| Case detail | `WindowsCaseDetailScreen` | Used by Windows case flow | Detail sections and action consistency |
| Calendar/hearings | `WindowsCalendarScreen` | `/calendar`, `/calendar_list`, `/full_calendar` | Date navigation, hearing agenda and density |
| Cause list | `WindowsCauseListScreen` | `/cause_list` | Court/day grouping and scanability |
| Clients | `WindowsClientsScreen` | `/clients` | Client directory, actions and states |
| Reminders | `WindowsRemindersScreen` | `/reminders` | Due dates, priority and completion |
| Fees | `WindowsFeesScreen` | `/fee` | Financial hierarchy and balances |
| Record payment | `WindowsRecordPaymentScreen` | `/record_payment` | Safe payment entry and confirmation |
| Team | `WindowsTeamScreen` | `/team` | Member/team overview and permissions |
| Assignment | `WindowsTransferCaseScreen` | `/transfer_case` | Assignment clarity and safeguards |
| JURIS | `WindowsJurisScreen` | `/juris` | Dedicated chat, local recent history, new/open/delete conversations |
| Profile | `WindowsProfileScreen` | `/profile` | Account information and identity |
| Settings | `WindowsSettingsScreen`, `WindowsAppSettingsScreen` | `/settings`, `/settings_native` | Consistent settings navigation |
| Security | `WindowsSecurityScreen` | `/security` | Security controls and confirmation states |
| Cloud storage | `WindowsCloudStorageScreen` | `/cloud_storage` | Storage state and actions |
| Upgrade | `WindowsUpgradeScreen` | `/upgrade` | Token/plan information |
| Notifications | `WindowsNotificationsScreen` | `/notifications` | Read state and action hierarchy |
| To-do | `WindowsTodoScreen` | `/todo` | Task priority and status |
| Support | `WindowsSupportScreen` | `/support` | Help content and support workflow |
| Service catalogue | Windows-specific responsive grid using shared desktop components | `/services` | Live catalogue data, refresh, loading/error/empty states |
| Token balance | Existing balance screen using Windows panels and status states | `/token_balance` | Verify Windows runtime and responsive sizing |
| Usage history | Existing history screen using shared desktop cards and message states | `/usage_history` | Verify long histories and narrow-window layout |

## Shared-shell guarantees
- Collapsible forest-green sidebar with active-route marker, tooltips, keyboard navigation and final LED logo.
- Every destination is reachable through the desktop rail.
- Desktop layout changes remain behind Windows-specific route selection; mobile/Android route selection is not redirected to desktop widgets.

## Verification still required on the Windows machine
- Run `flutter pub get`, `dart format`, `flutter analyze`, and the relevant Flutter tests.
- Launch at laptop and wide-monitor widths; test narrow-width JURIS chat, history selection/deletion, case context, keyboard navigation and route back/forward behavior.
- Inspect login/profile forms and MSIX/executable icons in the packaged build.
- This repository-only edit cannot validate local Windows rendering or runtime behavior.
