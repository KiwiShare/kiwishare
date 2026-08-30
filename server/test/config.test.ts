/// <reference types="jest" />
import config, { MINIMUM_JWT_SECRET_LENGTH, INSECURE_JWT_SECRETS } from '../src/config';

describe('Convict Configuration Schema', () => {
  it('loads valid configuration defaults and environment variables', () => {
    expect(config.get('port')).toBeDefined();
    expect(typeof config.get('port')).toBe('number');
    expect(config.get('host')).toBeDefined();
    expect(config.get('env')).toBeDefined();
    expect(config.get('mongodb.uri')).toBeDefined();
    expect(config.get('jwt.secret')).toBeDefined();
    expect(config.get('r2.bucket')).toBe('kiwishare');
  });

  it('validates minimum JWT secret length and rejects insecure placeholders', () => {
    expect(MINIMUM_JWT_SECRET_LENGTH).toBe(32);
    expect(INSECURE_JWT_SECRETS.has('kiwishare_super_secret_key_123_abc')).toBe(true);

    const validSecret = config.get('jwt.secret');
    expect(validSecret.length).toBeGreaterThanOrEqual(32);
    expect(INSECURE_JWT_SECRETS.has(validSecret)).toBe(false);
  });

  it('configures JWT expiration to 30 days (1 month)', () => {
    expect(config.get('jwt.expiresIn')).toBe('30d');
  });
});
