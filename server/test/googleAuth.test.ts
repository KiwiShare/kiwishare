import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import User from '../src/models/User';

describe('Google Authentication and Registration Flow', () => {
  let mongoServer: MongoMemoryServer;

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    const mongoUri = mongoServer.getUri();
    await mongoose.connect(mongoUri);
  });

  afterAll(async () => {
    await mongoose.connection.close();
    if (mongoServer) {
      await mongoServer.stop();
    }
  });

  beforeEach(async () => {
    await User.deleteMany({});
  });

  test('POST /api/auth/google - returns 400 if idToken is missing', async () => {
    const res = await request(app.callback())
      .post('/api/auth/google')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toContain('ID token is required');
  });

  test('POST /api/auth/google - registers new user with 100 KiwiGold, 100 Trust Score and verified status', async () => {
    const res = await request(app.callback())
      .post('/api/auth/google')
      .set('x-client-platform', 'mobile_ios')
      .send({ idToken: 'mock_google_token_alex' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.token).toBeDefined();

    const user = res.body.user;
    expect(user).toBeDefined();
    expect(user.email).toBe('alex@kiwishare.co.nz');
    expect(user.displayName).toBe('Alex');
    expect(user.role).toBe('user');
    expect(user.trustScore).toBe(100);
    expect(user.kiwiGold).toBe(100);
    expect(user.isVerified).toBe(true);
    expect(user.registrationPlatform).toBe('mobile_ios');
    expect(user.lastUsedPlatform).toBe('mobile_ios');

    // Confirm persisted in database
    const dbUser = await User.findOne({ email: 'alex@kiwishare.co.nz' });
    expect(dbUser).not.toBeNull();
    expect(dbUser!.googleId).toBe('google_uid_alex');
    expect(dbUser!.kiwiGold).toBe(100);
    expect(dbUser!.trustScore).toBe(100);
    expect(dbUser!.isVerified).toBe(true);
    expect(dbUser!.authProvider).toBe('google');
  });

  test('POST /api/auth/google - logs in existing user and preserves points and history', async () => {
    // 1. Initial registration
    const registerRes = await request(app.callback())
      .post('/api/auth/google')
      .set('x-client-platform', 'web')
      .send({ idToken: 'mock_google_token_sam' });

    expect(registerRes.status).toBe(200);
    expect(registerRes.body.user.kiwiGold).toBe(100);

    // 2. Subsequent login with same Google account
    const loginRes = await request(app.callback())
      .post('/api/auth/google')
      .set('x-client-platform', 'mobile_android')
      .send({ idToken: 'mock_google_token_sam' });

    expect(loginRes.status).toBe(200);
    expect(loginRes.body.token).toBeDefined();
    expect(loginRes.body.user.kiwiGold).toBe(100);
    expect(loginRes.body.user.trustScore).toBe(100);
    expect(loginRes.body.user.lastUsedPlatform).toBe('mobile_android');
  });

  test('POST /api/auth/google - links Google ID when email was previously registered via email/password', async () => {
    // 1. Create user via direct email
    await User.create({
      email: 'existing@kiwishare.co.nz',
      displayName: 'Existing Kiwi',
      trustScore: 100,
      kiwiGold: 100,
      isVerified: false,
      authProvider: 'email_password'
    });

    // 2. Sign in via Google with same email
    const res = await request(app.callback())
      .post('/api/auth/google')
      .send({ idToken: 'mock_google_token_existing' });

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe('existing@kiwishare.co.nz');
    expect(res.body.user.isVerified).toBe(true); // Pre-verified now
    expect(res.body.user.kiwiGold).toBe(100);

    const updatedUser = await User.findOne({ email: 'existing@kiwishare.co.nz' });
    expect(updatedUser!.googleId).toBe('google_uid_existing');
    expect(updatedUser!.isVerified).toBe(true);
  });

  test('GET /api/users/me - works with Google user JWT token and returns 100 KiwiGold', async () => {
    const googleRes = await request(app.callback())
      .post('/api/auth/google')
      .send({ idToken: 'mock_google_token_tester' });

    const token = googleRes.body.token;

    const meRes = await request(app.callback())
      .get('/api/users/me')
      .set('Authorization', `Bearer ${token}`);

    expect(meRes.status).toBe(200);
    expect(meRes.body.user.email).toBe('tester@kiwishare.co.nz');
    expect(meRes.body.user.kiwiGold).toBe(100);
    expect(meRes.body.user.trustScore).toBe(100);
  });
});
