# Firestore Security Baseline

This release replaces the temporary time-based open Firestore rule with an authenticated, ownership- and team-role-based ruleset.

## Identity

- Firebase Auth UID is the canonical account identity.
- `users/{uid}` is private to that authenticated UID.
- `led_id_directory/{ledId}` contains only minimal lookup fields needed to find an existing LED user by LED ID.
- Team membership documents are keyed by Firebase UID.

## Cases

- Personal cases are readable by their owner (`ownerUid`, with legacy `userId` support).
- A team owner can read team cases through the denormalized `teamOwnerUid` field.
- An assigned team member can read a case only when `assignedTo` equals their Firebase UID.
- Team owners/leaders can read team cases through the team membership authorization path.
- Case notes inherit the parent case authorization.

## Teams

- Active members can read their team and team chat/activity.
- Owner/Leader membership is required for team management, member management, groups, assignments, and audit-log writes.
- A member can only deactivate their own membership.
- Ownership transfer requires the authenticated current owner and an active member promoted to owner in the same transaction.

## Personal data

Clients, reminders, fees, fee transactions, and support tickets are scoped to the authenticated owner.

## Deployment

The rules are intentionally not deployed by this repository snapshot. Before production deployment, validate them with the Firebase Emulator/CLI against the real Firebase project and review any legacy data that predates the UID-based identity migration.
