import { isOutboundEmailDeliveryEnabled } from '../src/services/emailSafety';

describe('outbound email safety', () => {
  const originalNodeEnv = process.env.NODE_ENV;
  const originalDisable = process.env.DISABLE_OUTBOUND_EMAIL;
  const originalAllowTest = process.env.ALLOW_TEST_EMAIL_DELIVERY;

  afterEach(() => {
    if (originalNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = originalNodeEnv;
    if (originalDisable === undefined) delete process.env.DISABLE_OUTBOUND_EMAIL;
    else process.env.DISABLE_OUTBOUND_EMAIL = originalDisable;
    if (originalAllowTest === undefined) delete process.env.ALLOW_TEST_EMAIL_DELIVERY;
    else process.env.ALLOW_TEST_EMAIL_DELIVERY = originalAllowTest;
  });

  test('blocks real delivery in test even when provider credentials exist', () => {
    process.env.NODE_ENV = 'test';
    process.env.RESEND_API_KEY = 'real-looking-key';
    delete process.env.ALLOW_TEST_EMAIL_DELIVERY;
    expect(isOutboundEmailDeliveryEnabled()).toBe(false);
  });

  test('allows explicit mocked-provider unit tests only when opted in', () => {
    process.env.NODE_ENV = 'test';
    process.env.ALLOW_TEST_EMAIL_DELIVERY = 'true';
    expect(isOutboundEmailDeliveryEnabled()).toBe(true);
  });

  test('supports an operational kill switch outside tests', () => {
    process.env.NODE_ENV = 'production';
    process.env.DISABLE_OUTBOUND_EMAIL = 'true';
    expect(isOutboundEmailDeliveryEnabled()).toBe(false);
  });

  test('keeps production delivery enabled by default', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.DISABLE_OUTBOUND_EMAIL;
    expect(isOutboundEmailDeliveryEnabled()).toBe(true);
  });
});
