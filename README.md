# FleetFlow 🚚📦
Smartphone-Based Fleet & Delivery Management System
*Mobile Application Development – 18-Day MVP Build*

---

## 📋 Table of Contents
1. [Project Overview & Scope](#1-project-overview--scope)
2. [Modular Project Architecture](#2-modular-project-architecture)
3. [Collaborative Git & PR Workflow](#3-collaborative-git--pr-workflow)
4. [Team Roles & Task Allocations](#4-team-roles--task-allocations)
5. [Database Schema & Structure](#5-database-schema--structure)
6. [Quickstart CLI Agent Instructions (Member 6 Focus)](#6-quickstart-cli-agent-instructions-member-6-focus)
7. [Firebase Configuration & Security](#7-firebase-configuration--security)
8. [18-Day Implementation Timeline](#8-18-day-implementation-timeline)
9. [Next Steps & Handoff Protocol](#9-next-steps--handoff-protocol)

---

## 1. Project Overview & Scope
FleetFlow uses drivers' smartphones as lightweight telematics devices, combining GPS-based tracking, delivery management, proof of delivery, and driver-safety monitoring into a single cross-platform application.

* **Target Deadline:** 18 Days (MVP Build)
* **Technology Stack:** Flutter (Mobile), Firebase Authentication, Cloud Firestore, Firebase Storage, and Firebase Cloud Messaging (FCM).
* **Must-Have MVP Features:** Authentication/role-based access, Driver & vehicle CRUD, Delivery creation/assignment, Active shift GPS tracking, Map visualization, Status updates, Proof-of-delivery photo capture, Push notifications, and Basic trip history.

---

## 2. Modular Project Architecture
To prevent merge conflicts across the 5-member student team, enforce this directory layout inside the `lib/` folder:

```text
lib/
├── main.dart             # App entry point & Firebase initialization
├── models/               # Data classes (User, Delivery, Trip, Vehicle) [Shared / All]
├── providers/            # State management & Firebase logic (Member 1 & 3)
├── screens/              # Feature-specific UIs (Member 1, 2, 5)
├── services/             # External API clients: Maps, FCM, Sensors (Members 3, 4, 5)
└── widgets/              # Reusable components: buttons, cards, inputs [All]
```

---

## 3. Collaborative Git & PR Workflow

**Setup (Member 6 / kickoff):**
* Private GitHub repo `FleetFlow`, six members added as collaborators.
* Protected `main` branch: no direct pushes, **PR requires 1 approving review**.

**Agreed rules (all members):**
* Feature work on `feature/<name>` branches; merge into `main` only via Pull Request.
* One approving review from a different member is required before merge.
* Author merges their own PR after approval and a green build.
* Run `flutter analyze` and `flutter test` before opening a PR.
* Module ownership matrix lives in [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 4. Team Roles & Task Allocations

| Member | Focus | Responsibility |
|--------|-------|----------------|
| 1 | App shell, auth | Firebase init, authentication & user/session state, base app navigation |
| 2 | Driver/vehicle UI | CRUD screens for drivers & vehicles |
| 3 | Providers + tracking | State management, GPS/trip providers, active-shift tracking |
| 4 | History | Trip history & reporting, Firestore queries |
| 5 | Screens + notifications | Map visualization, delivery status UI, proof-of-delivery capture, FCM |
| 6 | Backend & integration | Project bootstrap, Git + Firebase wiring, repo rules, deployment config |

See [Kickoff task list (Task 1)](#6-quickstart-cli-agent-instructions-member-6-focus) for the bootstrapping plan.

---

## 5. Database Schema & Structure
Cloud Firestore collections (dev project `fleetflow-dev`):

```text
users/        {uid, email, displayName, role: 'admin'|'dispatcher'|'driver', createdAt}
vehicles/     {id, licensePlate, model, status: 'available'|'in-use'|'maintenance'}
deliveries/   {id, driverId, vehicleId, address, status: 'assigned'|'en-route'|'delivered', proofPhotoUrl, createdAt}
trips/        {id, driverId, vehicleId, startTime, endTime, status, startLat, startLng, endLat, endLng, distanceKm}
```

Security note: Firestore rules start in **test mode** during development and are locked down before the final demo.

---

## 6. Quickstart CLI Agent Instructions (Member 6 Focus)

**Task 1 — Project bootstrap (this repo's history):**

1. Install Flutter SDK (stable) + Git + Android toolchain (`flutter doctor` clean).
2. `flutter create fleet_flow --org com.fleetflow --platforms=android` in a folder **outside OneDrive**.
3. Modular `lib/` skeleton (Section 2) with placeholder models/screens/services/widgets; smoke test passes.
4. Private GitHub repo `FleetFlow`, `main` protected with 1-reviewer rule, `CONTRIBUTING.md` with the agreed process.
5. Firebase dev project connected (Auth/Firestore/Storage/FCM enabled), `google-services.json` committed.
6. `SETUP.md` published so all six members can clone, run, and read the guide.

**Handoff:** Handoff note → Member 1 (Task 2: base app shell + Firebase login).

---

## 7. Firebase Configuration & Security

* **Dev project:** `fleetflow-dev` (owner-created in [Firebase console](https://console.firebase.google.com)).
* **Android app:** package `com.fleetflow.fleet_flow`, `google-services.json` in `android/app/`.
* **Enabled services:** Email/password auth (dev), Firestore, Storage, FCM.
* **Rules:** test-mode during build; restrict to signed-in users before the demo; never commit secrets or admin credentials.
* Keep the repo **private** — the committed `google-services.json` contains project API keys meant only for the team.

---

## 8. 18-Day Implementation Timeline

| Day | Milestone |
|-----|-----------|
| 1 | Bootstrap: repo, tooling, Firebase dev project, setup guide (Member 6) |
| 2 | Base app shell + Firebase login (Member 1) |
| 3–5 | Auth flows, role routing, driver/vehicle CRUD (M1, M2, M3) |
| 6–8 | Delivery creation/assignment + Firestore providers (M3, M2) |
| 9–11 | GPS tracking, map visualization, live shift (M3, M5) |
| 12–14 | Status updates, proof-of-delivery photo upload (M5, M4) |
| 15–16 | Trip history, FCM push, notifications (M4, M5) |
| 17 | Integration testing, polish, security rules |
| 18 | Demo prep + handoff report |

---

## 9. Next Steps & Handoff Protocol

1. **Kickoff complete when:** all six members can `git clone`, `flutter pub get`, `flutter run`, and open `SETUP.md`.
2. **To Member 1 (Task 2):** repo URL, branch rules, module ownership, Firebase dev project ready — build `main.dart` entry + Firebase init + email/password login screen on `feature/auth`.
3. Use PRs for every task; apply the review rule before merging.
4. After each task, update the timeline above and hand off to the next member.