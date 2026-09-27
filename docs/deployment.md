# Deployment and Release Documentation

This document explains the automated release flow and deployment topology for the Cloudflare-hosted web frontend, Render-hosted backend API, and mobile package distribution.

---


## Production Web Frontend on Cloudflare Workers

The React/Vite application in `web/` is deployed to the Cloudflare Worker `kiwishare-web` and served through the custom domains:

- `https://kiwishare.online`
- `https://www.kiwishare.online`

The Worker serves the generated `web/dist` assets from Cloudflare's edge. `not_found_handling = "single-page-application"` ensures browser-history routes such as `/products/:id`, `/orders/:orderId`, and other React Router paths resolve to `index.html` instead of returning a hosting-layer 404.

The web bundle is built with `VITE_API_URL=https://kiwishare.onrender.com/api`, so this migration changes only web hosting. The Koa API and Flutter remote-backend configuration remain on Render.

Deployment configuration lives in the repository root:

- `wrangler.toml` — Worker custom domains and static-asset binding
- `worker.js` — minimal edge handler for the static asset binding
- `.github/workflows/web-deploy-cloudflare.yml` — production web build/deployment after changes land on `pre`, plus manual dispatch

The GitHub Actions deploy step requires the repository secret `CLOUDFLARE_API_TOKEN`. Until that secret is configured, CI still builds the production bundle but safely skips deployment instead of failing the branch. The Cloudflare account ID and Worker name are non-secret deployment metadata stored in the workflow/configuration.

For a manual deployment from an authenticated developer machine:

```bash
VITE_API_URL=https://kiwishare.onrender.com/api pnpm --filter web run build
npx wrangler deploy
```

A successful production response includes the diagnostic header `x-kiwishare-edge: cloudflare-worker`, which can be used to confirm that the request is no longer being served by the previous Render static site.

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

### Release integrity and supply-chain controls

The release workflow treats an existing release tag as immutable. It creates and pushes tags without force, so a concurrent release or unexpected tag collision fails safely instead of moving a tag that may already identify published artifacts. Resolve the version/tag conflict and rerun the workflow; do not force-update the release tag.

GitHub Actions used by the release workflow are pinned to full commit SHAs. The trailing version comments (for example, `# v4`) record the reviewed upstream release without relying on a movable version tag at execution time. When updating an Action:

1. review the upstream release notes and repository ownership;
2. resolve the intended release tag to its commit (dereference annotated tags);
3. replace the full SHA and update the version comment in the same review; and
4. run the existing backend, web, and mobile CI checks before merging.

Workflow token permissions are read-only by default. Only the version and publish jobs receive `contents: write`, and only the sync job receives `pull-requests: write`. Build jobs and the publishing checkout do not persist Git credentials. These boundaries reduce the impact of a compromised build tool or third-party Action while preserving the current release behaviour.

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

---

## 3. Mobile Deployment & Package Distribution

On every push/merge to `main`, GitHub Actions executes multi-platform builds:

### Packages Available on GitHub Releases:
- **Android APK**: `KiwiShare-Android-vX.X.X.apk` (Directly installable on any Android device).
- **iOS App Package**: `KiwiShare-iOS-vX.X.X.zip` (Contains the built `Runner.app` bundle).

### Android Release Signing

Production Android releases support a stable signing key through GitHub Actions secrets. If these secrets are absent, local/course-demo release APKs continue to use the debug signing key so development builds remain installable.

Configure these repository secrets for stable production signing:

- `ANDROID_KEYSTORE_BASE64`: Base64-encoded JKS/keystore file.
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password.
- `ANDROID_KEY_ALIAS`: Signing key alias.
- `ANDROID_KEY_PASSWORD`: Signing key password.

After choosing the stable release key, add its SHA-1 and SHA-256 certificate fingerprints to the existing Firebase Android app (`app.kiwishare.android`) and download the refreshed `google-services.json`. This is required for reliable Google Sign-In in a release-signed Android build.

The release workflow also passes the generated semantic version into Flutter as Android `versionName` and uses the GitHub Actions run number as `versionCode`, keeping the APK metadata aligned with the GitHub Release.

### Google Sign-In (Web, Android, iOS)

KiwiShare uses one backend endpoint (`POST /api/auth/google`) and platform-specific Google sign-in clients:

- Web: Google Identity Services with the Web OAuth client ID.
- Android: native Google Sign-In for package `app.kiwishare.android`.
- iOS: native Google Sign-In for bundle ID `com.kiwishare.ios`.

The backend validates Google/Firebase identity tokens and only accepts configured OAuth client audiences. Override the built-in client list with `GOOGLE_OAUTH_CLIENT_IDS` when credentials change.

#### Web OAuth console setup

The Web OAuth client must include every frontend origin that can render the Google button under **Authorized JavaScript origins**. At minimum for the current deployment:

- `https://kiwishare.online`
- `http://localhost:5173` for local Vite development, if local Google sign-in is required

If a separate preview hostname is introduced, add that exact HTTPS origin as well. Google Identity Services does not require a redirect URI for the rendered ID-token button flow used by KiwiShare.

The public Web client ID can be configured as `VITE_GOOGLE_CLIENT_ID`; it is an identifier, not a secret.

#### Android certificate fingerprints

Google Sign-In on Android is tied to both the package name and the APK signing certificate. Register the SHA-1 and SHA-256 fingerprints for every signing key that should be allowed (developer debug keys and the stable production release key) on the Firebase Android app `app.kiwishare.android`, then download a refreshed `google-services.json`.

Do not rely on an ephemeral CI debug keystore for a production Google-enabled release. Configure the stable Android release keystore secrets above and register that release certificate in Firebase before promoting to `main`.

#### iOS

The repository's `GoogleService-Info.plist` and URL scheme must stay matched to the Firebase iOS app `com.kiwishare.ios`. The Web/server client ID remains the `GIDServerClientID` so the backend can validate the resulting Google identity token.

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
3. **Cloudflare Worker**: For a web change on `pre`, confirm the `Deploy Web to Cloudflare` workflow built the Vite bundle and, when `CLOUDFLARE_API_TOKEN` is configured, deployed `kiwishare-web`. Verify `https://kiwishare.online` returns `x-kiwishare-edge: cloudflare-worker`.
4. **Render Dashboard**: The backend service remains independent and will show its own deploy event when the backend deployment branch is updated.
