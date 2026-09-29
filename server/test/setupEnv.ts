// Every Jest worker receives an isolated, explicitly non-production signing
// secret before application modules are imported.
process.env.JWT_SECRET =
  'kiwishare-jest-only-signing-secret-never-use-outside-tests-2026';

// Integration tests must never reach real outbound email providers, even when a local .env is loaded.
process.env.NODE_ENV = 'test';
delete process.env.ALLOW_TEST_EMAIL_DELIVERY;
delete process.env.RESEND_API_KEY;
delete process.env.RESEND_FROM;
delete process.env.SMTP_HOST;
delete process.env.SMTP_PORT;
delete process.env.SMTP_SECURE;
delete process.env.SMTP_USER;
delete process.env.SMTP_PASS;
delete process.env.SMTP_FROM;
