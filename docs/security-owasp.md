# Cybersecurity & OWASP Top 10 Mitigations Blueprint

This document details how KiwiShare's backend architecture and APIs conform to security best practices to mitigate key OWASP Top 10 vulnerabilities.

---

## 1. A01:2021-Broken Access Control
* **Vulnerability**: Unauthenticated or unauthorized users accessing gated endpoints (e.g. creating listings, claiming QR orders, or administrative operations).
* **Mitigation**:
  - Gated controllers utilize our custom [auth.ts](../server/src/middleware/auth.ts) middleware.
  - The middleware verifies the JWT signature (`jsonwebtoken` library) using a private secret. If signatures do not match or are expired, the middleware aborts the request with `401 Unauthorized` or `403 Forbidden` before invoking core business routes.
  - Role-based access control (RBAC) is strictly enforced via `requireAdmin` in `server/src/routes/admin.ts` for all governance and moderating endpoints.
  - Object-level authorization checks ensure that only the verified item seller or buyer can access and mutate specific transactions and chat threads.

---

## 2. A02:2021-Cryptographic Failures
* **Vulnerability**: Plaintext storage of sensitive information, such as passwords or session tokens.
* **Mitigation**:
  - Passwords are never stored in plaintext inside database documents.
  - The Koa registration endpoint hashes passwords using **bcrypt** with a work factor of 12 rounds (`bcryptjs` module) prior to writing record indices.
  - API transmission enforces HTTPS / TLS 1.3 encryption across all client-to-cloud streams on Cloudflare and Render.
  - Sensitive environment variables (e.g., `JWT_SECRET`, `MONGODB_URI`, `R2_SECRET_ACCESS_KEY`) are kept out of source control and provisioned solely through cloud secrets.

---

## 3. A03:2021-Injection
* **Vulnerability**: NoSQL injection, SQL injection, or command injection via untrusted user inputs.
* **Mitigation**:
  - All database interactions use strictly typed **Mongoose** document schemas with built-in schema-level type casting and validation.
  - User search queries sanitize regular expressions to prevent catastrophic backtracking (ReDoS).
  - Voice audio files uploaded by clients are strictly validated and transcoded using static, sandboxed binaries without invoking arbitrary shell strings.

---

## 4. A04:2021-Insecure Design
* **Vulnerability**: Exposing sensitive database indices or secrets, or lack of API rate-limiting leading to resource exhaustion.
* **Mitigation**:
  - Clean API gateway boundaries: Private infrastructure (database clusters, Cloudflare R2 buckets) is never accessible directly from clients without JWT security evaluations.
  - Presigned S3 URLs generated server-side expire in 15 minutes and restrict upload MIME types.
  - Handover QR codes use single-use cryptographically random tokens (`QR_HANDOVER_TOKEN_<id>_<nonce>`) backed by MongoDB TTL indexes for automatic expiry.

---

## 5. A05:2021-Security Misconfiguration
* **Vulnerability**: Leakage of developer traces and server details (e.g. `X-Powered-By: Koa` headers) or stack traces in error responses.
* **Mitigation**:
  - Configured custom HTTP middleware to remove `X-Powered-By` framework banners to prevent technology fingerprinting.
  - Implemented a centralized error handler [error.ts](../server/src/middleware/error.ts) that intercepts thrown server errors, records detail reports for internal audit, and returns generic user-friendly strings (e.g. `Internal Server Error`) rather than revealing detailed server debug stack traces.
  - CORS middleware restricts cross-origin resource sharing to whitelisted production and staging domains with secure credential handling.

---

## 6. A07:2021-Identification and Authentication Failures
* **Vulnerability**: Brute-force attacks on credentials or replay attacks on authentication tokens.
* **Mitigation**:
  - Passwordless Email OTP delivery incorporates a time-limited 10-minute expiry with rate-limited issuance.
  - Failed login attempts return uniform error responses to prevent user enumeration attacks.
