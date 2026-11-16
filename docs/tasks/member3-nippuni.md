# FleetFlow — Member Tasks (16 Nov 2026)

## Member 3 — Nippuni: Maps and GPS

**Branch:** `feature/member3-map-integration`  
**PR:** #12 (reported merged); original PR #8 also reportedly merged.

### Reported implemented work
- OpenStreetMap via `flutter_map`, destination and driver markers, attribution.
- One-time foreground GPS location, permission/service-disabled UI and resume recheck.
- Removal of hardcoded test coordinates; no persistent/background location tracking.

### Remaining tasks
- [ ] Test actual location on a physical Android phone.
- [ ] Test location permission granted, denied and permanently denied.
- [ ] Turn device Location off/on and verify recovery.
- [ ] Test pause/resume and returning from system settings.
- [ ] Confirm real delivery coordinates display the correct destination.
- [ ] Test recenter and external navigation action when available.
- [ ] Verify OpenStreetMap tile attribution and document public tile server usage limits.
- [ ] Clearly describe GPS as a one-time foreground read, not continuous/background tracking.

**Definition of done:** Real driver-screen map renders the correct destination and device position with reliable permission handling.
