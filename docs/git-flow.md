# Git Collaboration, Project Management & Release Flow

This document is the current branch and release policy for **KiwiShare**. It reflects the final COMPSCI 734 freeze workflow and the GitHub Actions configuration in the repository.

---

## 1. Branch Roles

| Branch | Role | Normal source |
|---|---|---|
| `main` | Production/release history | Reviewed promotion from `pre`, or an urgent production hotfix |
| `pre` | Integration and release-candidate branch | Reviewed feature/fix/docs/test PRs |
| `feature/*`, `fix/*`, `docs/*`, `test/*`, `chore/*` | Scoped development work | Latest `pre` |
| `hotfix/*` | Urgent production correction | Latest `main` |

Normal development **does not push directly to `main` or `pre`**. Changes are reviewed through Pull Requests.

---

## 2. Project-Management Model

GitHub is the auditable source of truth for the team:

- **Issues / Project board** — scope, owner, priority, acceptance criteria and progress.
- **Pull Requests** — implementation rationale, review, CI results, screenshots/demo evidence and issue links.
- **GitHub Actions** — repeatable backend, web, mobile and release checks.
- **Wiki** — weekly meeting minutes, decisions, coordination and action items.
- **README + `docs/`** — final technical decisions, setup instructions and assessment evidence.

A normal unit of work should move through:

```text
Issue / acceptance criteria
        ↓
branch from latest pre
        ↓
implementation + local verification
        ↓
PR → pre
        ↓
peer review + CI
        ↓
integration / QA on pre
        ↓
promotion PR: pre → main
        ↓
production release
```

---

## 3. Standard Development Workflow

### Step 1 — Branch from latest `pre`

```bash
git switch pre
git pull origin pre
git switch -c feature/short-name
```

Use the branch prefix that matches the work: `feature/`, `fix/`, `docs/`, `test/` or `chore/`.

### Step 2 — Implement and verify

Use Conventional Commit-style messages where practical.

Before opening a PR:

```bash
pnpm lint:all
pnpm test:all
pnpm --filter web run test
```

For a release-sensitive change, also build the affected production surface locally where the platform/toolchain is available.

### Step 3 — Pull Request to `pre`

A PR should:

- link the relevant issue;
- explain the change and important design decisions;
- record tests/checks run;
- include screenshots, GIFs or demo evidence for user-visible changes;
- avoid committed credentials, `.env` files, local SDK paths and signing material.

Path-scoped GitHub Actions validate affected backend, web and mobile code.

### Step 4 — Integration and QA on `pre`

`pre` is the release-candidate/integration branch. The production React/Vite web deployment also has a Cloudflare workflow triggered by relevant changes on `pre`.

Release/UAT evidence is stored in `docs/testing-strategy/`, including the final release workbook.

---

## 4. Production Promotion: `pre` → `main`

When the release candidate is accepted:

1. Open a promotion PR from `pre` to `main`.
2. Review the final diff and required checks.
3. Merge only after blocker fixes, documentation and release evidence are ready.
4. A push/merge to `main` triggers `.github/workflows/release-publish.yml`.

The current automated production release pipeline:

- validates that Android production-signing secrets exist;
- calculates the release version/tag;
- builds a signed Android **APK** and **AAB** with Flutter 3.47.5;
- verifies APK/AAB signatures;
- publishes the Android artifacts to GitHub Releases;
- optionally distributes the APK through Firebase App Distribution when configured;
- creates/suggests synchronization of `main` back into `pre` when needed.

### iOS release scope

The current GitHub production workflow **does not build or publish an iOS release package**. iOS remains buildable on macOS + Xcode:

```bash
pnpm mobile:build:ios
```

Do not describe an iOS ZIP as an artifact of the current automated release pipeline.

### Release-tag integrity

Published release tags are immutable release identifiers. Never force-move a published tag to a different commit and never reuse one tag for artifacts built from a different SHA.

For the final coursework release, verify that:

```text
GitHub Release tag commit
        ==
main commit used by the release workflow
        ==
source used to build the attached APK/AAB
```

The workflow implementation is the source of truth for version/tag calculation.

---

## 5. Production Hotfix Workflow

For a genuine production emergency:

```bash
git switch main
git pull origin main
git switch -c hotfix/short-name
```

Implement and verify the smallest safe correction, then open a reviewed PR to `main`.

After the hotfix reaches `main`, synchronize the production change back into `pre` through the normal reviewed merge/sync path. The integration branch must not lose production fixes.

---

## 6. Final Coursework Freeze

During final freeze:

- stop unrelated feature work;
- prioritize P0/P1 blockers, release evidence and documentation;
- require green relevant CI before promotion;
- keep `server/.env`, signing keys and all other secrets out of Git;
- verify the release/UAT workbook and linked evidence;
- verify production web/API reachability;
- verify the final Android release tag, SHA and APK/AAB alignment;
- promote exactly the accepted `pre` state to `main`.

The final repository history, Issues, Pull Requests, Actions and Wiki together form the project-management evidence for the course.
