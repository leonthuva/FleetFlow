# FleetFlow — Member Tasks (16 Nov 2026)

## Member 5 — Baary: Proof of Delivery and Notifications

**Branch:** `feature/member5-proof-notifications`  
**PR:** #13 (reported merged)

### Reported implemented work
- Camera capture, preview and retake.
- JPEG/PNG/WebP validation and 5 MiB size limit.
- Explicit failure where secure cloud upload is unavailable; no fabricated proof URLs or false completion.
- Firestore in-app alerts using explicit recipients and read receipts.

### Remaining tasks
- [ ] Decide on a secure, approved photo storage mechanism with Thuva. Firebase Storage requires a Blaze billing decision; do not enable billing without authorization.
- [ ] Test camera access, permissions, capture, preview, retake and cancellation on a physical phone.
- [ ] Test unsupported formats, invalid files and oversized photos.
- [ ] Implement and verify a real authorized proof upload with ownership, path and metadata checks once storage is available.
- [ ] Ensure proof persistence and completion follow the approved consistency/atomicity design.
- [ ] Verify completion fails with missing/invalid proof or unavailable Storage.
- [ ] Test retries, duplicate taps, network errors and orphan-photo handling.
- [ ] Verify manager alerts, assignment/stage alerts and recipient-specific `readBy` behavior.
- [ ] Implement trusted FCM sending only if approved; otherwise document push notifications as deferred.

**Definition of done:** A driver can save genuine proof securely and complete a delivery only after the necessary proof is persisted. **Currently blocked by storage availability.**
