# T4: vehicle management

Owner: Aasif (Member 1). Rules and authorization tests: Thuva (Member 6).
Branch: `feature/member1-vehicle-management`, based on `origin/main` at `9bd7232`, including merged PRs #22 and #23.

## Manager workflow

An authenticated admin or dispatcher opens **Vehicles**, adds a license plate/model/status, and saves. Each vehicle can be edited. The same tab lists real driver accounts with **Assign vehicle** actions, including **Unassigned**. Operations show loading/error/retry states and only confirm success after persistence. Pending saves disable duplicate taps and retain form data on failure.

`VehicleService` exposes `watchVehicles`, `createVehicle(Vehicle)`, `updateVehicle(Vehicle)`, `watchDrivers`, and `assignVehicle(driverId: ..., vehicleId: ...)`. Firestore is injected for tests. New document IDs are allocated by Firestore; no body `id` is written. Server timestamps audit creation, edits and assignment. Writes recheck the authoritative caller role; assignment transactionally checks the target is an existing driver and the selected vehicle still exists.

Assignment writes only `users/{driverUid}.activeVehicleId` and `updatedAt`. The existing driver profile/vehicle subscriptions update the driver home screen without reload. It does not change shift state, vehicle availability, delivery assignment or trip records. Vehicle exclusivity between drivers is not introduced by T4; that requires a separate contract decision.

## Schema and compatibility

T4 explicitly uses `available`, `in_use`, `maintenance`. This supersedes the older vehicle status spelling in Backend Contract v1.1 for new writes. Existing `in-use` documents are normalized on read, and become canonical when saved through the edit form. No bulk migration is run. License plates are trimmed and limited to 32 characters; models to 100. Both must contain non-whitespace text.

Vehicle creation writes only `licensePlate`, `model`, `status`, `createdAt`, `updatedAt`. Editing patches the three managed fields and `updatedAt`, preserving existing type, odometer, creation time and other legacy attributes. Vehicle deletion is not offered and is denied to clients so assignment references are retained.

## Security changes (not deployed)

The prior unrestricted admin update of other profiles is replaced by a narrow manager assignment permission. Both admins and dispatchers may change only a driver's vehicle reference and audit timestamp; an assigned reference must exist, or be the empty string. They cannot use assignment to change roles, identity, shift state or other fields. Driver self-service profile/shift permissions and administrator profile creation remain separate existing permissions.

Vehicle create/update rules validate the required fields, canonical status, bounded text and server audit timestamps. Unauthorized writers, malformed fields, unknown references, forged timestamps, unrelated user changes and vehicle deletion are covered by emulator tests. Do not release the UI against old rules and assume dispatchers can assign vehicles: this branch's rules require separately approved deployment.

## Verification boundary

Automated service/widget tests use injected fake Firestore. Authorization tests use the real local Firestore emulator with the demo project. They cover create/edit/assign/unassign, current-role rejection, validation, legacy status compatibility, persistence failure/retry, duplicate prevention, directory failure/retry, driver access denial and the assigned vehicle appearing on the actual driver home widget.

No physical-phone or live Firebase/Supabase test has been performed for T4. No deployment, claim provisioning, billing change, PR creation or merge is part of this task. No dependency upgrade is required. Exact final test results and verified commit identities are reported in the task handoff.


## Final local checks

- `flutter pub get`: exit 0; no intentional dependency changes.
- `flutter analyze`: exit 0, no issues found (41.4 seconds).
- `flutter test --reporter expanded`: exit 0, 84 passed, 0 failed.
- Targeted vehicle service/widget suite: 14 passed, 0 failed.
- `npm ci --prefix security`: exit 0. npm reported 5 high-severity advisories in the existing security test dependency tree; no lockfile changes or forced upgrades were made.
- `npx firebase-tools@15 emulators:exec --only firestore --project demo-fleetflow "cd security && npm test"`: exit 0, 29 passed, 0 failed, 0 skipped (48,370.2155 ms test-runner duration).
- Existing main-checkout `analysis_options.yaml` and untracked `AGENTS.md` are outside this isolated worktree and were preserved. Automatically rewritten worktree analysis/dependency files were restored before committing.
