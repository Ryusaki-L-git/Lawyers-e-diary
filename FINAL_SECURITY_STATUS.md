# Lawyer's E-Diary — Final Team Security Baseline

## Finalized in this release

- Firebase Auth UID is the canonical Team identity.
- LED ID is the human-facing lookup identity.
- `users/{uid}` is private to the authenticated user.
- `led_id_directory/{ledId}` contains only minimal public lookup data.
- Existing-user Team search is LED-ID-only.
- Team membership documents are UID-keyed.
- Member case access is assignment-scoped.
- Owner/Leader Team docket access is role-scoped.
- Case assignment uses `assignedTo` and `teamOwnerUid`.
- Case sync preserves Team assignment fields through merge writes.
- Clients, reminders, fees, fee transactions and support tickets are UID-scoped.
- Team groups/messages/activity are role/member scoped.
- Ownership transfer is constrained by Team role state.
- Temporary time-based open Firestore access is removed.
- Firestore rules default to deny for all unspecified paths.
- The transfer/team-switcher member list no longer reads the private `users` collection.

## Deployment status

This ZIP is a source release. It does **not** deploy Firestore rules or Firebase Functions to the production Firebase project.

Before deployment, run the Firestore rules through the Firebase Emulator/CLI against the real project and review legacy documents created before the UID migration. The repository intentionally contains no Firebase project ID configuration because that was not supplied here.

## Validation performed here

- Firebase configuration JSON parses successfully.
- Firestore rules have balanced structure and contain no temporary expiry rule or open catch-all rule.
- `functions/index.js` passes Node syntax checking.
- The final source diff from Phase 2 contains only the privacy-safe member lookup plus the final security configuration/documentation files.

A live Firebase Emulator/deployment validation was not performed in this environment.
