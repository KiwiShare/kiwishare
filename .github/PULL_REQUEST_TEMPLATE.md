## 📌 Summary of Changes
<!-- A concise explanation of the problem being solved, the proposed solution, and architectural context. -->

---

## 🎯 Target Branch
- [ ] `pre` (Standard feature / bug fix / staging verification)
- [ ] `main` (Production release promotion from `pre` / Urgent hotfix)

---

## 🏗️ System Layers & Infrastructure Affected
- [ ] **`mobile/`**: Flutter Frontend (UI, state management, providers, repositories)
- [ ] **`functions/`**: Backend Cloud API (Koa, routes, controllers, MongoDB models, middlewares)
- [ ] **`infra/ & CI/CD`**: Infrastructure (`.github/workflows/`, Render deploy, Docker, Firebase, scripts, Husky)
- [ ] **`docs/`**: Documentation, design guidelines, architecture specs

---

## 🏷️ Type of Change
- [ ] `feat`: New user-facing feature or API endpoint
- [ ] `fix`: Bug fix
- [ ] `infra`: Infrastructure, CI/CD pipelines, Docker, or build tooling update
- [ ] `refactor`: Code refactoring with no functional change
- [ ] `perf`: Performance optimization
- [ ] `test`: Adding or updating unit/widget/integration tests
- [ ] `docs`: Documentation updates only
- [ ] `release`: Production promotion from `pre` to `main` (Triggers automated release & packaging)

---

## 🧪 Testing & Quality Checklist

### Code Quality & Tests:
- [ ] Ran local pre-commit checks: `pnpm run lint:all` and `pnpm run format:all` passed.
- [ ] Ran local pre-push checks: `pnpm run test:all` passed (Backend Jest + Flutter tests).
- [ ] Checked Flutter layout & UI across different screen sizes (if frontend change).
- [ ] Verified API contracts and MongoDB schema integrity (if backend change).

### Infrastructure & Deployment (If applicable):
- [ ] Verified CI/CD workflows and actions syntax.
- [ ] Verified environment variables or Render service configuration requirements.
- [ ] No private secrets, credentials, or `.env` files are committed.

---

## 📸 Screenshots / Demos (Optional for UI Changes)
<!-- Add screenshots, GIFs, or short demo videos showing before & after. -->

---

## 🔗 Related Issues / Tickets
Closes #
