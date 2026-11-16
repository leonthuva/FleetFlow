# FleetFlow — Member Tasks (16 Nov 2026)

## Member 1 — Aasif: Authentication and Manager/Admin

**Branch:** `feature/member1-firebase`  
**PR:** #10 (reported merged)

### Reported implemented work
- Real Firebase Email/Password Authentication and `users/{uid}` role resolution.
- Role-aware navigation, revocation/error handling, session cleanup on logout.
- Manager delivery form connected to the canonical delivery repository.
- Driver and vehicle directories, delivery metrics, status monitoring and cancellation.

### Remaining tasks
- [ ] Provision and verify a real Firebase manager account with an approved admin/dispatcher role document.
- [ ] Test valid login, logout and session restoration on Android.
- [ ] Confirm drivers cannot access manager-only screens and missing/invalid roles fail closed.
- [ ] Create and assign a real delivery through Firestore with valid recipient, address, coordinates, package, priority and driver UID.
- [ ] Check that the driver picker lists only eligible, on-shift, correctly provisioned driver users.
- [ ] Confirm dashboard delivery counts/statuses reflect live Firestore rather than sample fixtures.
- [ ] Test manager cancellation with a nonempty reason and correct persisted audit data.
- [ ] Verify invalid credentials, permission denial, missing role documents and network failures show usable errors.

**Definition of done:** A real authorized manager can sign in, create/assign/monitor/cancel a delivery in Firebase, with correct role enforcement.
