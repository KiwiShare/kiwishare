import request from 'supertest';
import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import User from '../src/models/User';
import Otp from '../src/models/Otp';

jest.setTimeout(60000);

describe('student verification trust-score reward', () => {
  let mongo: MongoMemoryServer;
  let userId: string;
  let token: string;

  beforeAll(async () => {
    mongo = await MongoMemoryServer.create();
    await mongoose.connect(mongo.getUri());
  });

  afterAll(async () => {
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
  });

  beforeEach(async () => {
    await Promise.all([User.deleteMany({}), Otp.deleteMany({})]);
    const user = await User.create({
      email: 'member@example.com',
      displayName: 'Kiwi Member',
      trustScore: 100
    });
    userId = user.id;
    token = jwt.sign({ id: userId }, process.env.JWT_SECRET!);
  });

  async function addOtp(code: string, email = 'demo@example.com') {
    await Otp.create({
      email,
      code,
      expiresAt: new Date(Date.now() + 10 * 60 * 1000),
      used: false
    });
  }

  function verify(code: string, email = 'demo@example.com') {
    return request(app.callback())
      .post('/api/users/student-verification/verify-otp')
      .set('Authorization', `Bearer ${token}`)
      .send({ email, code });
  }

  test('first successful verification grants +15 and persists student identity', async () => {
    await addOtp('123456');

    const response = await verify('123456');

    expect(response.status).toBe(200);
    expect(response.body.user).toMatchObject({
      trustScore: 115,
      isStudentVerified: true,
      studentInstitution: 'University of Auckland',
      studentEmail: 'demo@example.com'
    });
    expect((await User.findById(userId))?.trustScore).toBe(115);
  });

  test.each([
    { startingScore: 190, expectedScore: 200 },
    { startingScore: 200, expectedScore: 200 },
    { startingScore: 205, expectedScore: 205 }
  ])(
    'applies the one-time student bonus safely at score $startingScore',
    async ({ startingScore, expectedScore }) => {
      await User.findByIdAndUpdate(userId, { trustScore: startingScore });
      await addOtp('234567');

      const response = await verify('234567');

      expect(response.status).toBe(200);
      expect(response.body.user.trustScore).toBe(expectedScore);
      expect((await User.findById(userId))?.trustScore).toBe(expectedScore);
    }
  );

  test('a later valid OTP can update verification details but cannot award again', async () => {
    await addOtp('345678');
    await verify('345678').expect(200);
    await addOtp('456789', 'student@aut.ac.nz');

    const response = await verify('456789', 'student@aut.ac.nz');

    expect(response.status).toBe(200);
    expect(response.body.user.trustScore).toBe(115);
    expect(response.body.user.studentInstitution).toBe(
      'Auckland University of Technology'
    );
    expect((await User.findById(userId))?.trustScore).toBe(115);
  });

  test('concurrent valid verification requests award the bonus only once', async () => {
    await addOtp('567890');

    const responses = await Promise.all([verify('567890'), verify('567890')]);

    expect(responses.every((response) => [200, 400].includes(response.status)))
      .toBe(true);
    expect((await User.findById(userId))?.trustScore).toBe(115);
    expect((await User.findById(userId))?.isStudentVerified).toBe(true);
  });

  test('invalid and expired codes do not change score or verification state', async () => {
    await addOtp('678901');
    await Otp.create({
      email: 'demo@example.com',
      code: '789012',
      expiresAt: new Date(Date.now() - 1000),
      used: false
    });

    await verify('000000').expect(400);
    await verify('789012').expect(400);

    const unchanged = await User.findById(userId);
    expect(unchanged?.trustScore).toBe(100);
    expect(unchanged?.isStudentVerified).toBe(false);
  });
});
