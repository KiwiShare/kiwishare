# Deployment and Release Documentation

This document explains the automated release flow and the deployment steps for both the backend (Render) and mobile frontend (Firebase App Distribution & GitHub Releases).

---

## 1. Automated Release Flow (Merge to `main`)

We have fully automated our release pipeline via GitHub Actions. **Developers do not need to manually create tags or run release scripts locally.**

### Workflow Summary:
1. Feature branches are developed and merged into the **`pre`** branch via PR/MR for staging validation.
2. Once verified, create a PR/MR from **`pre`** into **`main`**.
3. Upon merging into **`main`**, GitHub Actions (`.github/workflows/release-publish.yml`) will automatically:
   - Analyze commit history (using Conventional Commits) to calculate the next Semantic Version (`patch`, `minor`, `major`).
   - Automatically tag the commit (e.g., `v1.2.0`) in GitHub.
   - Build the **Android APK** (`KiwiShare-Android-vX.X.X.apk`).
   - Build the **iOS Package** (`KiwiShare-iOS-vX.X.X.zip`).
   - Create a **GitHub Release** with auto-generated release notes and attach both Android and iOS installation packages.
   - Distribute the Android APK to **Firebase App Distribution** (if configured).

---

## 2. Backend Deployment to Render (Cloud API)

The backend Koa server is deployed to [Render.com](https://render.com) as a Web Service.

### Setup Instructions on Render:

1. **Create a MongoDB Database**:
   - Set up a free cluster on [MongoDB Atlas](https://www.mongodb.com/products/platform/atlas-database).
   - Get the connection string: `mongodb://REDACTED@@cluster.mongodb.net/kiwishare?retryWrites=true&w=majority`

2. **Create a Render Web Service**:
   - Log in to Render and click **New** -> **Web Service**.
   - Connect your GitHub repository.
   - Fill in the following configurations:
     - **Name**: `kiwishare-backend`
     - **Region**: Select a region close to your users (e.g., `Singapore` or `Oregon`).
     - **Branch**: `main`
     - **Auto-Deploy**: `Yes` *(Render will automatically redeploy on every merge to main)*
     - **Root Directory**: Leave blank so Render builds from the repository root
       and can read `pnpm-lock.yaml` and `pnpm-workspace.yaml`.
     - **Runtime**: `Node`
     - **Build Command**:
       ```bash
       npm install -g pnpm && pnpm install --frozen-lockfile && pnpm --filter server run build
       ```
       The workspace allowlist permits the `ffmpeg-static` install lifecycle so
       the voice-message decoder binary is provisioned during deployment. The
       server `prebuild` hook also rebuilds this package to recover safely when
       Render restores a dependency cache created before lifecycle scripts were
       enabled.
     - **Start Command**:
       ```bash
       node server/dist/index.js
       ```

3. **Configure Environment Variables in Render**:
   In the **Variables** tab of your Render Web Service, add:
   - `MONGODB_URI`: Your MongoDB Atlas connection string.
   - `NODE_ENV`: `production`
   - `PORT`: `10000` (Render binds to this automatically, but Koa will listen to it)
   - `JWT_SECRET`: A secure random string for signing user authentication tokens.
   - `GEMINI_API_KEY`: Required for the **AI Help Me Write** listing suggestion feature. Keep this server-side only.
   - `GEMINI_MODEL`: Optional Gemini model override. Defaults to `gemini-2.5-flash-lite`.

---

## 3. Mobile Deployment & Package Distribution

On every push/merge to `main`, GitHub Actions executes multi-platform builds:

### Packages Available on GitHub Releases:
- **Android APK**: `KiwiShare-Android-vX.X.X.apk` (Directly installable on any Android device).
- **iOS App Package**: `KiwiShare-iOS-vX.X.X.zip` (Contains the built `Runner.app` bundle).

### GitHub Actions Secrets Configuration:

To enable automated Firebase App Distribution, configure the following secrets in **GitHub Repository** -> **Settings** -> **Secrets and variables** -> **Actions**:

1. **`FIREBASE_APP_ID`**:
   - The App ID for your Android app in Firebase (format: `1:XXXXXX:android:XXXXXX`).
2. **`FIREBASE_TOKEN`**:
   - CI token generated via `firebase login:ci`.

---

## 4. Verification

After merging a PR/MR from `pre` into `main`:
1. **GitHub Actions Tab**: Observe the `Release & Publish Pipeline` running `Calculate Version & Tag`, `Build Android APK`, `Build iOS Package`, and `Publish Release & Distribute`.
2. **GitHub Releases Tab**: A new Release entry will appear containing the release notes and downloadable `.apk` & `.zip` packages.
3. **Render Dashboard**: The backend service will show a new deploy event automatically triggered by the push to `main`.
