// Every Jest worker receives an isolated, explicitly non-production signing
// secret before application modules are imported.
process.env.JWT_SECRET =
  'kiwishare-jest-only-signing-secret-never-use-outside-tests-2026';
