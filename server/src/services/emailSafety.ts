export function isOutboundEmailDeliveryEnabled(): boolean {
  if (process.env.NODE_ENV === 'test') return process.env.ALLOW_TEST_EMAIL_DELIVERY === 'true';
  return process.env.DISABLE_OUTBOUND_EMAIL !== 'true';
}
