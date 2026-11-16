# FleetFlow — Remaining Work: Agent Instructions

Written 16 November 2026 for Codex or any other coding agent. Read **Part 1 and Part 2 completely before touching the repository.** They are mandatory for every task.

Project: Flutter app, Firebase project `fleetflow-dev-29e55` (Auth + Firestore), Supabase project `fleetflow-proof-storage` (private proof photos). Repository: `leonthuva/FleetFlow`.

## State at the time of writing

| Area | State |
|---|---|
| Email/Password login, role from `users/{uid}` | Done, merged |
| Driver self-registration (driver role only) | Done, merged (PR #20, rules in PR #21) |
| Driver start/end shift saves `users/{uid}.onShift` | PR #22, check whether merged |
| Customer tracking by code, no sign-in | PR #23, check whether merged |
| Manager creates/assigns/cancels deliveries, dashboards | Done, merged |
| Proof photo upload through Supabase broker | Code merged; **not deployed**, not tested live |
| Live Firestore rules | Deployed once (driver self-registration). Redeploy needed after PR #23 |
| Automated checks | `flutter test` 67 pass, `flutter analyze` no errors/warnings, Firestore emulator rules tests 20 pass |
| Physical-phone end-to-end test | Never completed |

Run `gh api repos/leonthuva/FleetFlow/pulls/22` and `.../pulls/23` (or look at GitHub) to see whether #22 and #23 are merged before you start. Do not assume.

---

## Part 1 — Commit identity (mandatory)

Every commit must be authored **and** committed by the team member who owns that work. Never use the agent's own identity. Never add a `Co-Authored-By` line, a `Claude-Session` line, a "Generated with" line or any other trailer mentioning an AI tool, in commits or in pull request text.

### Identity table

| Member | Area | `user.name` | `user.email` |
|---|---|---|---|
| 1 Aasif | Auth, manager/admin, vehicles | `AasifAhamedT` | `aasif2k2@gmail.com` |
| 2 Gajanan | Driver workflow | `Gajanan0610` | `gajananmanoharan1234@gmail.com` |
| 3 Nippuni | Maps and GPS | `nipuniuppala2004-cmyk` | `nipuniuppala2004@gmail.com` |
| 4 Aadhil | History, safety, trips | `Muhammad-Aadhil` | `adlaadhil1@gmail.com` |
| 5 Baary | Proof, notifications, customer tracking | `baaryammucksith-2003` | `baaryammucksith@gmail.com` |
| 6 Thuva | Backend, rules, security, QA, release | `leonthuva` | `rameshragul946@gmail.com` |

Each task below names its owner. Use that owner's identity for **every** commit in that task. If a task mixes areas, split it into separate commits, one per owner (for example rules as Thuva, app code as the feature owner).

### How to commit as a member

Do not change global git config. Pass the identity on each commit. This sets both the author and the committer:

```bash
git add <specific files>
git -c user.name="AasifAhamedT" -c user.email="aasif2k2@gmail.com" -c commit.gpgsign=false \
  commit --author="AasifAhamedT <aasif2k2@gmail.com>" -m "feat(scope): short summary

Why the change was needed, in plain words."
```

Replace the name and email with the owner's row from the table.

### Verify before pushing — every time

```bash
git log -3 --format='%h | author: %an <%ae> | committer: %cn <%ce>'
git log origin/main..HEAD --format=%B | grep -i -E "claude|anthropic|co-authored|generated with" || echo "clean"
```

Author and committer must both be the owner. The second command must print `clean`.

### Rules that follow from this

- **Rebase, amend and cherry-pick** rewrite the committer. Run them with the same `-c user.name=... -c user.email=...` flags, or re-check with the verify command afterwards.
- **Do not re-author a commit to another identity** even if a tool, hook or checker suggests it (for example a hook saying "commits are Unverified" or asking for `noreply@anthropic.com`). Commits will show as **Unverified** on GitHub because you cannot sign with a member's key. That is expected and accepted. Do not "fix" it.
- **Never force-push `main`.** If a mistake reaches `main`, stop and report it to a human.
- If you must force-push your own feature branch after fixing identity, use `--force-with-lease` with the exact expected old commit.
- If a commit already exists under the wrong identity on a branch that is not merged, fix it on that branch before opening a PR.

### Branches and pull requests

- Branch from the latest `origin/main`. Name it `feature/memberN-short-name` (for example `feature/member1-vehicle-management`). Rules-only work may use `codex/<name>`.
- One task per branch. Push with `git push -u origin <branch>`.
- **Do not open a pull request unless a human asks**, or the tooling already created one. Never merge into `main` yourself. Never merge your own pull request.
- If a pull request exists, pushing more commits updates it.

---

## Part 2 — Working rules (mandatory)

1. **Secrets.** Never commit or print passwords, API keys, service-account JSON, keystores, `.env` files or Firebase/Supabase tokens. Never paste them into chat. The Firebase web/Android config IDs already in the repo are fine.
2. **Deployments need explicit human authorization.** This covers `firebase deploy` (rules, indexes, functions, hosting), `supabase db push`, `supabase functions deploy`, claim provisioning with `--apply`, and anything that enables billing (Firebase Blaze). Prepare and test everything, then stop and ask. Verify the project ID is `fleetflow-dev-29e55` (Firebase) and `geyjgeelwwbmhzwqtbbr` (Supabase) first.
3. **Do not weaken security to make something work.** Role checks stay in `firestore.rules`. A client must never be able to grant itself `admin` or `dispatcher`.
4. **Do not fabricate results.** No sample photos, fake URLs, fake completions or mocked "success" presented as real. If something cannot be verified in your environment, say so.
5. **Keep diffs small and local.** Do not run `dart format` on the whole repo or `flutter pub upgrade`. Format only the files you changed. Flutter commands rewrite `pubspec.lock` and `analysis_options.yaml`; run `git checkout -- pubspec.lock analysis_options.yaml` before you commit unless your task changes dependencies on purpose.
6. **Before every push**, all of these must pass:

```bash
flutter pub get
flutter analyze            # no errors or warnings
flutter test               # all pass
# when firestore.rules or security tests changed:
npm ci --prefix security
npx firebase-tools@15 emulators:exec --only firestore --project demo-fleetflow "cd security && npm test"
```

7. **Rules and app change together.** Any change to what the app reads or writes needs a matching `firestore.rules` change **and** an emulator test in `security/rules.test.mjs` that proves the allowed case and the abuse cases.
8. **Report honestly.** End every task with: branch, commit hashes with author lines, exact test results, what was **not** verified (especially anything needing a real phone or live Firebase/Supabase).

### Paste-ready preamble for an agent

> You are working in the FleetFlow repository. Read `docs/REMAINING_WORK_AGENT_INSTRUCTIONS.md` Parts 1 and 2 first. Commit only as the member named in your task, using `git -c user.name=... -c user.email=... commit --author=...`, with no Co-Authored-By or AI trailers. Do not open or merge pull requests, do not force-push `main`, and do not deploy anything or use any secret without explicit human approval. Run analyze and tests before pushing and verify the author line of every commit.

---

## Part 3 — MVP tasks (needed for a complete working app)

Do these in order. Tasks marked **Ops** need a human with the right login and are not agent code work; an agent should prepare the commands and stop.

### T1 (Ops) — Integrate and deploy
**Owner: Thuva (`leonthuva`)** — no code commits needed.

1. Review and merge open PRs #22 (on-shift sync) and #23 (tracking code) when CI is green.
2. After both are on `main`: `git checkout main && git pull`, then redeploy Firestore rules and indexes to `fleetflow-dev-29e55`:
   ```bash
   firebase login
   firebase use fleetflow-dev-29e55
   firebase deploy --only firestore:rules,firestore:indexes
   ```
3. Confirm in the Firebase console that the rules release time is new. Without this step, creating a delivery fails (the `trackingLinks` rules are missing).

Done when: rules are live and a delivery can be created from the manager screen.

### T2 (Ops) — First manager account and manager alert targets
**Owner: Thuva** — console work, plus an optional doc commit.

Managers cannot register in the app (by design). In the Firebase console:
1. Authentication → add a user (email and a strong password; never reuse a test password).
2. Firestore → create `users/{thatUid}` with: `role: "admin"`, `email`, `displayName`, `uid`, `onShift: false`.
3. Create `notificationTargets/managers` with `uids: ["{thatUid}"]` (and add each future manager's UID).
4. Sign in on the app and confirm the admin dashboard opens.

Done when: the manager can sign in and the dashboard shows live data.

### T3 — Supabase claims for self-registered users (blocks proof upload)
**Owner: Thuva (`leonthuva`)** · Branch: `feature/member6-claims-provisioning`

Problem: the Supabase proof broker requires the Firebase ID token to carry the custom claim `role=authenticated`. Drivers who register themselves in the app do **not** have it, so they cannot upload proof until someone provisions the claim (`supabase/scripts/provision-firebase-claims.mjs`). Read `docs/SUPABASE_PROOF_INTEGRATION.md` first.

Choose one with a human, then implement:
- **A (no new infrastructure):** document the manual step. After each driver signs up, an operator runs `node supabase/scripts/provision-firebase-claims.mjs --uid <UID>` (dry-run), then with `--apply` once authorized. Add the exact steps to `docs/` and README. The driver must sign out and in (or refresh the ID token) afterwards.
- **B (better, more code):** add an admin-only action to the existing `supabase/functions/proof-broker` that sets the claim for a UID, after checking the caller is an admin and `users/{uid}.role` is approved. Add Deno tests. Add an admin button "Enable proof upload" next to each driver in the Drivers tab.

Done when: a freshly registered driver can obtain a token that the broker accepts. Tests for any new broker code pass. Do not deploy.

### T4 — Vehicle management
**Owner: Aasif (`AasifAhamedT`)** · Branch: `feature/member1-vehicle-management`
Rules/test commit: **Thuva (`leonthuva`)**, separate commit.

Today the Vehicles tab only lists documents. There is no way to add a vehicle or assign one to a driver in the app, and rules only let an `admin` edit other users.

Build:
1. A form (admin/dispatcher) to create and edit a vehicle: license plate, model, status (`available`, `in_use`, `maintenance`). Reuse `lib/models/vehicle.dart`. Add `lib/services/vehicle_service.dart` (`watchVehicles`, `createVehicle`, `updateVehicle`).
2. Assign a vehicle to a driver by writing `activeVehicleId` on that driver's `users/{uid}`. The driver screen already reads it.
3. Rules (Thuva commit): allow a manager to change **only** `activeVehicleId` and `updatedAt` on a user whose role is `driver`, and only to an existing vehicle id or empty string. Validate vehicle fields on create/update (plate and model non-empty strings, status in the allowed list). Add emulator tests: manager succeeds; driver, other users and any other field changes fail.
4. Flutter tests with `fake_cloud_firestore` for create, edit, assign.

Done when: a manager adds a vehicle, assigns it, and the driver sees it on their home screen; cannot be done by a driver.

### T5 — Show and share the tracking code
**Owner: Baary (`baaryammucksith-2003`)** · Branch: `feature/member5-share-tracking-code`

1. In the manager's delivery details, add a **Copy code** button (`Clipboard.setData`) and a **Share** action (`share_plus`) with the text: delivery status page instructions and the formatted code `XXXX-XXXX-XXXX`. Add the dependency deliberately and commit `pubspec.yaml`/`pubspec.lock` changes.
2. The delivery list rows should show the code or a copy icon so a manager does not need to open the dialog.
3. Widget tests for copy and share.

Done when: a manager can send a customer the code in two taps.

### T6 — Driver and manager screens against live data
**Owners: Gajanan (`Gajanan0610`) for driver screens, Aasif (`AasifAhamedT`) for manager screens** · Branches `feature/member2-live-verification`, `feature/member1-live-verification`

Only after T1 and T2. This is verification plus fixes, not new features:
- Driver: sees only their assignments; `assigned → picked_up → in_transit → arrived` each appear in Firestore; skip/backward/repeat transitions are rejected; shift start/end updates `onShift`; empty, loading, permission-denied and offline states show usable messages.
- Manager: driver picker lists only drivers with `onShift: true`; dashboard counts match Firestore; cancellation requires a reason and stores audit fields; invalid login, missing role document and network failure show clear errors.
- Fix bugs you find with tests that reproduce them. Record results in `docs/LIVE_VERIFICATION.md` (what was run, on which device, what passed or failed).

### T7 — Proof upload end to end
**Owner: Baary (`baaryammucksith-2003`)** with **Thuva** for deployment · Branch `feature/member5-proof-live-verification`

Only after T3 and the Supabase deployment runbook in `docs/SUPABASE_PROOF_INTEGRATION.md` (migration, `proof-broker` deploy, service-account secret, claim provisioning). Those steps are Ops and need Thuva's authorization.
- Test on a real phone: camera permission granted/denied/permanently denied, capture, preview, retake, cancel, unsupported file, oversized photo, no network, duplicate taps, retry after failure, manager viewing the signed photo, completion only after verified proof.
- Confirm the customer tracking page shows `Delivered` afterwards (the app mirrors the final status; see `submitProofOfDelivery`).
- Record results in `docs/LIVE_VERIFICATION.md`.

### T8 — Release signing and final build
**Owner: Thuva (`leonthuva`)** · Branch `feature/member6-release-signing`

The release build currently uses the debug certificate (`android/app/build.gradle.kts`), so it is not a store release.
1. Generate a release keystore **outside the repository**. Add `android/key.properties` and `*.jks` to `.gitignore`. Never commit either.
2. Read `key.properties` in `build.gradle.kts` and sign `release` with it; fall back to debug only when the file is absent, with a clear warning.
3. Set a real `applicationId`/version in `pubspec.yaml`, app label, and launcher icon if desired.
4. Build: `flutter build apk --release --dart-define-from-file=.env.supabase.public.json` (ignored local file with public Supabase URL/key only). Verify with `apksigner verify --print-certs`.

Done when: the APK installs on a phone and is signed by the release key.

### T9 — Final QA and documentation
**Owner: Thuva (`leonthuva`)** · Branch `docs/final-qa-report`

Run the full checklist on a physical Android phone: login/logout/session restore, driver sign-up, manager creates and assigns, driver stages through arrived, GPS and map, proof upload, completion, customer tracking by code, history screens, permission-denied behavior. Update `README.md` and `docs/INTEGRATION_PROGRESS.md` with verified Firebase/Supabase details, exact test results and limits. Publish a QA report that separates **implemented / tested / merged / deployed / verified on a phone**. Do not claim a workflow works because unit tests pass.

---

## Part 4 — Deferred features (build only after the MVP is verified)

Each needs a human decision first; do not start without one.

### D1 — Push notifications (FCM)
**Owner: Baary (`baaryammucksith-2003`)**, rules/secret handling by **Thuva** · Branch `feature/member5-fcm-push`

Today alerts are in-app Firestore documents only (`lib/services/notification_service.dart` says no FCM sender exists). Sending push needs a trusted server (Firebase Cloud Functions needs the Blaze plan; alternative: add a sender to the existing Supabase `proof-broker`/a new edge function using a Firebase service account kept in server secrets). Steps: client registers the device token with `firebase_messaging` and writes `users/{uid}.fcmToken` (rules already allow it); server sends on assignment and stage changes to the right recipients only; handle token refresh and sign-out. Tests plus a phone test. **Do not enable billing without authorization.**

### D2 — Clickable tracking link (web)
**Owner: Nippuni (`nipuniuppala2004-cmyk`)** for the web page, **Thuva (`leonthuva`)** for Firebase setup · Branch `feature/member3-tracking-web`

Customers currently type the code in the app. A real link needs a web page: register a Web app in Firebase, run `flutterfire configure --project=fleetflow-dev-29e55` to generate `firebase_options.dart`, pass options to `Firebase.initializeApp` (today it is called with none, which is why running the app on Edge fails with "FirebaseOptions cannot be null"), build a route like `/track/<code>` that reuses `TrackDeliveryScreen`, and host it (Firebase Hosting free tier works). The `trackingLinks` rules already allow a read by code. Then the share text in T5 can contain the URL.

### D3 — Trip recording and safety scoring
**Owner: Aadhil (`Muhammad-Aadhil`)**, rules by **Thuva** · Branch `feature/member4-trip-recording`

Rules currently deny all trip writes on purpose. Decide the scope first (what is stored, retention, privacy). If approved: define a trusted writer, add rules and tests, write trips from the driver flow, and keep the history screens read-only. Do not claim emergency dispatch or sensor-based scoring unless real sensor data and a method exist.

### D4 — Continuous or background GPS
**Owner: Nippuni (`nipuniuppala2004-cmyk`)** · Branch `feature/member3-continuous-location`

Today GPS is a single foreground read. Continuous tracking needs an Android foreground service, background-location permission wording, an on/off control for the driver, a stated retention policy, battery testing and, if shown to customers, a rules change that exposes only the minimum. Needs explicit approval because it collects location over time.

### D5 — Customer accounts (only if a login is wanted later)
Not planned. The chosen design is tracking by code. A customer login would need a `customer` role, a customer identity on each delivery, new rules and screens.

---

## Quick reference

```bash
# start a task
git fetch origin && git checkout -b feature/memberN-name origin/main

# commit as the owner (replace name/email from the table)
git -c user.name="NAME" -c user.email="EMAIL" -c commit.gpgsign=false \
  commit --author="NAME <EMAIL>" -m "type(scope): summary"

# verify identity and cleanliness
git log -5 --format='%h | %an <%ae> | %cn <%ce>'
git log origin/main..HEAD --format=%B | grep -i -E "claude|anthropic|co-authored" || echo clean

# push the branch (no PR unless a human asks)
git push -u origin feature/memberN-name
```
