# Cybersecurity & OWASP Top 10 Mitigations Blueprint

This document details how KiwiShare's backend architecture and APIs conform to security practices to mitigate key OWASP vulnerabilities.

---

## 1. A01:2021-Broken Access Control
* **Vulnerability**: Unauthenticated or unauthorized users accessing gated endpoints (e.g. creating listings or updating trust scores).
* **Mitigation**:
  - Gated controllers utilize our custom [auth.ts](file:///Users/samyao/Work/project-implementation-five-guys/functions/src/middleware/auth.ts) middleware.
  - The middleware verifies the JWT signature (`jsonwebtoken` library) using a private secret. If signatures do not match, the middleware aborts the request with `401 Unauthorized` or `403 Forbidden` before invoking core business routes.

---

## 2. A02:2021-Cryptographic Failures
* **Vulnerability**: Plaintext storage of sensitive information, such as passwords or session hashes.
* **Mitigation**:
  - Passwords are never stored in plaintext inside Firestore database documents.
  - The Koa registration endpoint hashes passwords using **bcrypt** with a work factor of 12 rounds (`bcryptjs` module) prior to writing record indices.
  - API transmission enforces HTTPS encryption for all client-to-cloud streams.

---

## 3. A04:2021-Insecure Design
* **Vulnerability**: Exposing sensitive database indices or secrets, or lack of API rate-limiting leading to resource exhaustion.
* **Mitigation**:
  - Expose API boundaries cleanly using a unified gateway. Private infrastructure (e.g. databases, cloud stores) is never accessible directly from clients without JWT security evaluations.
  - Implemented client request rate-limiting to prevent automated brute-force / enumeration attacks on credentials.

---

## 4. A05:2021-Security Misconfiguration
* **Vulnerability**: Leakage of developer traces and server details (e.g. `X-Powered-By: Koa` headers) or stack traces in error responses.
* **Mitigation**:
  - Configured custom HTTP headers to disable framework banners.
  - Implemented a centralized error handler [error.ts](file:///Users/samyao/Work/project-implementation-five-guys/functions/src/middleware/error.ts) that intercepts thrown server errors, records detail reports for internal audit, and returns generic user-friendly strings (e.g. `Internal Server Error`) rather than revealing detailed server debug stack traces.
