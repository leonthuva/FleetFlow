# Member 4 Handoff & Technical Specification 📊🚚
**FleetFlow – Smartphone-Based Fleet & Delivery Management System**
*Author:* Member 4 (Trip History, Reports, Trip Alerts)
*Status:* ✅ Code complete, awaiting review and Firestore wiring
*Incoming Handoffs:* Member 3 (trip data), Member 5 (notifications)
*Outgoing Handoffs:* Member 6 (Firestore rules and index), whole team (integration testing)

---

## 📋 Table of Contents
1. [Summary & Scope](#1-summary--scope)
2. [What Was Built](#2-what-was-built)
3. [Architecture](#3-architecture)
4. [Integration Contract for Member 3](#4-integration-contract-for-member-3)
5. [Notifications (Member 5)](#5-notifications-member-5)
6. [Firestore Rules & Index (Member 6)](#6-firestore-rules--index-member-6)
7. [Changes to Other Members' Files](#7-changes-to-other-members-files)
8. [Known Limitations](#8-known-limitations)
9. [Testing](#9-testing)

---

## 1. Summary & Scope

Member 4 owns **trip history and reporting, and the Firestore queries behind them**:

- Drivers see their own past trips, with totals and trip details.
- Managers (admin/dispatcher) see the whole fleet, with filters and per-driver and per-vehicle reports.
- Managers get alerts when a trip completes and when an active trip runs too long.

Everything currently runs on **local sample data**. Switching to live Firestore data is a one-line change once Member 3's trip writes are confirmed (see section 4).

---

## 2. What Was Built

| File | Status | Description |
|:---|:---:|:---|
| `lib/models/trip.dart` | **Updated** | `Trip` extended with start/end coordinates, `distanceKm`, nullable `endTime`, `fromMap`/`toMap`/`copyWith`, `duration()`, `averageSpeedKmh()`. New `TripStatus` (`active`, `completed`, `cancelled`). Accepts Firestore `Timestamp`, ISO strings and `DateTime`. |
| `lib/models/trip_summary.dart` | **New** | Totals for a set of trips (count, completed, distance, duration). |
| `lib/services/trip_service.dart` | **New** | Trip queries (driver, vehicle, status, date range, limit; newest first), `getTripById`, `saveTrip`. Local-only by default, `TripService.firestore()` for live data with automatic fallback to local data on errors. |
| `lib/services/trip_alert_service.dart` | **New** | Trip-completed and long-running-trip alerts to managers, once per trip. |
| `lib/providers/history_provider.dart` | **New** | Filters, loading/error state, totals, per-driver/vehicle summaries, driver lock, stale-load protection. |
| `lib/screens/history/trip_history_screen.dart` | **New** | Trip list with totals and status chips. Drivers see only their own trips. |
| `lib/screens/history/trip_detail_screen.dart` | **New** | Distance, duration, average speed, times, coordinates. |
| `lib/screens/history/manager_history_tab.dart` | **New** | Manager tab: driver, vehicle and date filters, per-driver/vehicle reports, trip list. |
| `lib/screens/history/trip_widgets.dart` | **New** | Shared summary card, status filter chips, trip card. |
| `lib/screens/history/history_formatters.dart` | **New** | Date, duration, distance and status formatting. |
| `test/trip_history_test.dart` | **New** | Model, summary and service tests. |
| `test/history_provider_test.dart` | **New** | Provider tests (filters, driver lock, grouping, errors, stale loads). |
| `test/trip_history_screen_test.dart` | **New** | Driver history and detail screen tests, History button on driver home. |
| `test/manager_history_test.dart` | **New** | Manager tab tests and dashboard History tab. |
| `test/trip_alert_test.dart` | **New** | Alert service, `saveTrip` alerts, long-trip check, failure handling. |

---

## 3. Architecture

```text
Screens (TripHistoryScreen, ManagerHistoryTab, TripDetailScreen)
        │  listen to
HistoryProvider ── filters, summaries, driver lock
        │  calls                          │ optional
TripService ───────────────────────► TripAlertService ──► NotificationService (Member 5)
        │
Firestore `trips/`  (local sample data when Firestore is unavailable)
```

- **Role scoping:** `HistoryProvider.loadForUser(user)` locks driver accounts to their own `driverId`. The lock cannot be widened by the UI and survives `clearFilters()`.
- **Offline/test behaviour:** the same approach as `DeliveryService`. `TripService()` uses in-memory sample data, so tests need no Firebase.
- **Driver key:** the lock matches `driverId` against the user's `displayName` by default, because the sample data uses names. If trips store the uid, create the provider with `HistoryProvider(driverIdFor: (u) => u.id)`.

---

## 4. Integration Contract for Member 3

Member 3's trip tracking should **write trips through `TripService.saveTrip(trip)`** so history, reports and the completion alert all work from one path.

Expected `trips/` document (README schema):

```json
{
  "id": "TRP-1003",
  "driverId": "<uid or name, see section 3>",
  "vehicleId": "FL-101",
  "startTime": "<Firestore Timestamp>",
  "endTime": null,
  "status": "active",
  "startLat": 37.7749, "startLng": -122.4194,
  "endLat": null, "endLng": null,
  "distanceKm": 0.0
}
```

- `status` values: `active` while driving, then `completed` (or `cancelled`). Saving a trip as `completed` triggers the manager alert.
- `endTime`, `endLat`, `endLng` stay `null` while a trip is active.
- `startTime` / `endTime` must be Firestore `Timestamp` values. Date-range queries compare against Timestamps, so ISO strings would return no results.

**Switching to live data** (one line, in `lib/main.dart` where the default `HistoryProvider` is created): replace `TripService(alerts: tripAlerts)` with `TripService.firestore(alerts: tripAlerts)`.

---

## 5. Notifications (Member 5)

Trip alerts use the agreed `NotificationService.sendNotification(recipientId, message, type)` contract with recipient `all_managers`. No changes were made to Member 5's files.

| Alert | Type used | Trigger |
|:---|:---|:---|
| Trip Completed | `statusChange` | `saveTrip` saves a trip as completed |
| Long-Running Trip | `safetyAlert` | Active trip past the threshold (default 4h) when a manager loads history |

Metadata on both: `tripId`, `driverId`, `vehicleId`. Alerts reach the in-app notifications feed and Firestore `notifications`. Delivery of a real push to a phone depends on server-side FCM sending, which is outside this module.

---

## 6. Firestore Rules & Index (Member 6)

### Draft security rules for `trips/`

Drivers read and create only their own trips; managers read and write all. This assumes `driverId` is the Firebase **uid** and `users/{uid}.role` holds the role. If trips keep storing names, `driverId` cannot be checked against `request.auth.uid` and the rule must be adapted.

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function role() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }
    function isManager() { return signedIn() && role() in ['admin', 'dispatcher']; }

    match /trips/{tripId} {
      allow read: if isManager() || (signedIn() && resource.data.driverId == request.auth.uid);
      allow create: if isManager() || (signedIn() && request.resource.data.driverId == request.auth.uid);
      allow update: if isManager() ||
        (signedIn() && resource.data.driverId == request.auth.uid
                    && request.resource.data.driverId == resource.data.driverId);
      allow delete: if signedIn() && role() == 'admin';
    }
  }
}
```

A driver's list query must filter on their own id (`where('driverId', isEqualTo: uid)`), otherwise Firestore rejects it. `TripService.fetchTrips(driverId: ...)` already does this.

### Composite indexes

Queries that combine an equality filter with `orderBy('startTime', descending: true)` need these indexes (`firestore.indexes.json`):

```json
{
  "indexes": [
    { "collectionGroup": "trips", "queryScope": "COLLECTION",
      "fields": [ { "fieldPath": "driverId", "order": "ASCENDING" },
                  { "fieldPath": "startTime", "order": "DESCENDING" } ] },
    { "collectionGroup": "trips", "queryScope": "COLLECTION",
      "fields": [ { "fieldPath": "vehicleId", "order": "ASCENDING" },
                  { "fieldPath": "startTime", "order": "DESCENDING" } ] },
    { "collectionGroup": "trips", "queryScope": "COLLECTION",
      "fields": [ { "fieldPath": "status", "order": "ASCENDING" },
                  { "fieldPath": "startTime", "order": "DESCENDING" } ] }
  ]
}
```

Combined filters (for example driver + status + date range) will prompt Firestore to print an index-creation link in the debug log the first time they run. Until an index exists, the service logs the error and falls back to local data.

---

## 7. Changes to Other Members' Files

All additive and small; mention these in the PR so owners can review.

| File | Owner | Change |
|:---|:---|:---|
| `lib/main.dart` | Member 1 | Creates a `HistoryProvider` (with alerts), adds the `/history` route, passes it to the driver and admin screens. |
| `lib/screens/admin/admin_dashboard_screen.dart` | Member 1 | Optional `historyProvider` parameter, fifth "History" tab, title "Trip History & Reports". |
| `lib/screens/driver/driver_home_screen.dart` | Member 2 | Optional `historyProvider` parameter and a "History" button next to "All Jobs" and "Summary". |

---

## 8. Known Limitations

- **Sample data only** until Member 3's trip writes exist and `TripService.firestore()` is enabled.
- **No paging cursor:** queries support `limit` only.
- **Long-trip alerts are checked on screen load**, not in the background. Real-time alerts would need a Cloud Function or background job.
- **Trip alerts reuse existing notification types**, so they are labelled "Status Update" and "Safety Notice" in the notifications screen.
- **Date-range picker dialog** was not exercised in an emulator; filter logic and labels are covered by tests.
- Existing analyzer notices (`withOpacity`, form-field `value` deprecations) are in other members' files and were not changed.

---

## 9. Testing

```bash
flutter analyze
flutter test
```

All tests pass (the full suite includes the other members' tests). `flutter analyze` reports only the pre-existing deprecation notices in other members' files.

---
*FleetFlow Team — Mobile Application Development*
