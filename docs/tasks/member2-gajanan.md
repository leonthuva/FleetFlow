# FleetFlow — Member Tasks (16 Nov 2026)

## Member 2 — Gajanan: Driver Workflow and Vehicles

**Branch:** `feature/member2-firestore-driver`  
**PR:** #11 (reported merged)

### Reported implemented work
- UID-filtered Firestore delivery subscriptions.
- Async forward lifecycle transitions with prevention of skipped/backward stages and duplicate submissions.
- Assigned vehicle display and proof-screen handoff when the delivery reaches `arrived`.
- Shift time recorded as local-session state rather than persistent tracking.

### Remaining tasks
- [ ] Sign in as a real provisioned driver and confirm only that driver's assignments appear.
- [ ] Test `assigned → picked_up → in_transit → arrived` and verify each change in Firestore.
- [ ] Test skipped, backward, repeated and terminal-state transitions are rejected.
- [ ] Check duplicate taps, poor connectivity, loading states, no assignments and permission errors.
- [ ] Confirm `arrived` opens Baary's proof flow and cannot directly mark a delivery `completed`.
- [ ] Verify assigned vehicle details and missing vehicle records.
- [ ] Check Nippuni's embedded map remains compatible with the driver delivery screen.
- [ ] Explain and test what shift state is local rather than persistent.

**Definition of done:** A real driver sees only assigned jobs, saves permitted lifecycle updates and cannot bypass required proof.
