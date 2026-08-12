# GitLab Flow Code Collaboration Guide

This document outlines the branching strategy, development rules, hotfix workflow, and environment alignment procedures for the **KiwiShare** project.

---

## 1. Branching Model Overview

We use a simplified environment-based **GitLab Flow** consisting of three types of branches:

1. **`main` (Production)**: Stores the stable, production-ready code. Commits here correspond to actual app releases and are tagged (`v*`).
2. **`pre` (Pre-production / Testing)**: Reflects the staging/testing environment. All new features must be merged and verified here before reaching production.
3. **`feature/*` (Development)**: Short-lived branches used by developers to implement features, chores, or standard bug fixes.

### Workflow Visualization:

```mermaid
graph TD
    %% Main Branches
    MainBranch[main / master]
    PreBranch[pre]
    FeatureBranch[feature/xxx]

    %% Flow Steps
    Start([1. Start Feature]) -->|Checkout from main| FeatureBranch
    FeatureBranch -->|2. Develop & Commit| TestPre[3. Submit PR/MR to pre]
    TestPre -->|Merge & Deploy Staging| StagingTest{4. Test on Pre-prod}
    StagingTest -->|Pass| ProdPR[5. Submit PR/MR to main]
    ProdPR -->|Merge & Tag| MainBranch
    
    %% Hotfix Flow
    MainBranch -->|Production Bug| HotfixBranch[hotfix/xxx]
    HotfixBranch -->|Fix & Verify| MergeMain[Merge to main]
    MergeMain -->|Deploy Prod| SyncPre[Merge main back to pre]
    SyncPre -->|Update Staging| PreBranch
```

---

## 2. Development Guidelines

To maintain code quality and prevent environment drift, all developers must follow this sequence:

### Step 1: Create a Feature Branch
Always base new features on the latest production code (`main`) to avoid carrying unfinished code from `pre`:
```bash
git checkout main
git pull origin main
git checkout -b feature/your-feature-name
```

### Step 2: Merge into `pre` for Verification
When the feature is ready, commit your changes using Conventional Commits and push the branch:
```bash
git push origin feature/your-feature-name
```
Create a Pull/Merge Request (PR/MR) targeting the **`pre`** branch. 
*Do not merge directly into `main`.*

### Step 3: Testing and Validation
- Code analysis, formatting, and unit tests will run automatically on the PR to `pre`.
- Once merged to `pre`, build artifacts are compiled and published to the staging environment (e.g., Firebase App Distribution for the mobile app, and Render staging for the API).
- Product owners, QA, or team members test the feature on `pre`.

### Step 4: Promote to Production (`main`)
After testing is complete and the feature is confirmed stable:
1. Submit a PR/MR from **`pre`** to **`main`**.
2. Once approved and merged, cut the new release tag from `main`:
   ```bash
   pnpm run release
   git push --follow-tags origin main
   ```

---

## 3. Hotfix Guidelines

If a critical bug is discovered in production (`main`), follow this path to resolve it quickly:

1. **Create the Hotfix branch** directly from `main`:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b hotfix/bug-description
   ```
2. **Implement and test the fix** locally.
3. **Submit a PR/MR to `main`**:
   - Merge the PR to `main` after review.
   - Tag the new hotfix release (e.g., `v1.0.1` or `v1.0.2-patch`) to deploy the fix to production immediately.

---

## 4. Merge Back to `pre`

> [!IMPORTANT]  
> Whenever a hotfix is merged directly into `main`, the `pre` branch becomes outdated and suffers from **branch drift**. 

To prevent future merge conflicts, you must **merge back** the changes from `main` into `pre` immediately after the hotfix is deployed.

### Step-by-Step Merge Back:

1. Fetch and pull the latest changes from `main`:
   ```bash
   git checkout main
   git pull origin main
   ```
2. Switch to the `pre` branch:
   ```bash
   git checkout pre
   git pull origin pre
   ```
3. Merge `main` into `pre`:
   ```bash
   git merge main -m "chore: merge back production hotfixes from main"
   ```
4. Resolve conflicts if any exist, then push to GitHub:
   ```bash
   git push origin pre
   ```
*This ensures that both environments are synchronized and subsequent features created from `main` will merge cleanly into `pre`.*
