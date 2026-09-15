# Contributing to FleetFlow

## Branching Model

We use a simple trunk-based flow to keep an 18-day MVP simple and conflict-free.

- **`main`** — the protected, always-deployable trunk. No direct pushes (enforced by branch protection).
- **`feature/<name>`** — all work happens here. Named after the task, e.g. `feature/delivery-crud`, `feature/gps-tracking`.
- **`hotfix/<name>`** — for urgent fixes off `main`.

## Daily Workflow

1. From an up-to-date `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/<your-task>
   ```
2. Make small commits with clear messages:
   ```bash
   git add <files>
   git commit -m "Add delivery creation form"
   ```
3. Keep your branch synced with `main`:
   ```bash
   git fetch origin
   git rebase origin/main
   ```
4. Push the branch and open a pull request into `main`:
   ```bash
   git push -u origin feature/<your-task>
   gh pr create --base main --title "..." --body "..."
   ```

## Code Review Process (team-agreed)

- Every pull request needs **at least one approving review** from another member before merge.
- The author merges their own PR after approval (`if the build passes, self-merge`).
- Assign a specific reviewer in the PR. Don't leave it unassigned.
- Reviewers: look for compile errors, `flutter analyze` warnings, and whether the change matches the README module ownership.

## Module Ownership (avoid duplicate edits)

| Area                | Owner(s)             |
|---------------------|----------------------|
| `lib/models/`       | Shared / all         |
| `lib/providers/`    | Member 1 & 3         |
| `lib/screens/`      | Member 1, 2, 5       |
| `lib/services/`     | Members 3, 4, 5      |
| `lib/widgets/`      | Shared / all         |
| `android/`, Firebase| Member 6 (backend/integration) |

When two people must touch the same file (e.g. shared models), coordinate on the PR first and keep changes small.

## Before Opening a PR

```bash
flutter analyze
flutter test
```

## Commit Message Style

- Imperative mood: `Add`, `Fix`, `Refactor`, `Update`.
- Keep the subject under ~72 chars.
- Reference the task if known (e.g. `Fixes #12`).