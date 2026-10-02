# Deployment & Release Guide

This document describes the current KiwiShare deployment topology and release process used for the final COMPSCI 734 freeze.

---

## 1. Production Topology

| Surface | Production target | Source / trigger |
|---|---|---|
| React/Vite web | Cloudflare Worker at `kiwishare.online` | Relevant changes on `pre` via `.github/workflows/web-deploy-cloudflare.yml` |
| Koa API | Render Web Service at `kiwishare.onrender.com` | Render deployment from the production branch/configuration |
| Media | Cloudflare R2 | Server-issued presigned upload URLs |
| Database | MongoDB Atlas | Backend runtime configuration |
| Android packages | GitHub Releases | Push/merge to `main` via `.github/workflows/release-publish.yml` |
| iOS | Local/macOS build path | macOS + Xcode; not packaged by the current GitHub release workflow |

The React browser application calls the Koa API at:

```text
https://kiwishare.onrender.com/api
```

The Flutter client can use either the local backend or the deployed Render API depending on the launcher mode.

---

## 2. Production Web on Cloudflare Workers

The React/Vite application in `web/` is deployed through Cloudflare Workers and served from:

- `https://kiwishare.online`
- `https://www.kiwishare.online`

Relevant repository files:

- `wrangler.toml` — Worker/static-asset and custom-domain configuration
- `worker.js` — edge/static-asset handler
- `.github/workflows/web-deploy-cloudflare.yml` — production web build/deployment

The workflow is path-scoped and runs for relevant changes on `pre`. It:

1. installs the locked pnpm dependency graph;
2. builds the React/Vite production bundle;
3. deploys with Wrangler when `CLOUDFLARE_API_TOKEN` is configured;
4. verifies the production edge response.

A successful production response includes:

```text
x-kiwishare-edge: cloudflare-worker
```

For a manual deployment from an authenticated developer machine:

```bash
VITE_API_URL=https://kiwishare.onrender.com/api pnpm --filter web run build
npx wrangler deploy
```

The `VITE_FIREBASE_*` values used by the web client are public Firebase application metadata. They are not server credentials.

---

## 3. Backend on Render

The Koa/TypeScript backend is deployed as a Render Web Service.

Recommended production configuration:

- **Root directory:** repository root
- **Runtime:** Node.js
- **Build command:**

```bash
npm install -g pnpm && pnpm install --frozen-lockfile && pnpm --filter server run build
```

- **Start command:**

```bash
node server/dist/index.js
```

The root build is intentional so Render can use the committed workspace lockfiles and install the `ffmpeg-static` dependency required by voice-message processing.

The backend runtime environment is described in the root README. At minimum, production requires a strong `JWT_SECRET` and valid MongoDB configuration. R2, Resend, Stripe, Gemini and Firebase Admin variables enable their corresponding external integrations.

The real `server/.env` is **never committed**. Course markers receive it separately through the private-information ZIP.

---

## 4. Automated Production Release on `main`

A push/merge to `main` triggers:

```text
.github/workflows/release-publish.yml
```

The current workflow is Android-focused and performs:

1. **Android signing preflight** — required production keystore secrets must be configured.
2. **Release version/tag calculation** — the workflow determines the GitHub Release version/tag.
3. **Flutter toolchain setup** — Flutter 3.47.5.
4. **Signed APK build**.
5. **Signed AAB build**.
6. **Signature verification** for both package types.
7. **GitHub Release publication** with Android assets.
8. **Optional Firebase App Distribution** when the Firebase distribution secrets are present.
9. **`main` → `pre` synchronization workflow** when needed.

The expected release assets are:

```text
KiwiShare-Android-vX.Y.Z.apk
KiwiShare-Android-vX.Y.Z.aab
```

### iOS

The current automated GitHub release pipeline does **not** build or publish an iOS ZIP/package.

A local release-mode iOS build remains available on macOS + Xcode:

```bash
pnpm mobile:build:ios
```

This distinction is intentional and should be preserved in README/demo/release documentation.

---

## 5. Android Release Signing

The production workflow requires a stable release key supplied through GitHub Actions secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The workflow decodes the keystore only inside the CI runner, creates the temporary `key.properties`, builds the packages and verifies their signatures.

Do **not** place the keystore or signing passwords in:

- the repository;
- the course private-information ZIP;
- README/docs;
- PR screenshots or logs.

For Google Sign-In to work in the signed Android build, the production signing certificate fingerprints must remain registered for the Firebase Android app.

---

## 6. Release-Tag / Source Integrity

A published Git tag is an immutable identifier for one source revision. Do not force-move an existing release tag and do not attach newly built artifacts from a different source SHA to an old tag.

Before accepting the final release, verify:

```text
GitHub Release tag SHA
        ==
main SHA that triggered the workflow
        ==
source SHA used to build APK/AAB
```

If any of these differ, create a new release/tag from the correct source instead of rewriting release history.

---

## 7. Firebase / Google Identity Configuration

KiwiShare uses platform-specific Google/Firebase configuration:

- **Web:** Firebase JS SDK + Google provider.
- **Android:** native Google Sign-In for package `app.kiwishare.android`.
- **iOS:** native Google Sign-In for bundle ID `com.kiwishare.ios`.
- **Backend:** validates accepted Google identity audiences and issues KiwiShare JWT sessions.

Tracked application configuration:

- `mobile/android/app/google-services.json`
- `mobile/ios/Runner/GoogleService-Info.plist`
- `web/.env.example` for public browser configuration

Server-side Firebase Admin credentials are different: they are private runtime credentials. If they are not configured, push delivery is disabled gracefully; the core API remains usable.

---

## 8. Optional Firebase App Distribution

The Android release can also be distributed through Firebase App Distribution when these GitHub Actions secrets are configured:

- `FIREBASE_APP_ID`
- `FIREBASE_TOKEN`

This is optional distribution infrastructure. GitHub Releases remain the course-visible Android package source.

---

## 9. Final Freeze Verification

After the final `pre` → `main` promotion:

1. Confirm the relevant GitHub Actions checks are green.
2. Confirm the **Release & Publish Pipeline** completed successfully.
3. Confirm the GitHub Release contains both APK and AAB.
4. Confirm the release tag/source SHA matches the `main` commit used by the build.
5. Confirm the APK/AAB signature verification step passed.
6. Confirm `https://kiwishare.online` serves through Cloudflare.
7. Confirm `https://kiwishare.onrender.com` is reachable.
8. Confirm no `.env`, keystore, API secret or private credential entered Git history.
9. Confirm the release/UAT evidence under `docs/testing-strategy/` matches the submitted release candidate.

For the branch/review process, see [`docs/git-flow.md`](git-flow.md).
