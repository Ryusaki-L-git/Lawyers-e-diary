# LED — FINAL COMPLETION MISSION (Windows + Firebase + Auth + Case System)
## Progress Log

Project: `C:\Users\Lawyers-e-diary-main` (package `lawyers_e_diary`, v1.0.0+1)
Flutter 3.47.6 · Dart 3.13.5 · Visual Studio Community 2026 18.9.2

---

## Environment (must be re-applied each session)

The Flutter SDK and Pub cache live under a path containing a SPACE
(`C:\Users\Zafarullah khan\...`). The sqlite3 native-asset hook passes its path
to `cmd.exe` unquoted, so `flutter test` fails with
`'C:\Users\Zafarullah' is not recognized`.

Workaround (junctions only — nothing was moved or deleted):

```powershell
$env:PUB_CACHE = "C:\Users\ZAFARU~1\AppData\Local\Temp\kilo\pubcache"
& "C:\Users\ZAFARU~1\AppData\Local\Temp\kilo\flutter\bin\flutter.bat" <cmd>
```

Source control: the project directory has **no `.git`** — it is a downloaded
copy, not a maintained repository. There is no branch, no commit history and no
working-tree state to preserve or diff. All changes are therefore tracked in
this log and by file timestamps.

---

## Mission A — Baseline (established, not assumed)

| Check | Result |
|---|---|
| Project directory | `C:\Users\Lawyers-e-diary-main` confirmed |
| Flutter / Dart | 3.47.6 / 3.13.5 |
| Git | **No `.git` directory** — no branch, no commits, no working tree |
| `flutter analyze` (baseline) | **No issues found** |
| `flutter test` (baseline) | **62/62 passed** |
| Firebase project | `lawyer-s-e-diary` (android/ios/macos/windows/web all configured) |
| Firebase init | `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` before `runApp` |
| MSIX certificate | `lawyers-e-diary.pfx` **absent** |
| `firestore.indexes.json` | **absent** at baseline |
| `.firebaserc` | **absent** — no Firebase project linked for deployment |

---

## Mission B — Firebase/Firestore saving failures

### Root causes found (four distinct causes, not one)

1. **Missing composite indexes (deployment configuration gap).**
   `firestore.indexes.json` did not exist and `firebase.json` declared only
   `rules`. Every personal-collection query pairs an equality filter with an
   `orderBy` on a different field, which requires a composite index:
   - `reminders`: `userId` + `dueDateTime` (+`isCompleted`)
   - `todos`: `userId` + `createdAt` desc (+`isCompleted`)
   - `fees`: `userId` + `createdAt` desc
   - plus `clients`, `teams`, `cases` multi-filter queries

   Without the index Firestore rejects the query with `FAILED_PRECONDITION`,
   so a newly written item never appears in the list.

2. **Swallowed write exceptions producing false success.**
   `FirestoreService` caught and discarded errors in `softDeleteCase`,
   `restoreCase`, `updateCaseStatus`, `toggleCaseStarred`,
   `toggleReminderDone`, `deleteReminder`, `saveUserData` and `addNote`.
   The UI reported the action as complete although nothing was written.

3. **Callers with no error surface.** The Windows and mobile reminder lists
   and the starred-cases screen invoked the swallowing methods directly, so a
   failed write was completely silent.

4. **Rules not deployed.** The `/todos` rules exist in `firestore.rules` but
   were never deployed to the live project, so To-Do reads and writes would
   be rejected with `PERMISSION_DENIED`.

### Fixes applied

- **`firestore.indexes.json` (new)** — 10 composite indexes covering every
  personal-collection query. **`firebase.json`** now registers
  `"indexes": "firestore.indexes.json"`.
- **`lib/services/firestore_service.dart`** — the eight swallowing methods now
  `rethrow` after logging. `addClient` / `addFee` / `addReminder` / `addTodo`
  already returned `null` on failure and their callers already checked it.
- **`lib/windows/windows_reminders_screen.dart`**, **`lib/screens/reminders/reminders_list_screen.dart`**,
  **`lib/screens/cases/starred_cases_screen.dart`** — every call now catches
  the error and shows a truthful message.

### Rules verification (not deployed)

`/todos/{todoId}` is owner-scoped and matches the document schema written by
`TodoModel.toMap()` (`userId` is always present, and an update may not
reassign it). No rule was made permissive; no public access was introduced.

---

## Mission C — Authentication persistence

### Root cause

`SplashScreen._determineStartupRoute()` decided the launch route from two
sources that were both unreliable:

```dart
final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
if (!isLoggedIn) return '/login';
final User? user = FirebaseAuth.instance.currentUser;
if (user == null) return '/login';
```

`FirebaseAuth.currentUser` delegates to the **native** SDK, which restores the
persisted session asynchronously. Read synchronously right after
`initializeApp()`, it is still `null`, so a returning user was routed to
`/login`. The local `isLoggedIn` flag then compounded this: it was the gate,
so a lost or unflushed flag locked the user out even with a valid session.
Worse, the surrounding `catch (_) => '/login'` turned a transient Firestore
timeout on the profile read into a sign-out.

### Fix applied (`lib/splash_screen.dart`)

- Firebase Authentication is now the single source of truth. The splash waits
  for the restored session via `authStateChanges().first` with a bounded
  timeout and a short grace-period re-check of `currentUser`.
- The local flag no longer gates routing in either direction.
- A failed profile read now opens the app instead of the login screen.
- `resolveStartupDestination(...)` was extracted as a pure, testable function.
- **`lib/templates/transactions/auth_transactions.dart`** gained `signOut()`,
  which signs out of Firebase and clears the local flag; the profile and
  settings screens now use it, so the flag can no longer claim a signed-out
  user is signed in.

No new login system, no stored passwords or tokens, no verification weakened.

---

## Mission D — Case system audit

The case system is a **local-first** system: cases live in a drift/SQLite
database (`AppDatabase`) and sync to Firestore through `CaseSyncService`. It
does not depend on the personal-collection Firestore queries, which is why it
behaved differently from the modules that appeared to lose data.

### Defect found — the hearing purpose was lost in both directions

`LocalCaseRecord.toCaseModel()` hard-coded `hearingPurpose: null`, and
`toCloudMap()` omitted the field entirely. The value was therefore dropped
whenever a case was read from the local database and whenever a local case
was pushed to the cloud.

### Fix applied

- **`lib/data/local/app_database.dart`** — added a nullable `hearingPurpose`
  column, schema version 2 → 3, with a non-destructive `addColumn` migration.
  Existing rows are untouched.
- **`lib/repositories/case_repository.dart`** — `hearingPurpose` plumbed
  through `LocalCaseRecord`, `fromRow`, `fromLegacyCase`, `toCompanion`,
  `toCloudMap`, `fromCloudMap`, `toCaseModel` and `copyWith`.
  `createCase` now accepts the value.
- Drift code regenerated with `build_runner`.

### Ownership findings — already correct, confirmed by test

Every local query is scoped by `ownerUid`; `saveCase` throws `StateError` when
the authenticated user does not own the record; `FirestoreCaseSyncDataSource`
scopes by `ownerUid`/`userId` and refuses cross-owner writes. The Firestore
rules for `/cases` require ownership for read and update and deny delete.
These are covered by the existing and newly added tests.

### Hearing-date provenance

`caseSource` (`manual` by default) and `hearingPurpose` are stored as
recorded and are never inferred from the date or the court. The WhatsApp
helper maps the source to a *provenance* label only; it never states that the
court fixed the date for that reason.

---

## Mission E — Windows completion

| Defect | Fix |
|---|---|
| `/token_balance` route was dead — the screen was unreachable on both platforms | Added a "Case tokens" sidebar entry in the Windows shell and a "Case Tokens" tile in the mobile profile menu |
| `record_payment_screen.dart` rendered a mobile `AppBar` inside the desktop shell (double chrome) | The Windows branch of `fee_detail_screen.dart` now pushes the native `WindowsRecordPaymentScreen` |
| `team_bottom_navigation.dart` had no Windows guard — a mobile tab bar inside the desktop sidebar | Returns `SizedBox.shrink()` on Windows, matching the existing `AppBottomNavigation` pattern |
| `windows_case_detail_screen.dart` header had the eyebrow but no serif title | Added the `AppTypography.heading` title |
| `windows_juris_screen.dart` used `Colors.amber` (`#FFBF00`), off-palette | Replaced with `AppPalette.statusWarning` |
| The shell had an unreachable `activeRoute == '/calendar_list'` comparison | Removed the dead branch |

Routes: 33 named routes, all resolving. `/calendar_list` and `/full_calendar`
remain registered as legitimate deep-link entry points.

---

## Mission F — WhatsApp hearing update (verified, not rebuilt)

The existing implementation is sound:

- Paid-only gate at the operation boundary; `fetchSubscription()` throwing is
  caught and the action is refused.
- `fetchSubscription()` returns the free tier when the user is signed out or
  has no subscription document — both fail closed.
- The number is reduced to digits and rejected below seven digits, so no
  input can inject a path or query segment into the link.
- The message ends with `Warm regards,` and the signed-in advocate's name when
  available.
- The date source is presented as provenance, never as the reason a court
  fixed the date.
- Cancelling, copying, launch failure and successful launch are each reported
  truthfully. Opening WhatsApp is never reported as proof of sending.

**Security boundary:** this is a client-side check on a link the user opens
manually. It is an entitlement *prompt*, not an unbypassable server-side
boundary — the WhatsApp message is composed on the user's device.

---

## Mission G — JURIS / eCourts boundary (independently audited)

Whole-tree search for `ecourt` returns exactly one hit: a local string
heuristic over `caseSource` in `case_actions_helper.dart` that classifies
provenance for message wording. It performs no network call and holds no
credential.

- `lib/services/ecourts_service.dart` — 0 bytes, empty, imported by nothing.
- `lib/screens/juris/juris_screen.dart` — 0 bytes, empty, imported by nothing.
- `lib/services/juris_service.dart` — only target is `{JURIS_BASE_URL}/chat`,
  authorised with the user's own Firebase ID token. No eCourts domain, no
  eCourts credential, no refresh method.
- `lib/services/case_sync_service.dart` — Firestore only, no HTTP.
- `lib/services/token_service.dart` — only `{JURIS_BASE_URL}/v1/tokens/me` and
  `/v1/ai/usage/me`.

**The boundary is intact.** No repair reintroduced eCourts access.

---

## Verification results (final)

| Check | Command | Result |
|---|---|---|
| Format | `dart format lib test` | 163 files formatted |
| Analyze | `flutter analyze` | **No issues found** (exit 0) |
| Tests | `flutter test` | **81/81 passed** (exit 0) — 62 baseline + 19 new |
| Windows build | `flutter build windows --release` | **SUCCESS** (exit 0) |
| MSIX | `windows\runner\build_msix.ps1` | **Package created** (21.45 MB) |
| Signing | SignTool | **Not signed** — no certificate present |

Artifacts:
- `build\windows\x64\runner\Release\lawyers_e_diary.exe` (15.19 MB)
- `build\windows\x64\runner\Release\lawyers_e_diary.msix` (21.45 MB)

MSIX identity: `LawyersEDiary`, `CN=Lawyers E-Diary`, `1.0.0.0`, `x64`,
`EntryPoint="Windows.FullTrustApplication"`, all seven icon assets and all
runtime DLLs present.

---

## Remaining owner actions

1. **Deploy Firestore indexes and rules** —
   `firebase deploy --only firestore:rules,firestore:indexes`.
   Required for the `/todos` collection and for the clients, reminders, fees
   and to-do list queries. Not deployed: no `.firebaserc` and no project
   credentials are available in this environment.
2. **Provide a code-signing certificate** — place it at
   `windows\runner\resources\lawyers-e-diary.pfx` (or update the path in
   `build_msix.ps1`) and re-run the script. The package is currently unsigned
   and cannot be distributed as trusted.
3. **Real-device verification** — the session-restoration behaviour, live
   Firestore writes and To-Do persistence need an authenticated device run;
   they are not proven by unit tests.
