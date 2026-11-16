# Task 16: private Supabase proof integration

Feature owner: Baary (M5). Integration/security owner: Thuva (M6).
Implemented by Codex under Thuva's direction. Existing teammate commits are preserved.
Branch: `feature/member5-supabase-proof`. This branch includes the unmerged QA foundation from PR #15; review that dependency too.

## Verified hosted configuration

On 2026-11-16, the signed-in Supabase dashboard showed project `fleetflow-proof-storage` (`geyjgeelwwbmhzwqtbbr`), Free plan, Sydney, healthy. Bucket `delivery-proofs` already existed: PRIVATE, 5 MB maximum, MIME allowlist JPEG/PNG/WebP, empty, zero existing policies. Firebase third-party authentication was already enabled for `fleetflow-dev-29e55`. These settings were inspected, not changed. Firebase billing was not changed.

Three live anonymous checks pass: upload/read denial and empty object listing. An empty listing on an empty bucket does not prove authenticated driver upload or manager viewing. Those require deployment, credentials and real test accounts below.

## Implemented behavior

Flutter initializes Supabase after Firebase. Only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` are client configuration; no service-role or Firebase Admin key belongs in Flutter. Firebase ID tokens supply Supabase authorization. The token bridge requires an explicitly provisioned `role=authenticated` custom claim; Firestore `users/{uid}.role` remains the authoritative application role. Existing custom claims are preserved by the provisioning script.

The camera/gallery flow retains cancellation, preview, retake, recipient and notes. Both the client and trusted broker decode actual JPEG, PNG or WebP content, reject empty/truncated/mislabeled content, cap files at 5,000,000 bytes, dimensions at 4096 and decoded pixels at 4,000,000. The camera requests at most 1600 by 1600. Optional capture coordinates are untrusted metadata; missing GPS stays empty. No fabricated location or background tracking is introduced.

`begin` verifies the Firebase signature, project, expiry, token issuance, revocation/disabled account and fresh Firestore driver role, assignment and arrived state. A transaction creates a 15-minute intent and a per-delivery lock before a service-only SQL RPC issues a path-specific grant. Paths are `{firebaseUid}/{deliveryId}/{uuid-v4}.{jpg|png|webp}`. The grant binds the owner, path, MIME, size and SHA-256. Storage INSERT requires the exact grant. Direct client object SELECT/UPDATE/DELETE and proof/grant/lock writes are denied. Restrictive policies also resist unrelated permissive Storage policies.

The client uploads immutable bytes (`upsert=false`), then calls `complete`. Duplicate-object responses never mean success: the broker downloads and decodes the real object, verifies digest/size/MIME and closes its upload grant. A Firestore transaction rechecks role, assignment, arrived state, expiry and lock, then atomically writes verified evidence, completed status and an authorized manager alert. No client can complete deliveries directly. Manager alert targets come from the server-provisioned `notificationTargets/managers` and each target role is checked again. This is an in-app Firestore alert; trusted FCM push sending remains outside this change.

`view` checks current authoritative manager/dispatcher or assigned-driver access and returns a 60-second signed URL. URLs stay in widget memory and are refreshed after failure; they are never persisted to Firestore. Legacy public proof URLs are not rendered as trusted evidence.

## Consistency and reconciliation

Firestore and Storage do not share a transaction. Intents are durable before upload access. Same-photo retries reuse the lock/intent, including after app restart, grant-write failure, upload response loss and Firestore commit failure. A different photo requires discarding the pending attempt. Existing verified evidence cannot be replaced or removed.

Invalid image cleanup claims an intent transactionally before closing the grant/removing only that pending object. Completion and cleanup contend on the same intent/lock, preventing cleanup from deleting a valid committed proof. Removal failures retain cleanup state for retry. Admin-only `reconcile` processes at most 20 attempts per page, returns `nextCursor`, and repeats cleaned intents to catch late orphan uploads. Continue all pages and restart from the first page on subsequent sweeps. No scheduler is deployed; an approved operator must invoke periodic reconciliation. Retention/archiving of old intent records needs an operational policy before long-term scale.

## Review-gated deployment runbook

The SQL migration, broker, Firebase claim changes and Firestore rules in this PR ARE NOT DEPLOYED. The v1.2 contract addendum requires explicit acceptance. Another team member must approve the PR under CONTRIBUTING.md. Security deployment requires separate release approval.

After review/approval, an authorized operator must:

1. Install tools: `npm ci --prefix supabase/tooling`. Authenticate the Supabase CLI through its supported local login flow; never paste tokens in chat. The installed CLI is v3; use `supabase/tooling/node_modules/.bin/supabase.cmd` on Windows. All remote commands below target only `geyjgeelwwbmhzwqtbbr`.
2. Create/use a dedicated Firebase broker service account with the reviewed Firestore read/write and Firebase Authentication account-read permissions, and supply its JSON ONLY through Supabase's server secrets manager (`FIREBASE_SERVICE_ACCOUNT_JSON`). Keep the credential outside this repository. Runtime `SUPABASE_SERVICE_ROLE_KEY` is server-only. Review rotation, account revocation and IAM scope; do not ship an Owner/Editor credential. Configure `APP_ALLOWED_ORIGINS` only for approved web origins; native Android requests have no Origin.
3. Preview migrations: `supabase db push --remote=geyjgeelwwbmhzwqtbbr --dry-run --skip-vault`. Inspect the exact migration before the approved apply: `supabase db push --remote=geyjgeelwwbmhzwqtbbr --skip-vault`. Alternatively, execute the reviewed SQL transaction in SQL Editor. Confirm private bucket limits and restrictive policies on the hosted Storage schema. PGlite tests do not substitute for this check.
4. Deploy only `proof-broker`: `supabase functions deploy proof-broker --remote=geyjgeelwwbmhzwqtbbr --use-api --no-verify-jwt`. The legacy gateway check is disabled because the function explicitly verifies Google-signed Firebase JWTs, revocation and roles. Never remove that verification. Verify hosted WASM asset packaging and real image decoding before enabling clients.
5. Deploy the tested Firestore rules/indexes through the separately approved Firebase release step. Current live Firebase rules were not inspected or changed during Task 16. Do not infer they match this branch.
6. Provision ONLY approved real account UIDs using ADC outside the repo: `node supabase/scripts/provision-firebase-claims.mjs --uid FIREBASE_UID` (dry-run); use `--apply` only after authorization. Existing `role` claim conflicts fail rather than overwrite. Re-sign in/refresh ID tokens. Provision canonical `users/{uid}` and manager notification targets through the approved backend process.
7. Build with a local ignored JSON containing public defines: `flutter build apk --release --dart-define-from-file=.env.supabase.public.json`. The local review APK uses this project's verified URL/public key. It will show real service failures until the backend is deployed. Builds without defines keep completion disabled. No secret key is needed by the APK.
8. Set real test Firebase ID tokens in process environment via a secure local mechanism (do not log or commit them), then enable `RUN_LIVE_PROOF_TESTS=true` and run `npm --prefix supabase/tooling run test:backend`. The opt-in live test uses `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `FIREBASE_MANAGER_ID_TOKEN`, `FIREBASE_DRIVER_ID_TOKEN`; check the test source for exact names before running. It creates an immutable QA delivery/proof and tests assignment, stages, real private upload, verification, duplicate completion, Firestore records and manager image bytes. Complete the manual Android camera/GPS/login/error checklist too.

## Tests and limitations

- Flutter service/model/widget tests cover token claims, real decoders, invalid images, upload/verification failures and retry, duplicate prevention, persisted completion checks and camera cancellation/preview/retake.
- Deno tests cover signed Firebase JWT verification, disabled/revoked accounts, ownership/stages, real WASM JPEG/PNG/WebP decoding, idempotency, races, failed commits, safe cleanup, reconciliation, manager viewing and HTTP boundaries.
- PGlite executes the actual migration and PostgreSQL RLS against anonymous/authenticated/service roles, including a hostile broad permissive legacy policy. It emulates auth.jwt/storage tables, not the hosted Storage HTTP service.
- Firebase emulator tests enforce client boundaries. A separate test uses the actual Firestore REST adapter and emulator transactions/server timestamps, with fake object storage. The adapter uses the documented batchGet transaction request to avoid the emulator GET BYTE_STRING parser issue.
- Provisioning script tests preserve unrelated claims and enforce explicit UID/authoritative role/dry-run.
- The real full cross-provider workflow is opt-in and BLOCKED until deployment/Admin access/account provisioning. Mocks and local emulators are not counted as live success.
- No Android hardware is connected. Emulator/device camera, GPS, real account flow and actual notification delivery remain unverified. Release currently uses the existing Android debug signing configuration; it is a review APK, not store-ready signing.

## Source references

- [Supabase Firebase third-party authentication](https://supabase.com/docs/guides/auth/third-party/firebase-auth)
- [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control)
- [Supabase Edge image processing example](https://supabase.com/docs/guides/functions/examples/image-manipulation)
- [Firestore transactional batchGet](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/batchGet)
