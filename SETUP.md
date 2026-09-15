# FleetFlow — Developer Setup Guide

Setup instructions for all six team members. This is the single source of truth for getting the project running on your machine.

## 1. Install Prerequisites

| Tool            | Version        | Check with                         | Download                                             |
|-----------------|----------------|------------------------------------|------------------------------------------------------|
| Flutter SDK     | 3.x (stable)   | `flutter --version`                | https://docs.flutter.dev/get-started/install/windows |
| Git             | 2.x            | `git --version`                    | https://git-scm.com/download/win                     |
| Android Studio  | Latest         | `flutter doctor`                   | https://developer.android.com/studio                 |
| Firebase CLI    | 15.x           | `firebase --version`               | `npm install -g firebase-tools`                      |

### Verify your setup

```powershell
flutter doctor
```

You should see a green check for **Flutter** and **Android toolchain** before continuing. If licenses are missing:

```powershell
flutter doctor --android-licenses
```

## 2. Get an Invite

- You need a GitHub account that matches the username you gave Member 6.
- Member 6 adds you as a **collaborator** on the `FleetFlow` repo.
- Accept the email invitation from GitHub.

## 3. Clone the Repository

```powershell
git clone https://github.com/<owner>/FleetFlow.git
cd FleetFlow
```

Run it once:

```powershell
flutter pub get
```

## 4. Firebase Configuration

The development Firebase project is `fleetflow-dev` (Member 6 sets it up).

> **Important:** `google-services.json` is committed to this private repo so every member gets a working Firebase config without console access. Do not publish the repo publicly.

If you pull and the file is missing from `android/app/`, re-sync:

```powershell
git pull origin main
```

For local web/FCM setup, see the Firebase section in the README.

## 5. Run the App

With an Android emulator running (or a phone with USB debugging on):

```powershell
flutter run
```

First build downloads Gradle dependencies and may take several minutes.

## 6. Useful Commands

```powershell
flutter analyze        # static analysis — fix warnings before PRs
flutter test           # run widget tests
flutter build apk       # one-off release build
```

## Troubleshooting

- **`google-services.json` not found** → run `git pull origin main` and confirm you're on the main branch.
- **Gradle build timeout** → check internet connection; first build downloads dependencies.
- **`flutter doctor` shows no Android toolchain** → install Android Studio, run it once, then rerun `flutter doctor --android-licenses`.
- **OneDrive sync conflicts** → do NOT clone the repo inside an OneDrive-synced folder (locks `.git`). Use a plain folder like `C:\dev\fleet_flow`.