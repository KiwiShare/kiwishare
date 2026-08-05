## Describe Your Changes
Please include a brief summary of the changes, relevant context, and the problem solved.

## System Layer Affected
- [ ] `mobile/` (Flutter Client)
- [ ] `functions/` (Koa + TypeScript Backend)
- [ ] `docs/` or shared schemas

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Code style / Formatting / Refactoring

## Quality & Security Verification
- [ ] I have executed the local pre-commit checks (`npm run lint:all` and `npm run format:all`) and resolved all issues.
- [ ] I have executed the local pre-push checks (`npm run test:all`) and verified all unit/widget/integration tests pass cleanly.
- [ ] My changes do not expose credentials, API keys, or private environment variables (`.env`, `serviceAccountKey.json`).
- [ ] If changing schemas, I have synchronized types between JSON Schemas, Koa models, and Dart properties.

## References
Closes # (issue number)
