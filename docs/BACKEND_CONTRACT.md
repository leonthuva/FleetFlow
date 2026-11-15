# FleetFlow — Backend Contract v1.1

> **Document type:** Revised backend contract for team approval
> **Supersedes:** `FleetFlow_Backend_Contract_Verification.md` (v1.0)
> **Author role:** Thuva — Member 6 (Backend, Database, Integration, QA)
> **Project:** FleetFlow — Flutter + Firebase fleet and delivery management
> **Date:** 2026-11-15
> **Repository under review:** `Fleetflow` — branch `chore/backend-contract-v1.1`, based on `main` at `33b582f`
> **Contract status:** Draft for approval. A1–A12 are **recommended** for approval; U1–U12 require team input. This document does not record any team approval.
> **Implementation status:** No application source file was changed by this contract task. A prior working-tree PR 0 draft exists but is not committed, approved, or deployed. No branch was merged, committed, pushed, or deployed.

---

## 0. Purpose and scope

v1.0 correctly identified that FleetFlow has no working end-to-end Firebase persistence. v1.1 does **not** approve a “client validates, then writes” design. The security boundary is moved to Firebase Security Rules, with the service layer as defence in depth and an optional trusted backend for the two things rules cannot do: verify actual file bytes and send real FCM push.

v1.1 is limited to:

1. Correcting delivery transition security.
2. Correcting Firebase Storage authorization and upload constraints.
3. Correcting notification security and role targeting.
4. Reviewing `feature/member4-history` and replacing “merge the branch” with a tested PR strategy.
5. Re-checking D1–D10 against the models, Firestore Timestamp handling, and service APIs.
6. Separating repository configuration from verified Firebase Console state.

Out of scope: implementing application features, merging branches, committing, pushing, deploying, or changing UI behaviour. The only file produced by this task is this contract document.

---

## 1. Verification summary (2026-11-15)

### 1.1 Repository evidence collected in this review

| Check | Result |
|---|---|
| Current branch | `chore/backend-contract-v1.1` |
| `main` HEAD | `33b582f` (merge of `feature/maps-location`) |
| `flutter --version` | Flutter 3.47.4 stable, Dart 3.13.3 |
| `flutter analyze` on current branch | 24 info-level issues: 23 pre-existing deprecations plus 1 new `prefer_const_constructors` in `test/core/firestore_dates_test.dart:59`; no errors |
| `flutter test` on current branch | **33 tests passed** (24 existing + 9 `parseFirestoreDate` tests) |
| `origin/feature/member4-history` position | 7 commits ahead of `main`, **0 behind** |
| History branch textual conflicts | **None** (`git merge-base` is `33b582f`) |
| History branch diff | 19 files, +2485/−5 |
| `flutter analyze` on history branch | 23 pre-existing info issues; no errors |
| `flutter test` on history branch | **71 tests passed** |
| History test warning | `test/manager_history_test.dart:81` dropdown hit-test warning; test still passes |
| Firebase CLI | 15.30.1 installed; **not authenticated** |
| Firebase project probes | `CONFIGURATION_NOT_FOUND` for Identity Toolkit; 404 for Firestore REST, Storage bucket root, and Hosted config |
| Rules emulator gate | **Not verified.** Default `JAVA_HOME` is JDK 17; Firebase CLI requires JDK 21. With JDK 21 selected, the emulator download timed out in this audit. `firebase-debug.log` records an earlier emulator attempt but no successful completion. |

### 1.2 Repository files produced before this task

These are present in the working tree but are **untracked drafts**, not committed or deployed:

- `firebase.json`
- `firestore.rules`
- `storage.rules`
- `firestore.indexes.json`
- `lib/core/firestore_dates.dart`
- `lib/core/app_config.dart`
- `test/core/firestore_dates_test.dart`

They are useful starting points. They are **not** the contract. PR 0 must reconcile them with the corrections in Sections 2, 3, and 5 before merge.

### 1.3 Current working-tree state

```
 M analysis_options.yaml
?? docs/BACKEND_CONTRACT.md
?? firebase.json
?? firestore.indexes.json
?? firestore.rules
?? lib/core/
?? storage.rules
?? test/core/
```

`analysis_options.yaml` has a pre-existing local change (`web/**` added to the analyzer exclude list). It is unrelated to PR 0 and must not be included in PR 0 unless the team explicitly approves it.

---

## 2. Correction 1 — Delivery transition security

### 2.1 Threat model

The client is untrusted. A modified app or direct REST call can:

- call `updateStatus` with any string;
- update another driver’s delivery if rules allow collection-wide writes;
- set `completed` without a proof;
- rewrite `driverId` to reassign a delivery;
- set arbitrary `completedAt` or `proofPhotoUrl` values;
- create a proof document that points at a URL that was never uploaded.

Client-side `DeliveryStatus.isValidTransition()` in `lib/models/delivery.dart:80-90` is necessary for UX but is **not** a security control. `DeliveryService.updateStatus()` currently accepts any status (`lib/services/delivery_service.dart:130-166`) and silently swallows Firestore errors.

### 2.2 Enforcement layers

| Layer | Responsibility | Security boundary? |
|---|---|---|
| UI (`delivery_detail_screen.dart`) | Show only the next action; `return` after a proof warning | No |
| `DeliveryService` | Reject illegal transition; write exact fields; use `WriteBatch` for proof + completion | Defence in depth |
| Firestore Security Rules | Authoritative ownership, status order, timestamp shape, proof existence | **Yes** |
| Trusted backend (optional) | Verify Storage object exists and bytes are an image; send FCM | Strongest; not available now |

### 2.3 Canonical transition matrix

| Current | Target | Actor allowed | Rule requirements |
|---|---|---|---|
| `assigned` | `picked_up` | assigned driver | `driverId == auth.uid`; only `status`, `pickedUpAt`, `updatedAt` change; both timestamps |
| `picked_up` | `in_transit` | assigned driver | same; `inTransitAt` is a timestamp |
| `in_transit` | `arrived` | assigned driver | same; `arrivedAt` is a timestamp |
| `arrived` | `completed` | assigned driver | same **and** a valid `deliveryProofs/{deliveryId}` exists; proof `driverId == auth.uid`; proof `photoUrl == delivery.proofPhotoUrl` |
| any non-terminal | `cancelled` | `admin` or `dispatcher` only | `cancelledAt` timestamp; non-empty `cancelReason` |
| any non-terminal | assignment-field edit | `admin` or `dispatcher` only | status unchanged; only assignment/metadata fields change |
| any terminal | any | nobody | `completed` and `cancelled` are immutable from the app |
| `assigned` | `in_transit` / `completed` | nobody | skipped states rejected |
| any | backwards | nobody | reverse transitions rejected |

Persisted status enum:

```
assigned -> picked_up -> in_transit -> arrived -> completed
any non-terminal -> cancelled
```

`DeliveryStatus.all` must include `cancelled`. `DeliveryStatus.standardSequence` remains the five forward states only. `DeliveryStatus.getLabel(completed)` may return `Delivered` for display, but the stored value is always `completed`.

### 2.4 Firestore rules draft — delivery ownership and transitions

This is the authoritative rule shape for `deliveries/` and `deliveryProofs/`. The existing `firestore.rules` draft is close; PR 0 must keep this shape.

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }

    function role() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    function isAdmin() { return signedIn() && role() == 'admin'; }
    function isManager() { return signedIn() && role() in ['admin', 'dispatcher']; }
    function isDriver() { return signedIn() && role() == 'driver'; }

    function onlyChanged(keys) {
      return request.resource.data.diff(resource.data).affectedKeys().hasOnly(keys);
    }

    function driverTransition(deliveryId) {
      let current = resource.data.status;
      let next = request.resource.data.status;
      let proofPath = /databases/$(database)/documents/deliveryProofs/$(deliveryId);

      return
        (current == 'assigned' && next == 'picked_up'
          && onlyChanged(['status', 'pickedUpAt', 'updatedAt'])
          && request.resource.data.pickedUpAt is timestamp
          && request.resource.data.updatedAt is timestamp)
        ||
        (current == 'picked_up' && next == 'in_transit'
          && onlyChanged(['status', 'inTransitAt', 'updatedAt'])
          && request.resource.data.inTransitAt is timestamp
          && request.resource.data.updatedAt is timestamp)
        ||
        (current == 'in_transit' && next == 'arrived'
          && onlyChanged(['status', 'arrivedAt', 'updatedAt'])
          && request.resource.data.arrivedAt is timestamp
          && request.resource.data.updatedAt is timestamp)
        ||
        (current == 'arrived' && next == 'completed'
          && onlyChanged(['status', 'completedAt', 'proofPhotoUrl',
                          'signatureNotes', 'updatedAt'])
          && request.resource.data.completedAt is timestamp
          && request.resource.data.updatedAt is timestamp
          && request.resource.data.proofPhotoUrl is string
          && (existsAfter(proofPath) || exists(proofPath))
          && getAfter(proofPath).data.driverId == request.auth.uid
          && getAfter(proofPath).data.photoUrl == request.resource.data.proofPhotoUrl);
    }

    function managerUpdate(deliveryId) {
      let current = resource.data.status;
      let next = request.resource.data.status;
      let proofPath = /databases/$(database)/documents/deliveryProofs/$(deliveryId);

      return
        (current == next
          && current in ['assigned', 'picked_up', 'in_transit', 'arrived']
          && onlyChanged(['driverId', 'vehicleId', 'pickupAddress', 'address',
                          'latitude', 'longitude', 'recipientName',
                          'recipientPhone', 'packageDescription',
                          'specialInstructions', 'priority', 'eta',
                          'assignedAt', 'updatedAt'])
          && request.resource.data.updatedAt is timestamp)
        ||
        (current in ['assigned', 'picked_up', 'in_transit', 'arrived']
          && next == 'cancelled'
          && onlyChanged(['status', 'cancelledAt', 'cancelReason', 'updatedAt'])
          && request.resource.data.cancelledAt is timestamp
          && request.resource.data.updatedAt is timestamp
          && request.resource.data.cancelReason is string
          && request.resource.data.cancelReason.size() > 0)
        ||
        (current == 'arrived' && next == 'completed'
          && onlyChanged(['status', 'completedAt', 'proofPhotoUrl',
                          'signatureNotes', 'updatedAt'])
          && request.resource.data.completedAt is timestamp
          && request.resource.data.updatedAt is timestamp
          && request.resource.data.proofPhotoUrl is string
          && (existsAfter(proofPath) || exists(proofPath))
          && getAfter(proofPath).data.photoUrl == request.resource.data.proofPhotoUrl);
    }

    match /deliveries/{deliveryId} {
      allow read: if isManager()
        || (isDriver() && resource.data.driverId == request.auth.uid);

      allow create, delete: if isManager();

      allow update: if (isManager() && managerUpdate(deliveryId))
        || (isDriver()
            && resource.data.driverId == request.auth.uid
            && request.resource.data.driverId == request.auth.uid
            && driverTransition(deliveryId));
    }

    match /deliveryProofs/{deliveryId} {
      allow read: if isManager()
        || (isDriver() && resource.data.driverId == request.auth.uid);

      allow create: if isDriver()
        && request.resource.data.driverId == request.auth.uid
        && !exists(/databases/$(database)/documents/deliveryProofs/$(deliveryId))
        && get(/databases/$(database)/documents/deliveries/$(deliveryId)).data.status == 'arrived'
        && get(/databases/$(database)/documents/deliveries/$(deliveryId)).data.driverId == request.auth.uid
        && request.resource.data.photoUrl is string
        && request.resource.data.storagePath is string
        && request.resource.data.timestamp is timestamp
        && request.resource.data.capturedLocation is map
        && request.resource.data.capturedLocation.lat is number
        && request.resource.data.capturedLocation.lng is number;

      allow update, delete: if isAdmin();
    }
  }
}
```

Notes:

- `deliveryProofs/{deliveryId}` uses the delivery id as the proof id. Submission is idempotent and the completion rule checks one document.
- `existsAfter()` lets a client create the proof and update the delivery in one `WriteBatch`. `getAfter()` validates the proof in the same atomic operation.
- Managers are **not** allowed to bypass the proof requirement. Their completion path uses the same proof check. If the team later wants a dispatcher override, it must be a separate, audited field and a separate decision (U12).
- `get()` calls in rules are billed reads. Keep the rule set within the Firestore access-call limits (10 per single request; 20 per batch/transaction).

### 2.5 Proof submission sequence (client service)

`DeliveryService.submitProof()` must perform this order:

1. Read the authenticated uid from `FirebaseAuth.instance.currentUser`; do not trust a caller-supplied uid. Verify the delivery status is `arrived` and `driverId == auth.uid`.
2. Resize/compress the image (`image_picker` `imageQuality: 85`, `maxWidth: 1600`) and validate the local file extension/MIME.
3. Upload to Storage at `proofs/{deliveryId}/{epochMillis}.jpg` with metadata `{deliveryId, driverId, uploadedAt}`.
4. In one `WriteBatch`:
   - `set` `deliveryProofs/{deliveryId}` with the returned URL and path;
   - `update` `deliveries/{deliveryId}` with `status: completed`, `proofPhotoUrl: url`, `signatureNotes`, `completedAt: FieldValue.serverTimestamp()`, `updatedAt: FieldValue.serverTimestamp()`.
5. If the batch fails, delete the orphan Storage object and surface the real error. The Storage rule must allow this narrow delete (Section 3.3). Do not leave a fake success.
6. Only after the batch commits, send the manager notification. A notification failure must be visible to the caller but must not roll back the delivery.

The UI guard in `delivery_detail_screen.dart:28-39` must `return` after showing the “capture proof first” message. Today it warns and then continues, which is a correctness bug.

### 2.6 Trusted backend option

If the team enables Blaze, add a callable function:

```
completeDelivery({ deliveryId, storagePath })
  - verify caller uid == delivery.driverId
  - verify delivery.status == 'arrived'
  - verify Storage object exists and content type is an allowed image
  - create proof doc + update delivery in one Admin SDK transaction
  - send FCM to managers
```

This is the only way to verify actual file bytes and to guarantee push delivery. It is not required for the rules-only Target-1 path, but it removes the residual risk that a client writes a proof document pointing at an object it did not upload. Treat it as post-MVP hardening (U7).

### 2.7 Deployment warning

The current app writer does not satisfy these rules. `DeliveryService.updateStatus()` writes only `status`, `updatedAt`, and sometimes `completedAt`; it does not write the stage timestamp, and it accepts any status. If the v1.1 rules are deployed before PR 2, every driver transition will be denied. **Do not deploy `firestore.rules` to the real project until PR 2 (delivery service) and PR 6 (notifications) are merged and tested.** Use the emulator for rules tests in the meantime.

---

## 3. Correction 2 — Firebase Storage authorization

### 3.1 Verified current capabilities

Confirmed against the current official Firebase documentation for Cloud Storage Security Rules (2026):

- `request.auth` exposes `uid` and JWT claims (`request.auth.token`).
- `request.resource` exposes the incoming object’s `size`, `contentType`, and developer `metadata`; `resource` exposes the existing object.
- Rules support granular `get`, `list`, `create`, `update`, and `delete`.
- Rules support cross-service Cloud Firestore access via `firestore.get()` and `firestore.exists()`.
  - Only the default Firestore database is visible.
  - **No more than two Firestore documents may be accessed in a single Rules evaluation.**
  - Firestore reads from Storage Rules are billed and require the cross-service IAM permission to be enabled in the console or CLI.
- Rules can validate declared `contentType` and actual `size`.
- Rules **cannot** prove that the declared MIME type matches the file bytes. A client can spoof `contentType`. Only a trusted backend or server-side image inspection can verify the bytes.

The v1.0 statement “Storage rules cannot read Firestore” is outdated. The correct v1.1 position is: Storage rules can read the default Firestore database, subject to IAM and quota limits, so delivery ownership can be enforced at upload time.

### 3.2 Canonical Storage contract

| Item | v1.1 decision |
|---|---|
| Path | `proofs/{deliveryId}/{epochMillis}.jpg` |
| Example | `proofs/DEL-2041/1760000000000.jpg` |
| Metadata | `{ deliveryId, driverId, uploadedAt }` |
| Declared content type | `image/jpeg`, `image/png`, or `image/webp` only |
| Maximum size | **5 MiB** (`5 * 1024 * 1024` bytes) |
| File name | digits + `.jpg` / `.jpeg` / `.png` / `.webp` |
| Driver write | only assigned driver, only while delivery is `arrived` |
| Manager read | `admin` / `dispatcher` |
| Driver read | own proof only |
| Update | denied from the app |
| Delete | assigned driver only while delivery is still `arrived` (orphan cleanup); denied after `completed` |
| Legacy paths | `deliveries/{deliveryId}/proof_<ts>.jpg` and `pod/{deliveryId}.jpg` are deprecated; do not write new files |

### 3.3 Storage rules draft

```text
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    function signedIn() { return request.auth != null; }

    function delivery(deliveryId) {
      return firestore.get(
        /databases/(default)/documents/deliveries/$(deliveryId)
      ).data;
    }

    function canUpload(deliveryId) {
      let d = delivery(deliveryId);
      return d.driverId == request.auth.uid && d.status == 'arrived';
    }

    function canRead(deliveryId) {
      let d = delivery(deliveryId);
      let user = firestore.get(
        /databases/(default)/documents/users/$(request.auth.uid)
      ).data;
      return d.driverId == request.auth.uid
        || user.role in ['admin', 'dispatcher'];
    }

    match /proofs/{deliveryId}/{fileName} {
      allow create: if signedIn()
        && canUpload(deliveryId)
        && request.resource.size <= 5 * 1024 * 1024
        && request.resource.contentType in ['image/jpeg', 'image/png', 'image/webp']
        && fileName.matches('^[0-9]+\\.(jpg|jpeg|png|webp)$')
        && request.resource.metadata.deliveryId == deliveryId
        && request.resource.metadata.driverId == request.auth.uid;

      allow read: if signedIn() && canRead(deliveryId);

      // Orphan cleanup only. Once the proof batch completes, the delivery
      // status is 'completed' and this delete is denied.
      allow delete: if signedIn()
        && delivery(deliveryId).driverId == request.auth.uid
        && delivery(deliveryId).status == 'arrived';

      allow update: if false;
    }

    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

Important implementation notes:

- `canUpload` and `canRead` each read one or two Firestore documents. This stays within the two-document limit. Do not add more `firestore.get()` calls to the same evaluation.
- The metadata checks are not a security boundary by themselves because the client supplies metadata. The path and Firestore ownership check are the boundary; metadata is for audit.
- The narrow `delete` is required because `DeliveryService.submitProof()` must clean up an orphan upload when the batch fails. Without it, the service cannot honour its own error path. The delete is unavailable after completion.
- If the cross-service IAM permission cannot be enabled, use the fallback path `proofs/{deliveryId}/{driverUid}/{fileName}` and rule `driverUid == request.auth.uid`. That fallback still cannot prove the driver owns the delivery; it only proves the uploader. Mark it as a lower-assurance demo mode (U6).
- If iOS HEIC uploads are required, convert to JPEG before upload or add `image/heic` / `image/heif` to the allowlist after testing on a real device. Do not silently accept unknown types (U11).

### 3.4 Residual risk

A determined client can upload a 4 MiB file that is not really an image but declares `image/jpeg`. The rules will accept the declared type. Mitigations:

- Only the assigned driver can upload, only for their `arrived` delivery.
- The file is private to the driver and managers.
- Use a Cloud Function (post-MVP) to inspect magic bytes and delete invalid objects.
- Never render proof URLs in a privileged context without an image decoder/error fallback.

---

## 4. Correction 3 — Notification security and role targeting

### 4.1 Problems in v1.0 and current code

`NotificationService.sendNotification()` currently accepts any `recipientId` and writes `notifications/{id}` with no role or ownership checks (`notification_service.dart:115-148`). Any authenticated user can write an `assignment`, `emergency`, or `safety_alert` for `all_managers`. `all_managers` is not a uid, so a rules query cannot authorize it (`delivery_service.dart:150`, `:228`; `notification_service.dart:36-68`). The demo simulator in `notifications_screen.dart:34-78` writes arbitrary `all_managers` alerts.

The existing `firestore.rules` draft already restricts driver-created alerts to the driver’s own delivery or trip. It still has a gap: a driver can set `recipientIds` to arbitrary uids while claiming `audience: managers`. v1.1 closes that gap with a concrete manager-target document.

### 4.2 Role model (unchanged)

`UserRole.admin`, `UserRole.dispatcher`, `UserRole.driver` (`lib/models/user.dart:1-7`). A manager is `admin` or `dispatcher`.

### 4.3 Canonical notification document

```json
{
  "createdBy": "<uid>",
  "audience": "managers | driver | all",
  "recipientIds": ["<uid>", "..."],
  "recipientRoles": ["admin", "dispatcher"],
  "title": "Delivery Status Updated",
  "message": "DEL-2041 status changed to In Transit.",
  "type": "assignment | status_change | route_deviation | safety_alert | delivery_completed | emergency",
  "timestamp": "<Firestore Timestamp>",
  "readBy": ["<uid>"],
  "metadata": { "deliveryId": "DEL-2041", "tripId": null, "status": "in_transit" }
}
```

### 4.4 Manager target document (new in v1.1)

To align driver-created manager alerts with the `admin` and `dispatcher` roles without allowing arbitrary recipients, use one admin-maintained target document:

```json
// notificationTargets/managers
{
  "uids": ["<admin uid>", "<dispatcher uid>"],
  "updatedAt": "<Firestore Timestamp>"
}
```

- Only `admin` may write this document.
- Aasif creates it when seeding manager accounts and updates it when a manager account is added or removed.
- Drivers may read it so the service can fill `recipientIds` for a manager alert.
- A driver-created manager alert must have `recipientIds` exactly equal to this list (order-insensitive). The rule checks both directions with `hasAll`.
- If the document is missing or empty, driver-created manager alerts fail. That is intentional: no manager target, no alert.

### 4.5 Who may create what

| Event type | Driver may create? | Manager may create? | Required link |
|---|---|---|---|
| `assignment` | No | Yes (`admin`/`dispatcher`) | `metadata.deliveryId` assigned to target driver |
| `status_change` | Yes, own delivery only | Yes | own `deliveries/{id}` where `driverId == auth.uid` |
| `route_deviation` | Yes, own active trip/delivery | Yes | own `trips/{id}` or `deliveries/{id}` |
| `safety_alert` | Yes, own active trip | Yes | own `trips/{id}` |
| `delivery_completed` | Yes, own delivered delivery | Yes | own `deliveries/{id}` with proof |
| `emergency` | Yes, own active trip | Yes | own `trips/{id}` |

Drivers can never create an `assignment`, cannot target another driver, and cannot create a manager alert for a delivery or trip that is not theirs.

### 4.6 Driver alert message policy

For driver-created alerts, the service generates `title` and `message` from fixed templates in `NotificationService`. The driver may supply structured metadata (delivery id, trip id, status, location) but not arbitrary manager-facing prose. This prevents a driver from fabricating a misleading manager alert even though rules cannot validate free text. This is A12.

### 4.7 Firestore rules draft — notifications

```text
match /notificationTargets/{audience} {
  allow read: if signedIn();
  allow write: if isAdmin();
}

match /notifications/{notificationId} {
  function notificationAudienceValid() {
    let data = request.resource.data;
    return
      (data.audience == 'managers'
        && data.recipientRoles == ['admin', 'dispatcher'])
      ||
      (data.audience == 'driver'
        && data.recipientRoles == ['driver'])
      ||
      (data.audience == 'all'
        && data.recipientRoles == ['admin', 'dispatcher', 'driver']);
  }

  function managerTargets() {
    return get(/databases/$(database)/documents/notificationTargets/managers).data.uids;
  }

  function driverNotificationValid() {
    let data = request.resource.data;
    let metadata = data.metadata;
    let targets = managerTargets();

    return
      data.audience == 'managers'
      && data.recipientRoles == ['admin', 'dispatcher']
      && data.recipientIds.hasAll(targets)
      && targets.hasAll(data.recipientIds)
      && data.type in [
           'status_change', 'route_deviation',
           'safety_alert', 'delivery_completed', 'emergency'
         ]
      && metadata is map
      && (
        ('deliveryId' in metadata
          && metadata.deliveryId is string
          && get(/databases/$(database)/documents/deliveries/$(metadata.deliveryId))
               .data.driverId == request.auth.uid)
        ||
        ('tripId' in metadata
          && metadata.tripId is string
          && get(/databases/$(database)/documents/trips/$(metadata.tripId))
               .data.driverId == request.auth.uid)
      );
  }

  allow read: if signedIn()
    && request.auth.uid in resource.data.recipientIds;

  allow create: if signedIn()
    && request.resource.data.createdBy == request.auth.uid
    && request.resource.data.recipientIds is list
    && request.resource.data.recipientIds.size() > 0
    && request.resource.data.recipientRoles is list
    && notificationAudienceValid()
    && request.resource.data.timestamp is timestamp
    && request.resource.data.type in [
         'assignment', 'status_change', 'route_deviation',
         'safety_alert', 'delivery_completed', 'emergency'
       ]
    && (
      isManager()
      ||
      (isDriver() && driverNotificationValid())
    );

  allow update: if signedIn()
    && request.auth.uid in resource.data.recipientIds
    && onlyChanged(['readBy'])
    && request.resource.data.readBy is list
    && request.resource.data.readBy.hasAll(resource.data.readBy)
    && request.resource.data.readBy.size() <= resource.data.readBy.size() + 1
    && request.auth.uid in request.resource.data.readBy;

  allow delete: if isAdmin();
}
```

Notes:

- Authorization uses `recipientIds` (concrete uids), not `all_managers` and not a role string.
- `recipientRoles` is an audit/targeting label and must match the audience.
- Manager-created notifications are not restricted to the target list; managers may address drivers or other managers.
- Driver-created notifications must match the manager target document exactly. This is the rule-level barrier against arbitrary recipient fabrication.
- `read` is replaced by `readBy: [uid]`. Mark-as-read uses `arrayUnion([uid])`; one manager reading an alert no longer marks it read for every manager.
- Residual risk: rules can validate ownership and the event type, but they cannot prove that a driver’s structured metadata is truthful. Fixed templates (4.6) and audit fields mitigate this. A trusted backend is the only complete solution (U7).

### 4.8 Query and index

Manager feed:

```
where('recipientIds', arrayContains: uid)
  .orderBy('timestamp', descending: true)
```

Driver feed uses the same query with the driver uid. Composite index: `recipientIds` array-contains + `timestamp` descending. This is already in `firestore.indexes.json`.

The demo notification simulator must be gated behind `AppConfig.demoMode`; it currently writes arbitrary `all_managers` alerts.

---

## 5. Correction 4 — `feature/member4-history` branch review

### 5.1 Current branch state (verified)

| Check | Result |
|---|---|
| Branch base | `25ff1b1` is 7 commits ahead of `main` (`33b582f`), **0 behind** |
| Textual merge conflicts | **None** (`git merge-base` is `33b582f`) |
| `flutter test` on branch in a detached temp worktree | **71 tests passed** |
| `flutter analyze` on branch | 23 pre-existing info-level deprecations; no errors |
| Non-fatal test warning | `test/manager_history_test.dart:81` dropdown hit-test warning; test still passes |
| Files changed | 19 files, +2485/−5 |
| Shared files changed | `lib/main.dart`, `lib/models/trip.dart`, `lib/screens/admin/admin_dashboard_screen.dart`, `lib/screens/driver/driver_home_screen.dart` |
| Added files | Trip model extension, `trip_summary`, `TripService`, `TripAlertService`, `HistoryProvider`, history screens/widgets/formatters, 5 test files, `docs/HANDOFF_MEMBER4.md` |

The branch is mergeable **today**, but that is not the same as safe to merge. It carries sample data (`driverId` values such as `Marcus Vance`), writes an `id` field inside trip documents, uses `all_managers`, and includes a duplicate draft of the Firestore rules/indexes in its handoff doc. Those conflict with v1.1 even without a textual Git conflict.

### 5.2 Shared-file conflict map

| File | Why it conflicts | Current owner | Required treatment |
|---|---|---|---|
| `lib/models/trip.dart` | `main` has a 17-line stub; branch replaces it. Timestamp/uid contract changes also touch it | Aadhil | First history PR; rebase on contract foundation; no UI in same PR |
| `lib/main.dart` | Branch adds `HistoryProvider`, `/history`, and injects provider into admin/driver screens. Aasif/Gajanan/Nippuni also need routes/providers | Member 1 / shared | Do not let history touch this until PR 0/1/2 and driver integration land; one small PR at the end |
| `lib/screens/admin/admin_dashboard_screen.dart` | Branch adds fifth History tab; Gajanan also edits Deliveries tab for assignment. Same file, different regions | Member 1/2 | History tab edit last, after assignment UI, with owner review |
| `lib/screens/driver/driver_home_screen.dart` | Branch adds History button; Gajanan/Nippuni also edit driver home | Member 2 | History button last, after driver integration |
| `lib/services/notification_service.dart` | `TripAlertService` calls the old `sendNotification` + `all_managers` shape | Baary | History PR must consume the v1.1 `send`/`sendNotification` adapter; do not add a second notification path |
| `docs/HANDOFF_MEMBER4.md` | Contains a duplicate Firestore rules/index draft that will drift | Aadhil/Thuva | Update to point at canonical `firestore.rules` / `firestore.indexes.json`; remove duplicated rules |
| `test/*` | New tests are low conflict risk | Aadhil | Keep tests in the same PR slice as the code they cover |

### 5.3 Tested PR strategy (do not merge the whole branch)

Create new branches from current `main` and split the history work into three stacked PRs. Use `git cherry-pick` or `rebase --onto`; do **not** merge the entire branch and do **not** force-push shared branches.

| Slice | Branch | Contents | Depends on | Gate |
|---|---|---|---|---|
| H1 | `feature/history-data-layer` | Trip model extension, `TripSummary`, `TripService`, `TripAlertService`, model/service/alert tests. No UI, no shared files. | PR 0 + PR 2 | `flutter analyze`; `flutter test test/trip_history_test.dart test/trip_alert_test.dart` |
| H2 | `feature/history-provider` | `HistoryProvider`, formatters, widgets, provider/screen-level tests that do not require shared route edits | H1 | `flutter test test/history_provider_test.dart test/trip_history_screen_test.dart` |
| H3 | `feature/history-screens` | History screens, fifth admin tab, driver History button, `/history` route, handoff-doc cleanup | H2 + PR 4 + PR 7 | `flutter test test/manager_history_test.dart test/trip_history_screen_test.dart`; fix dropdown warning |

Suggested commit mapping (inspect each commit before cherry-picking; split by file ownership, not blindly by commit):

| Commit | Subject | Target slice |
|---|---|---|
| `c55d3d4` | Trip model/service/summary | H1 |
| `58317a5` | Trip completion and long-running alerts | H1 |
| `25ff1b1` | Demo trips for the mock driver | H1, behind demo mode |
| `fd16ab8` | HistoryProvider with filters and reports | H2 |
| `2a84213` | Driver trip history/detail screens | H3 |
| `ac0d83f` | Manager History & Reports tab | H3 |
| `e20c1bd` | Member 4 handoff doc | H3 cleanup |

H1 must also:

- write `startTime` / `endTime` as Firestore `Timestamp` in `TripService`, not ISO strings;
- stop writing `id` inside the document body;
- use Firebase uid for `driverId` (display names are a lookup concern);
- keep sample data behind `AppConfig.demoMode`;
- route alerts through the v1.1 `NotificationService.send()` with the manager target list, not `all_managers`;
- point its rules/index documentation at the canonical files.

H3 is deliberately last because it is the only slice that edits shared files.

### 5.4 Merge gate for every history slice

1. Rebase onto the current target branch.
2. `flutter analyze` (no new issues).
3. `flutter test` (all tests pass).
4. `dart format --output=none --set-exit-if-changed lib test`.
5. Confirm the diff contains only the slice’s files; no rules, `main.dart`, or unrelated screens in H1/H2.
6. One approving review from the owner of every shared file touched.

---

## 6. Correction 5 — Review of D1–D10 against models, timestamps, and services

### 6.1 D0 conventions (revised)

1. **Document ID is identity.** Do not persist `id`, `uid`, or `deliveryId` inside the document body. Read-side aliases remain for one migration window.
2. **At rest, timestamps are Firestore `Timestamp`.** Writes use `FieldValue.serverTimestamp()` for server events. Models parse with one shared helper. ISO strings are legacy read input only.
3. **camelCase field names**, matching Dart model names.
4. **Services are the only Firestore/Storage touchpoint.** Screens never call `FirebaseFirestore` or `FirebaseStorage` directly.
5. **`driverId` is always Firebase Auth uid** in deliveries, trips, proofs, users, and notifications. Display names are resolved through `users`.
6. **Demo fallback is explicit and visible.** No silent catch, no fake URL, no seed write outside `AppConfig.demoMode`.
7. **No dual writes.** A field/collection has one canonical name. Aliases are read-only compatibility.
8. **No silent success.** A failed write is an error surfaced to the caller.

### 6.2 D1–D10 decision register (revised)

| ID | v1.0 proposal | v1.1 correction | Inconsistency found in current code | Status |
|---|---|---|---|---|
| D1 | 5 states + `cancelled`; update README/admin | Keep 5 forward states + `cancelled`. Add `cancelled` to `DeliveryStatus.all`. Update `README.md:80` and the admin deliveries tab. Display label may be “Delivered” but stored value is `completed`. | `DeliveryStatus.all` omits `cancelled` (`delivery.dart:21-27`); `standardSequence` is forward-only; admin uses `en-route`/`delivered` (`admin_dashboard_screen.dart:733-745`) | **Approvable** |
| D2 | `deliveryProofs/{deliveryId}` idempotent | Keep plural + delivery-id doc id. Canonical field `photoUrl`; accept `photoURL` on read only. Collection `deliveryProof` is legacy. No dual writes. One-time migration script after approval. | Model uses `photoURL`, `id`, `deliveryId` (`delivery_proof.dart`); service writes singular `deliveryProof` with a random `proofId` (`delivery_service.dart:216`); no `storagePath` | **Approvable with migration note** |
| D3 | `DEL-####` via `counters` transaction | Keep `DEL-####` as doc id and business code. Manager/dispatcher only. Rule limits counter increment to `resource.data.value + 1`. Counter reset/offline conflict remains a team decision. | No `counters` service or transaction exists; IDs are hardcoded seeds | **Approvable; U2 remains** |
| D4 | `driverId` = Firebase uid only | Keep. Add `assignedAt`, `cancelledAt`, `cancelReason`, `createdBy` to `Delivery`; add `phone`, `activeVehicleId`, `onShift`, `createdAt`, `updatedAt` to `AppUser`; remove `id` from `Vehicle.toMap` and add `assignedDriverId`, timestamps. Sample/history name-based data must not ship as real data. | `Delivery.toMap` writes `assignedDriverId` alias (`delivery.dart:230-259`); `AppUser` is 4 fields (`user.dart:9-58`); `Vehicle.toMap` writes `id`; samples use names | **Approvable; migration U4 remains** |
| D5 | Firestore `Timestamp` everywhere | Keep. Add `lib/core/firestore_dates.dart`; fix `Delivery`, `DeliveryProof`, `AppNotification`, `Trip`. Do not write ISO strings from `toMap()` to Firestore. | Parser exists and its 9 tests pass, but models do not use it. `Delivery.fromMap` uses `toString()` and defaults `createdAt` to now (`delivery.dart:184-228`); `toMap` writes ISO (`delivery.dart:230-259`); `DeliveryProof` and `AppNotification` do the same; `Trip` on `main` has no serialization; history branch has its own parser and writes ISO in `toMap` | **Approvable** |
| D6 | `recipients` array + role:manager | Replace `all_managers` with concrete `recipientIds` plus audit `recipientRoles`; `readBy` per user; driver-created manager alerts must match `notificationTargets/managers`; fixed message templates for driver alerts. | `AppNotification` has singular `recipientId`, global `read`, no `createdBy`/`audience`/`recipientRoles`/`readBy` (`app_notification.dart:69-143`); service writes `all_managers`; no target list | **Principle approvable; U1 remains** |
| D7 | `proofs/{deliveryId}/{ts}.jpg` | Keep path plus metadata; 5 MiB; JPEG/PNG/WebP; Storage rules check assigned driver + `arrived` via Firestore; narrow delete for orphan cleanup. Deprecate `deliveries/...` and `pod/...` paths. | `StorageService` writes `deliveries/{id}/proof_ts.jpg`, returns `String`, returns a fake Unsplash URL on failure, sets only `deliveryId`/`uploadedAt` metadata (`storage_service.dart:20-57`) | **Approvable; cross-service IAM U6** |
| D8 | `--dart-define=DEMO_MODE=true` only | Keep. Tests must inject fakes instead of enabling global demo mode. Remove fake Unsplash URL, fake auth, and silent catches. Show a `DEMO DATA` banner. | `AppConfig.demoMode` exists, but `DeliveryService`, `DriverProvider`, and `NotificationService` seed always; `AuthProvider` is fake; `FirebaseService.initialize` swallows errors | **Approvable** |
| D9 | Merge history branch before Aadhil starts | Do not merge the whole branch. Use H1/H2/H3 stacked PRs; Aadhil starts H1 from current `main` after PR 0/2. | Branch uses names, writes `id`, ISO `toMap`, `all_managers`, silent local fallback | **Approvable** |
| D10 | Hard block arrived→completed | Keep. Rule requires proof doc + assigned driver + proof URL match; UI must `return` after warning; service must validate `arrived` and proof before writing. | `submitProofOfDelivery` does not require `arrived` (`delivery_service.dart:173-240`); `updateStatus` accepts `completed`; UI warns then continues (`delivery_detail_screen.dart:28-39`) | **Approvable** |

### 6.3 Canonical Firestore schemas

#### `users/{uid}`

```json
{
  "email": "driver@fleetflow.dev",
  "displayName": "Marcus Vance",
  "role": "admin | dispatcher | driver",
  "phone": "+1...",
  "activeVehicleId": "veh_01",
  "onShift": false,
  "fcmToken": "<string | null>",
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>"
}
```

Sign-up creates `driver` only. Manager accounts are seeded in the Firebase console or with an Admin SDK script; never via a client-controlled role field.

#### `deliveries/{deliveryId}`

```json
{
  "driverId": "<uid | null>",
  "vehicleId": "<vehicleId | null>",
  "createdBy": "<manager uid>",
  "status": "assigned",
  "pickupAddress": "Central Depot Bay 4",
  "address": "742 Evergreen Terrace, Springfield",
  "latitude": 37.7833,
  "longitude": -122.4167,
  "recipientName": "Apex Health Logistics",
  "recipientPhone": "+1 (415) 892-1100",
  "packageDescription": "2x Medical Cases",
  "specialInstructions": "Ring bell at Gate 2.",
  "priority": "standard | high | urgent",
  "eta": "<Timestamp | null>",
  "proofPhotoUrl": "<string | null>",
  "signatureNotes": "<string | null>",
  "assignedAt": "<Timestamp | null>",
  "pickedUpAt": "<Timestamp | null>",
  "inTransitAt": "<Timestamp | null>",
  "arrivedAt": "<Timestamp | null>",
  "completedAt": "<Timestamp | null>",
  "cancelledAt": "<Timestamp | null>",
  "cancelReason": "<string | null>",
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>"
}
```

Read aliases kept in `Delivery.fromMap` for one migration window: `destination -> address`, `customerName -> recipientName`, `customerPhone -> recipientPhone`, `proofPhotoURL -> proofPhotoUrl`, `pickup -> pickupAddress`. `toMap()` writes canonical names only.

#### `deliveryProofs/{deliveryId}`

```json
{
  "driverId": "<uid>",
  "photoUrl": "<download URL>",
  "storagePath": "proofs/DEL-2041/1760000000000.jpg",
  "timestamp": "<Timestamp>",
  "capturedLocation": {
    "lat": 37.78,
    "lng": -122.41,
    "accuracy": 8.2,
    "address": "..."
  },
  "notes": "Left with receptionist",
  "recipientName": "J. Doe",
  "createdAt": "<Timestamp>"
}
```

`timestamp` is the proof capture time and may be written with `Timestamp.now()` because it describes a client capture. Delivery lifecycle timestamps use `FieldValue.serverTimestamp()`.

#### `trips/{tripId}`

Exactly Member 4’s shape, with v1.1 corrections:

```json
{
  "driverId": "<uid>",
  "vehicleId": "FL-101",
  "startTime": "<Timestamp>",
  "endTime": "<Timestamp | null>",
  "status": "active | completed | cancelled",
  "startLat": 37.7749,
  "startLng": -122.4194,
  "endLat": 37.7833,
  "endLng": -122.4167,
  "distanceKm": 48.6,
  "createdAt": "<Timestamp>",
  "updatedAt": "<Timestamp>"
}
```

#### `vehicles/{vehicleId}` and `counters/{name}`

`vehicles`: `{ licensePlate, model, type, status: available|in-use|maintenance, currentOdometerKm, assignedDriverId, createdAt, updatedAt }`.

`counters`: `{ value: 4123 }`, only if D3 option A is approved.

#### `notificationTargets/managers`

```json
{
  "uids": ["<admin uid>", "<dispatcher uid>"],
  "updatedAt": "<Timestamp>"
}
```

### 6.4 Shared timestamp parser (required by PR 0)

`lib/core/firestore_dates.dart` already exists in the working tree:

```dart
DateTime? parseFirestoreDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  if (value is String) return DateTime.tryParse(value);
  try {
    final dynamic converted = (value as dynamic).toDate();
    return converted is DateTime ? converted : null;
  } catch (_) {
    return null;
  }
}
```

Rules:

- `Delivery.fromMap` must use this parser; a missing `createdAt` is `null`, not `DateTime.now()`.
- `DeliveryProof.fromMap`, `AppNotification.fromMap`, and `Trip.fromMap` use it.
- `toMap()` never writes ISO strings to Firestore; services convert `DateTime` to `Timestamp.fromDate`, or models write `Timestamp` directly.
- Unit tests cover `Timestamp`, `int` ms, ISO string, `DateTime`, `null`, invalid string, unsupported object, and legacy `toDate()`.
- The current test file has 9 passing tests; PR 0 must fix the single `prefer_const_constructors` info at `test/core/firestore_dates_test.dart:59`.

### 6.5 Service API v1.1 (canonical signatures)

```dart
// lib/services/auth_service.dart                          (Aasif)
Stream<AppUser?> authStateChanges();
Future<AppUser> signIn({required String email, required String password});
Future<void> signOut();
Future<AppUser> ensureUserDocument(AppUser user);
Future<void> registerDriver({required String email, required String password,
  required String displayName, String? phone});

// lib/services/user_service.dart                          (Aasif)
Stream<List<AppUser>> watchUsersByRole(String role);
Stream<List<AppUser>> watchDrivers();
Future<void> setOnShift(String uid, bool onShift);
Future<void> setFcmToken(String uid, String token);
Future<void> syncManagerTargets(List<String> managerUids); // admin only

// lib/services/vehicle_service.dart                      (Aasif)
Stream<List<Vehicle>> watchVehicles();
Future<String> createVehicle(Vehicle vehicle);
Future<void> updateVehicle(Vehicle vehicle);

// lib/services/delivery_service.dart                     (Thuva owns API)
Stream<List<Delivery>> watchAll({String? status, String? driverId});
Stream<List<Delivery>> watchForDriver(String driverId);
Stream<Delivery?> watchById(String deliveryId);
Future<String> createAndAssign({
  required String createdBy,
  required String driverId,
  required String address,
  required double latitude,
  required double longitude,
  required String recipientName,
  required String recipientPhone,
  required String packageDescription,
  String? vehicleId,
  String pickupAddress = 'Central Logistics Hub, Bay 3',
  String priority = 'standard',
  String? specialInstructions,
  DateTime? eta,
});
Future<void> transition({
  required String deliveryId,
  required String nextStatus,
  required String actorUid,
});
Future<DeliveryProof> submitProof({
  required String deliveryId,
  required File photo,
  required double lat,
  required double lng,
  double? accuracy,
  String? address,
  String? notes,
  String? recipientName,
});
Stream<DeliveryProof?> watchProof(String deliveryId);

// Backward-compatible adapters (one sprint only; do not add new callers)
@Deprecated('Use transition()')
Future<Delivery> updateStatus({required String deliveryId, required String newStatus});

@Deprecated('Use submitProof()')
Future<DeliveryProof> submitProofOfDelivery({
  required String deliveryId,
  File? photoFile,
  Uint8List? photoBytes,
  required Map<String, dynamic> location,
  String? notes,
  String? recipientName,
});

// lib/services/storage_service.dart                      (Baary owns upload)
Future<({String url, String path})> uploadDeliveryProof({
  required String deliveryId,
  required String driverId,
  required File file,
});
Future<void> deleteDeliveryProof(String path); // only valid while delivery is arrived

// lib/services/notification_service.dart                 (Baary)
Future<AppNotification> send({
  required List<String> recipientIds,
  required List<String> recipientRoles,
  required String audience,
  required String title,
  required String message,
  required String type,
  Map<String, dynamic>? metadata,
});
Stream<List<AppNotification>> watchForUser(String uid);
Future<void> markAsRead(String notificationId, String uid);
Stream<List<String>> watchManagerTargets();
Future<void> syncManagerTargets(List<String> managerUids); // admin only

// Backward-compatible adapter (one sprint only)
@Deprecated('Use send()')
Future<AppNotification> sendNotification({
  required String recipientId,
  required String message,
  required String type,
  String? title,
  Map<String, dynamic>? metadata,
});

// lib/services/trip_service.dart                         (Aadhil)
Future<List<Trip>> fetchTrips({String? driverId, String? vehicleId,
  String? status, DateTime? from, DateTime? to, int? limit});
Future<Trip?> getTripById(String id);
Future<void> saveTrip(Trip trip);
Stream<List<Trip>> watchTrips({String? driverId, String? vehicleId,
  String? status, int? limit});

// lib/providers/location_provider.dart                   (Nippuni)
Future<void> startTracking({required String driverId, required String tripId});
Future<void> stopTracking();
Stream<({double lat, double lng, double speedKmh, double accuracy})>
  get locationStream;
```

Compatibility bridge:

| Current API | v1.1 action |
|---|---|
| `AuthProvider.signIn(... roleOverride)` returns `bool` | Keep `bool` for UI, but call `AuthService.signIn`; `roleOverride` only in `DEMO_MODE`; remove email-substring role inference |
| `DeliveryService.updateStatus` | Deprecated wrapper around `transition`; no new callers |
| `DeliveryService.submitProofOfDelivery` | Deprecated wrapper around `submitProof`; no fake URL |
| `StorageService.uploadDeliveryProof` returns `String` | Change to record `({url, path})`; update callers in the same PR |
| `NotificationService.sendNotification` | Deprecated adapter; resolves `recipientId` to a concrete uid; rejects `all_managers` outside demo |
| `TripService.saveTrip` | Keep name; write Timestamps; do not write `id`; use uid |
| `DriverProvider.advanceDeliveryStatus` | Becomes a thin view over `DeliveryService.watchForDriver`; no local status mutation as source of truth |

### 6.6 Specific inconsistencies found and required fixes

| # | Inconsistency | Evidence | Required fix |
|---|---|---|---|
| C1 | `DeliveryStatus.all` omits `cancelled` | `delivery.dart:21-27` | Add `cancelled`; update filters |
| C2 | `Delivery.copyWith` cannot clear nullable fields | `delivery.dart:261-311` | Add explicit `clearProof`, `clearSignature`, `clearCompletedAt` or sentinel-based copy |
| C3 | `Delivery.fromMap` parses `Timestamp` via `toString()` and defaults `createdAt` to now | `delivery.dart:184-228` | Use `parseFirestoreDate`; missing `createdAt` is null |
| C4 | `Delivery.toMap` writes ISO strings and duplicate aliases | `delivery.dart:230-259` | Write canonical fields; service converts DateTime to Timestamp |
| C5 | `DeliveryService.updateStatus` accepts any status and does not write stage timestamps | `delivery_service.dart:130-166` | Validate transition; write stage timestamp; no silent catch |
| C6 | `DeliveryService.submitProofOfDelivery` does not require `arrived` | `delivery_service.dart:173-240` | Require `arrived` + assigned driver + proof batch |
| C7 | `deliveryProof` singular, `photoURL` | `delivery_service.dart:216`, `delivery_proof.dart:4` | `deliveryProofs/{deliveryId}`, `photoUrl`; read aliases only |
| C8 | `all_managers` notification target | `delivery_service.dart:150`, `:228`; `notification_service.dart:36-68` | Resolve role -> uids; `recipientIds`; manager target list |
| C9 | `AppNotification.read` is global | `app_notification.dart:69-143` | `readBy: [uid]`; update service/UI |
| C10 | Notification id uses milliseconds | `notification_service.dart:122` | Firestore auto-id or UUID; no collision |
| C11 | `AppUser.toMap` writes `id` and `uid` | `user.dart:36-44` | Write neither; doc id is uid |
| C12 | `AppUser` lacks role/manager fields from D4 | `user.dart:9-58` | Add optional fields; fromMap defaults |
| C13 | `Trip` on `main` has no serialization | `trip.dart` (17 lines) | H1 replaces it; no one else edits it |
| C14 | History `Trip.toMap` writes ISO strings and `saveTrip` writes `id` | branch `trip.dart`, `trip_service.dart` | H1 fixes; service writes Timestamp; no `id` body |
| C15 | History driver lock matches display name | `history_provider.dart` `_defaultDriverIdFor` | Match `driverId` = uid; display name only in UI |
| C16 | `StorageService` returns fake Unsplash URL on failure | `storage_service.dart:20-57` | Throw typed error; demo URL only behind `DEMO_MODE` and badge |
| C17 | `FirebaseService.initialize` swallows all errors | `firebase_service.dart:4-11` | Surface init failure; health check |
| C18 | Fake auth and `roleOverride` | `auth_provider.dart:28-74` | Real Firebase Auth; demo mode only |
| C19 | Duplicate driver portals / `HomeScreen` second `DriverProvider` | `main.dart:67-77`, `home_screen.dart:106` | Remove `/driver/hub` or gate demo; one provider |
| C20 | Admin status vocabulary `en-route`/`delivered` | `admin_dashboard_screen.dart:733-745` | Use canonical enum |
| C21 | `TripAlertService` creates `all_managers` alerts | branch `trip_alert_service.dart` | Use `send()` with manager recipient IDs |
| C22 | `TripService.firestore()` falls back to local data on query error | branch `trip_service.dart:38-69` | Demo only; production surfaces error |
| C23 | `DeliveryService` seeds are always loaded | `delivery_service.dart:35-106` | Gate behind `AppConfig.demoMode` |
| C24 | `DriverProvider` seeds are always loaded | `driver_provider.dart:155-227` | Gate behind `AppConfig.demoMode` |
| C25 | `NotificationService` doesn't store FCM token on user | `notification_service.dart:79-110` | `setFcmToken(uid, token)`; no server sender yet |
| C26 | `Vehicle.toMap` writes `id`; model lacks `assignedDriverId`/timestamps | `vehicle.dart:34-44` | Remove `id`; add optional fields; doc id is identity |
| C27 | `AppNotification.toMap` writes `notificationId` and singular `recipientId` | `app_notification.dart:109-121` | Write canonical `recipientIds`, `createdBy`, `audience`, `recipientRoles`, `readBy`; no `notificationId` body |
| C28 | FCM foreground message uses `recipientId: 'current_user'` | `notification_service.dart:79-110` | Use the authenticated uid; do not write a pseudo-recipient |
| C29 | `DeliveryService` has no `createAndAssign`, `transition`, `watchForDriver`, or `watchById` | `delivery_service.dart` | PR 2 adds the canonical API |
| C30 | Deploying v1.1 rules against current writers denies valid writes | Sections 2.7 and 4.7 | Deploy only after PR 2/PR 6; use emulator until then |

---

## 7. Correction 6 — Firebase operational status

### 7.1 Repository configuration — verified present

| Item | Verified value | Evidence |
|---|---|---|
| Firebase project id | `fleetflow-dev-29e55` | `android/app/google-services.json` |
| Project number | `337102459948` | same |
| Android package | `com.fleetflow.fleet_flow` | same; `android/app/build.gradle.kts` |
| Storage bucket declared | `fleetflow-dev-29e55.firebasestorage.app` | same |
| google-services plugin | `4.5.0` | `android/settings.gradle.kts` |
| AGP / Kotlin | `9.1.0` / `2.4.0` | `android/settings.gradle.kts` |
| NDK | `28.2.13676358` | `android/app/build.gradle.kts` |
| Firebase SDK constraints | core `^3.6.0`, auth `^5.3.1`, firestore `^5.4.4`, storage `^12.3.2`, messaging `^15.1.3` | `pubspec.yaml:37-45` |
| Firebase SDK resolved | core `3.15.2`, auth `5.7.0`, firestore `5.6.12`, storage `12.4.10`, messaging `15.2.10` | `flutter pub get` output |
| App bootstrap | `Firebase.initializeApp()` wrapped in silent catch | `lib/services/firebase_service.dart` |
| FCM bootstrap | permission + token request | `lib/services/notification_service.dart:79-110` |
| `firebase.json` | Present as an untracked working-tree draft | repository root |
| `firestore.rules` | Present as an untracked working-tree draft | repository root |
| `storage.rules` | Present as an untracked working-tree draft | repository root |
| `firestore.indexes.json` | Present as an untracked working-tree draft | repository root |
| `.firebaserc` | **Absent** | repository root |
| `functions/` / server sender | **Absent** | repository root |

`google-services.json` is tracked in the repository and contains the project API key. Firebase API keys are not equivalent to server secrets, but the repository should not be made public without reviewing that file. `firebase-debug.log` is also present; it is diagnostic noise and should not be committed in PR 0.

### 7.2 Firebase Console state — not verified

**Repository configuration is not proof that Firebase is operational.** This audit could not access the console or an authenticated Firebase CLI. The following are **UNVERIFIED**:

- Email/password Authentication enabled and accounts created.
- Firestore database created; default database; region; rules deployed.
- Storage bucket exists and rules deployed; cross-service Firestore permission enabled for Storage Rules.
- FCM/APNs configured; server key/service account available to a sender.
- Whether the project is still in test mode.
- Whether the Android app registration still matches the package and signing certificate.

### 7.3 Probe evidence (read-only, no credentials)

| Probe | Result (2026-11-15) | Interpretation |
|---|---|---|
| `firebase --version` | `15.30.1` | CLI installed |
| `firebase projects:list` | “Failed to authenticate, have you run `firebase login`?” | No authenticated CLI session |
| `firebase apps:list --project fleetflow-dev-29e55` | same auth error | Cannot verify app registration |
| `gcloud --version` | not installed | No alternate admin path |
| Identity Toolkit `accounts:signInWithPassword` with project API key | HTTP 400 `CONFIGURATION_NOT_FOUND` | Auth may be disabled, the API key may be restricted, or the project config is incomplete — **not conclusive**, but it is not evidence that Auth works |
| Firestore REST default documents | HTTP 404 (empty body) | Database may not be provisioned or the endpoint may reject the probe — **not conclusive** |
| Storage bucket root GET | HTTP 404 | Bucket may not be provisioned or may deny the probe — **not conclusive** |
| Hosted config `__/firebase/init.json` | HTTP 404 | Firebase Hosting not configured or not used — **not conclusive** |
| Rules emulator | Blocked by default JDK 17; with JDK 21 the emulator download timed out | Rules compile/deploy is **not verified** |

No probe proves that Authentication, Firestore, or Storage is operational. The contract therefore treats all three as unverified until the console checklist is completed.

### 7.4 Console verification checklist (Thuva, before rules deployment)

Run after `firebase login` and `firebase use fleetflow-dev-29e55`:

1. **Authentication**
   - [ ] Email/Password provider enabled.
   - [ ] Create `admin@fleetflow.dev`, `dispatcher@fleetflow.dev`, and one `driver@fleetflow.dev` test account.
   - [ ] Create `users/{uid}` documents with the correct role.
   - [ ] Create `notificationTargets/managers` with the admin and dispatcher uids.
2. **Firestore**
   - [ ] Default database exists in the chosen region.
   - [ ] Do not deploy `firestore.rules` yet (Section 2.7).
   - [ ] Confirm `users`, `deliveries`, `deliveryProofs`, `trips`, `notifications`, `vehicles`, `counters`, `notificationTargets` are readable/writable under the rules in the emulator.
3. **Storage**
   - [ ] Bucket `fleetflow-dev-29e55.firebasestorage.app` exists.
   - [ ] Do not deploy `storage.rules` yet.
   - [ ] Enable the Firestore cross-service permission for Storage Rules when ready.
   - [ ] Test a 1 MiB JPEG upload as assigned driver and a 6 MiB upload as a rejection.
   - [ ] Test that the assigned driver can delete an orphan while `arrived`, and cannot delete after `completed`.
4. **Messaging**
   - [ ] FCM enabled for the Android app.
   - [ ] Confirm no server sender exists; state “in-app feed only” in the demo.
5. **Project settings**
   - [ ] Android package still `com.fleetflow.fleet_flow`.
   - [ ] Add SHA-1/SHA-256 if Google Sign-In or phone auth is ever enabled.
6. **Repository**
   - [ ] Review whether `google-services.json` should remain public; do not publish the repo without a decision.
   - [ ] Do not deploy rules from this contract task; deploy only after approval and after PR 2/PR 6.

If any box cannot be checked, mark the corresponding item in Section 9 as blocked rather than claiming the service works.

### 7.5 Deployment gate

The rules in Sections 2 and 4 are stricter than the current app writers. Deploying them before the matching service PRs will break the app. The safe sequence is:

1. PR 0: commit rules as drafts; run emulator tests.
2. PR 2: delivery service writes exact fields and timestamps.
3. PR 6: notification service writes the v1.1 schema and manager target list.
4. PR 9: deploy rules to the real project and run the Target-1 acceptance test.

Until step 4, the real project should keep its existing rules, or no rules changes at all.

---

## 8. Decisions that can be approved now

| ID | Decision | Why it is safe to approve | Owner |
|---|---|---|---|
| A1 | Persisted status enum: `assigned`, `picked_up`, `in_transit`, `arrived`, `completed`, `cancelled` | Matches the shipped state machine; only `all`, docs, and admin vocabulary need correction | Thuva |
| A2 | `deliveryProofs/{deliveryId}` (plural, idempotent) with `photoUrl` and `storagePath` | Existing code is already close; removes duplicate collection/field drift | Thuva/Baary |
| A3 | `DEL-####` doc id with `counters/deliveries` transaction | Keeps customer tracking and existing UI working; rule can bound increment | Thuva |
| A4 | `driverId` = Firebase uid in all canonical collections | Required for rules; display names resolved via `users` | Aasif/Thuva |
| A5 | Firestore `Timestamp` at rest + one shared parser | Fixes real data corruption; testable in isolation | Thuva |
| A6 | Driver ownership + exact transition + proof existence enforced in rules; managers cannot bypass proof | Removes client-only validation; rules draft is ready | Thuva |
| A7 | Storage path `proofs/{deliveryId}/{epochMillis}.jpg`; 5 MiB; JPEG/PNG/WebP; narrow orphan delete | Matches D6/D7; rules use Firestore ownership | Baary/Thuva |
| A8 | Notification targeting by concrete uid; `all_managers` retired; `readBy` per user; `notificationTargets/managers` restricts driver-created alerts | Fixes arbitrary manager-alert fabrication and global read state | Baary/Thuva |
| A9 | Demo mode via `--dart-define=DEMO_MODE=true`, visible banner, no fake success | Keeps tests/demo usable without weakening production | All |
| A10 | Hard block `arrived -> completed` without proof; UI returns after warning | Correctness and security requirement | Gajanan/Thuva |
| A11 | Split `feature/member4-history` into H1/H2/H3 tested PRs | Branch is conflict-free now but will rot; slices reduce shared-file risk | Aadhil/Thuva |
| A12 | Driver-created manager alerts use fixed message templates and the manager target document; no free-text manager-facing prose | Rules cannot verify free text; templates reduce fabrication risk without a backend | Baary/Thuva |

---

## 9. Unresolved decisions requiring team input

| ID | Question | Options | Recommendation / owner |
|---|---|---|---|
| U1 | Manager target list maintenance | (a) admin updates `notificationTargets/managers` whenever managers change (recommended); (b) backend function maintains it; (c) per-user inbox subcollections | (a) for MVP; Aasif + Thuva confirm before PR 1 |
| U2 | Delivery ID authority | (a) client transaction on `counters` (recommended); (b) server/Cloud Function; (c) random auto-id + `code` | (a) for MVP; Thuva |
| U3 | Cancellation authority | (a) manager only (recommended); (b) driver emergency cancel + manager review; (c) both | (a) for rules clarity; Gajanan + Thuva |
| U4 | `driverId` migration/demo mapping | (a) create real Auth users for samples; (b) keep names only in demo seed (recommended); (c) dual `driverId`/`driverName` | (b) demo only; Aasif + Aadhil |
| U5 | Proof collection migration | (a) one-time script `deliveryProof` -> `deliveryProofs` (recommended); (b) dual-read only; (c) drop old data | (a) after approval; Thuva |
| U6 | Storage cross-service IAM / bucket existence | (a) enable Firestore access for Storage Rules (recommended); (b) fallback uid path; (c) backend-only upload | Verify console first; Thuva |
| U7 | FCM server sender | (a) in-app only for demo (recommended); (b) Blaze Cloud Function; (c) external sender | (a) for Target 1; Baary + Thuva |
| U8 | Manager seeding and custom claims | (a) console/Admin SDK `users` docs only (recommended); (b) add custom claims `role`; (c) both | (a) for MVP; (b) if Storage manager read needs it; Aasif |
| U9 | History branch timing vs other PRs | (a) H1/H2 after PR 0/2, H3 last (recommended); (b) merge whole branch now | (a); Aadhil + Thuva |
| U10 | User directory privacy | (a) managers read `users`; drivers read only self and `notificationTargets/managers` (recommended); (b) separate `directory/{uid}`; (c) backend lookup | (a) is sufficient because drivers no longer need the full user list; Thuva |
| U11 | iOS HEIC support | (a) convert to JPEG client-side (recommended); (b) allow HEIC types; (c) reject | (a) for Android-first MVP; Baary |
| U12 | Manager completion override | (a) managers follow the same proof rule (recommended and implemented in the draft); (b) managers may override with an audit reason | (a) unless dispatcher workflow requires override; Gajanan + Thuva |

---

## 10. Exact implementation responsibilities

| Member | Owns | Must implement | Must not touch | Depends on |
|---|---|---|---|---|
| **Aasif** (M1) | Auth, users, vehicles, manager target list | `lib/services/auth_service.dart`, `user_service.dart`, `vehicle_service.dart`; rewrite `auth_provider.dart` to use Firebase Auth; extend `AppUser` (`phone`, `activeVehicleId`, `onShift`, timestamps); remove email-substring roles; seed manager accounts and `notificationTargets/managers`; wire admin driver/vehicle CRUD to services; tests | `delivery.dart`, `delivery_service.dart`, `trip.dart`, rules | PR 0; A4, A8, U1 |
| **Gajanan** (M2) | Driver UI, assignment UI | Refactor `driver_provider.dart` to stream `DeliveryService.watchForDriver(uid)`; delete/gate seeds; fix proof guard to `return`; wire `DeliveryDetailScreen` to `transition`/`submitProof`; implement manager New Delivery + driver picker in `admin_dashboard_screen.dart`; update status vocabulary; tests | Rules, Storage, notifications, trip model | PR 0, PR 1, PR 2; A10 |
| **Nippuni** (M3) | GPS, trips, telematics | `location_provider.dart`/`trip_provider.dart`; start/stop active shift; GPS stream into `MapInsertionPoint`; telematics into `SafetyTelematicsInsertionPoint`; write trips via `TripService` with uid/Timestamps; route wiring | `delivery_service.dart`, `delivery.dart`, history screens | PR 0, PR 2, H1 |
| **Aadhil** (M4) | History data + UI | Rebase H1/H2/H3 from `main`; fix `Trip.toMap`/`TripService` to Timestamps and no `id`; uid driver lock; split history screens from shared-file edits; remove duplicate rules draft from handoff; fix dropdown test warning; tests | `delivery.dart`, `delivery_service.dart`, proof/notification services | PR 0, PR 2, H1/H2 |
| **Baary** (M5) | Proof, Storage, notifications | `storage_service.dart` path/metadata/record return; remove fake URL; narrow delete; `notification_service.dart` `send` + `watchForUser` + `readBy` + manager target list + fixed templates; `notification_provider.dart`; `camera_pod_insertion_point.dart` real upload; `proof_of_delivery_screen.dart` real service; customer tracking read path; FCM token only | `delivery.dart` transition rules, auth roles, trip model | PR 0, PR 2, PR 6; A7, A8, A12 |
| **Thuva** (M6) | Contract, rules, repository, QA | `docs/BACKEND_CONTRACT.md`; `lib/core/firestore_dates.dart`; `lib/core/app_config.dart`; `firebase.json`; `firestore.rules`; `storage.rules`; `firestore.indexes.json`; `delivery_service.dart` API/transitions/proof batch/counters; `Delivery` timestamp/copy fixes; CI; console verification; PR reviews; integration QA | Member UI screens (except contract-approved API changes) | — |

Shared-file rule: the listed owner opens the PR; a second member reviews; the owner merges only after `flutter analyze`, `flutter test`, and (for rules) the rules tests are green.

---

## 11. Safe GitHub PR and merge order

### 11.1 PR sequence

| Order | Branch | Owner | Contents | Reviewers | Gate |
|---:|---|---|---|---|---|
| 0 | `chore/backend-contract-v1.1` | Thuva | This doc, `AppConfig`, date parser + tests, `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json` | Aasif + Baary | `flutter analyze`; `flutter test`; emulator rules load; no app screens/providers touched |
| 1 | `feature/real-auth` | Aasif | Auth/User/Vehicle services; AuthProvider; AppUser fields; manager seeding + `notificationTargets/managers` | Thuva + Gajanan | Auth unit tests; role boundary tests; no fake login |
| 2 | `feature/delivery-repository` | Thuva | `Delivery` timestamp/copy fixes; `DeliveryService` watch/create/transition/proof/counters; adapters | Gajanan + Baary | Service tests; transition matrix; timestamp tests |
| 3 | `feature/history-data-layer` (H1) | Aadhil | Trip model/service/alert + tests; no UI/shared files | Thuva | `flutter test test/trip_history_test.dart test/trip_alert_test.dart` |
| 4 | `feature/driver-integration` | Gajanan | DriverProvider stream; proof guard; manager assignment UI | Aasif + Baary | Driver flow tests; no seeds in non-demo |
| 5 | `feature/history-provider` (H2) | Aadhil | HistoryProvider/formatters/widgets + tests | Thuva | Provider/screen tests |
| 6 | `feature/proof-notifications` | Baary | StorageService, NotificationService, proof screen, camera insertion, customer tracking | Thuva + Gajanan | Upload/notification tests; no fake URL |
| 7 | `feature/maps-gps` | Nippuni | Location/Trip providers, map/telematics insertion, route | Gajanan + Aadhil | GPS unit tests; no delivery-service writes |
| 8 | `feature/history-screens` (H3) | Aadhil | History screens, admin tab, driver button, `/history` route, handoff cleanup | Gajanan + Thuva | Full `flutter test`; fix dropdown warning |
| 9 | `qa/target-1-integration` | Thuva | Integration fixes, rules/index deployment verification, health check, demo script | All | Target-1 acceptance test (Section 13) |

### 11.2 Rules

1. `main` stays protected; no direct pushes.
2. Rebase feature branches on `main` before opening/updating a PR; do not force-push a branch another member is reviewing without announcing it.
3. One approving review from a different member; the owner merges.
4. Green `flutter analyze` and `flutter test` required. Rules PRs also require `firebase emulators:exec --only firestore,storage` (or a documented console rules-playground result).
5. Never merge the whole `feature/member4-history` branch. Cherry-pick/rebase H1/H2/H3.
6. No one edits `firestore.rules`, `storage.rules`, `firestore.indexes.json`, or `docs/BACKEND_CONTRACT.md` outside a Thuva-reviewed PR.
7. Do not deploy rules from a feature PR. Deployment happens only after PR 0 approval, after PR 2/PR 6, and only by Thuva.
8. Delete branches after merge; do not reuse merged feature branches.
9. Do not include `analysis_options.yaml` or `firebase-debug.log` in PR 0 unless the team explicitly approves that change.

---

## 12. First implementation task for Thuva

### 12.1 Task: PR 0 — Contract foundation (no app features)

Branch: `chore/backend-contract-v1.1`

The working tree already contains drafts. Thuva’s first task is to reconcile them with this contract, not to start from zero:

- `docs/BACKEND_CONTRACT.md` (this document)
- `lib/core/firestore_dates.dart` (`parseFirestoreDate`)
- `lib/core/app_config.dart` (`demoMode` from `--dart-define=DEMO_MODE`)
- `test/core/firestore_dates_test.dart`
- `firebase.json`
- `firestore.rules`
- `storage.rules`
- `firestore.indexes.json`

Required delta before PR 0:

1. Add the `notificationTargets/managers` rule and document shape.
2. Add the narrow Storage delete rule for orphan cleanup.
3. Fix the `prefer_const_constructors` info at `test/core/firestore_dates_test.dart:59`.
4. Confirm `firestore.indexes.json` includes the `notifications(recipientIds, timestamp)` index.
5. Do not change screens, providers, `delivery_service.dart`, models, or `pubspec.yaml` in PR 0.
6. Do not deploy.

### 12.2 Acceptance tests

| # | Test | Expected |
|---|---|---|
| 0.1 | `flutter analyze` | No errors; 23 pre-existing info deprecations only; the new test lint is fixed |
| 0.2 | `flutter test` | All 33 current tests pass |
| 0.3 | `flutter test test/core/firestore_dates_test.dart` | 9 tests pass for `Timestamp`, `int` ms, ISO `String`, `DateTime`, `null`, invalid `String`, unsupported object, legacy `toDate()` |
| 0.4 | `firebase emulators:exec --only firestore,storage "echo rules-loaded"` with `JAVA_HOME` set to JDK 21 | Rules compile and emulators start; no syntax errors. If the emulator download is blocked, mark this **BLOCKED**, not passed |
| 0.5 | Rules matrix: driver A updates driver B’s delivery | Denied |
| 0.6 | Rules matrix: `assigned -> completed` | Denied |
| 0.7 | Rules matrix: `arrived -> completed` with no proof doc | Denied |
| 0.8 | Rules matrix: batch creates valid proof + completes delivery | Allowed |
| 0.9 | Rules matrix: driver writes `cancelled` | Denied; manager allowed with non-empty reason |
| 0.10 | Rules matrix: manager tries `arrived -> completed` without proof | Denied |
| 0.11 | Rules matrix: non-assigned driver Storage upload | Denied |
| 0.12 | Rules matrix: assigned driver uploads 6 MiB or `text/plain` | Denied |
| 0.13 | Rules matrix: assigned driver uploads valid 1 MiB JPEG while `arrived` | Allowed |
| 0.14 | Rules matrix: assigned driver deletes orphan while `arrived` | Allowed; after `completed` denied |
| 0.15 | Rules matrix: driver sends `assignment` notification to another driver | Denied |
| 0.16 | Rules matrix: driver sends `status_change` for own delivery to the manager target list | Allowed |
| 0.17 | Rules matrix: driver sends `status_change` with arbitrary recipient IDs | Denied |
| 0.18 | Rules matrix: driver sends `status_change` for another driver’s delivery | Denied |
| 0.19 | Rules matrix: manager sends `assignment` to a driver | Allowed |
| 0.20 | Rules matrix: non-admin writes `notificationTargets/managers` | Denied |
| 0.21 | Rules matrix: recipient marks notification read | `readBy` only; other recipients unaffected |
| 0.22 | `git diff --stat` for PR 0 | Only docs/core/rules/config/test files; no `lib/screens`, `lib/providers`, `lib/services`, `lib/models`, `analysis_options.yaml`, or `firebase-debug.log` |
| 0.23 | `git status` after tests | Clean except intended PR 0 files; no secrets or generated files |

### 12.3 Definition of done for PR 0

- PR 0 is approved and merged.
- The rules/indexes are committed but **not deployed** until the console check in Section 7.4 is complete and PR 2/PR 6 have landed.
- A short PR description lists the exact unresolved items (Section 9) that block PR 2/4/6.
- No application feature behavior has changed.

---

## 13. Target-1 acceptance test (unchanged, now enforceable)

1. Manager logs in with a real Firebase `admin` account; creates `DEL-####` and assigns a driver uid. Doc has `status: assigned`, `driverId`, `assignedAt`.
2. Driver logs in on a second emulator/device; delivery appears via real-time stream without restart.
3. Driver advances `assigned -> picked_up -> in_transit -> arrived`; each stage timestamp persists and is visible to the manager live.
4. Driver taps Complete at `arrived` without proof -> **denied by the UI and by the rules**; no status change.
5. Driver captures a real camera photo -> Storage object exists at `proofs/{deliveryId}/...`; proof doc exists; delivery `completed`; `proofPhotoUrl` and `completedAt` set.
6. Manager sees Completed + proof image; customer tracking by id shows completed.
7. Force-close and relaunch both apps -> state identical (persistence, not memory).
8. Disable Wi-Fi mid-transition -> visible error, no fake success.
9. A second driver account cannot read or transition the first driver’s delivery (direct REST/SDK attempt).
10. A driver cannot create a notification for another driver, an `assignment` alert, or a manager alert with arbitrary recipient IDs.
11. A manager reading a notification does not mark it read for other managers.
12. A failed proof batch leaves no fake success; the orphan object can be cleaned only while the delivery is still `arrived`.

---

## 14. Code and repository state statement

- No application source file was modified by this contract task.
- No branch was merged.
- No commit, push, or deployment was performed.
- `flutter test` and `flutter analyze` were run read-only for evidence.
- `flutter test` on the current branch: 33 passed.
- `flutter analyze` on the current branch: 24 info issues (23 pre-existing + 1 new test lint); no errors.
- `origin/feature/member4-history` was tested in a detached temporary worktree: 71 tests passed, 23 pre-existing info issues, one non-fatal dropdown warning at `test/manager_history_test.dart:81`. The worktree was removed afterward.
- The Firebase rules emulator was attempted. The default JDK 17 is below the CLI requirement; with JDK 21 selected, the emulator download did not complete within the audit timeout. Rules compile/deploy remains **unverified**.
- Firebase Authentication, Firestore, and Storage are **configured in the repository** but **not verified as operational** in the Firebase Console.
- The only file produced by this task is `docs/BACKEND_CONTRACT.md`.
- The working tree already contained untracked PR 0 drafts and a pre-existing `analysis_options.yaml` change before this task. They are reported in Section 1.3 and are not approved by this document.

---

## 15. Approval

Section 8 (A1–A12) is **recommended** for approval on 2026-11-15. Section 9 (U1–U12) remains tracked for team assignment. PR 0 may proceed with the recommended defaults for rule drafts only after the team accepts this document. Unresolved choices must be settled before PR 2/PR 4/PR 6. No one merges a feature branch before PR 0 lands. No rules are deployed before PR 2/PR 6 and the console check.

**BACKEND CONTRACT V1.1 READY FOR APPROVAL.**
