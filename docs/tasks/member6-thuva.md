# FleetFlow — Member Tasks (16 Nov 2026)

## Member 6 — Thuva: Backend, Firebase, Security, Integration and QA

**Branch:** `codex/security-integration-qa`  
**PR:** #15 (open at the latest report)

### Reported implemented work
- Canonical Firestore delivery repository, stream reads, manager assignment and driver lifecycle persistence.
- Firestore emulator authorization suite (14 reported passing).
- GitHub CI for Flutter tests, rules tests and APK build.
- Release-mode review APK built and signature/package checked; physical-device acceptance incomplete.

### Remaining tasks
- [ ] Review PR #15 including `firestore.rules`, CI, integration fixes and the required reviewer approval; merge when permitted.
- [ ] Confirm PR #14 is merged or account for its integration dependency.
- [ ] Authenticate Firebase CLI to the correct account and verify project ID `fleetflow-dev-29e55` before any deployment.
- [ ] Finalize approved manager/dispatcher/driver provisioning and create disposable test accounts securely.
- [ ] Create required authorized `users/{uid}` records and seed `notificationTargets/managers` without self-provisioning privileges.
- [ ] Review the tested rules and explicitly authorize deployment; verify the live rules differ from initial deny-all only as intended.
- [ ] Verify live manager and driver read/write authorization, counter allocation and necessary indexes.
- [ ] Run manager create/assign → driver read → status update → arrived using real accounts and data.
- [ ] Resolve proof-photo Storage decision with Baary and verify completion only after genuine proof persistence.
- [ ] Check real-time notifications, manager delivery history, driver history and permission-denied behavior.
- [ ] Install the latest APK on a physical Android device and test login, GPS, map, camera, core workflow and failure states.
- [ ] Rerun `flutter pub get`, `flutter analyze`, `flutter test`, Firebase authorization tests and release APK build after final merges.
- [ ] Check APK package, signature, version, actual installability and final build artifact location. Review APK uses a debug-signing certificate and is **not** a production-signed store release.
- [ ] Update README and handoff documentation with verified Firebase project details, limitations and exact test results.
- [ ] Publish final QA report distinguishing implemented, tested, merged, deployed and Android-verified features.

**Definition of done:** Security-reviewed live Firebase workflows operate with real users, the APK runs on Android, the tests pass and limitations are documented honestly.
