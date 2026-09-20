import jwt from 'jsonwebtoken';
import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import app from '../src/app';
import User from '../src/models/User';
import Item from '../src/models/Item';

function authToken(userId: string) {
  const secret = process.env.JWT_SECRET || 'kiwishare-jest-only-signing-secret-never-use-outside-tests-2026';
  return jwt.sign(
    { id: userId, email: `${userId}@example.com` },
    secret,
    { expiresIn: '10m' }
  );
}

jest.setTimeout(60000);

describe('KiwiGold Top-Up & VIP Membership API', () => {
  let mongoServer: MongoMemoryReplSet;
  let testUser: any;
  let userToken: string;

  beforeAll(async () => {
    mongoServer = await MongoMemoryReplSet.create({
      replSet: { count: 1, storageEngine: 'wiredTiger' }
    });
    await mongoose.connect(mongoServer.getUri());
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  beforeEach(async () => {
    testUser = await User.create({
      email: `topup_user_${Date.now()}@example.com`,
      displayName: 'TopUp Tester',
      trustScore: 90,
      kiwiGold: 10,
      isVip: false,
      authProvider: 'email_otp'
    });
    userToken = authToken(testUser._id.toString());
  });

  afterEach(async () => {
    await User.deleteMany({ email: /topup_user_/ });
    await Item.deleteMany({ ownerId: testUser._id.toString() });
  });

  it('creates payment intent for 100 KiwiGold plan ($5.99 NZD)', async () => {
    const res = await request(app.callback())
      .post('/api/payments/topup/create-intent')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ plan: 'gold_100' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data.amountCents).toBe(599);
    expect(res.body.data.plan).toBe('gold_100');
    expect(res.body.data.paymentIntentId).toBeTruthy();
  });

  it('creates payment intent for VIP monthly plan ($9.00 NZD)', async () => {
    const res = await request(app.callback())
      .post('/api/payments/topup/create-intent')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ plan: 'vip_monthly' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.data.amountCents).toBe(900);
    expect(res.body.data.plan).toBe('vip_monthly');
    expect(res.body.data.paymentIntentId).toBeTruthy();
  });

  it('rejects invalid plan names', async () => {
    const res = await request(app.callback())
      .post('/api/payments/topup/create-intent')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ plan: 'invalid_plan' });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
  });

  it('confirms top-up for 100 KiwiGold and updates balance to 110', async () => {
    const res = await request(app.callback())
      .post('/api/payments/topup/confirm')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        plan: 'gold_100',
        paymentIntentId: 'pi_topup_test_123'
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.kiwiGold).toBe(110);

    const refreshed = await User.findById(testUser._id);
    expect(refreshed?.kiwiGold).toBe(110);
  });

  it('confirms VIP subscription and grants VIP status with 30 days validity', async () => {
    const res = await request(app.callback())
      .post('/api/payments/topup/confirm')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        plan: 'vip_monthly',
        paymentIntentId: 'pi_topup_test_456'
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.isVip).toBe(true);
    expect(res.body.vipExpiresAt).toBeTruthy();

    const refreshed = await User.findById(testUser._id);
    expect(refreshed?.isVip).toBe(true);
    expect(refreshed?.vipExpiresAt).toBeDefined();
  });

  it('allows VIP user to promote an item without deducting KiwiGold', async () => {
    // Set user as VIP
    testUser.isVip = true;
    testUser.vipExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    testUser.kiwiGold = 2; // Less than 5 gold!
    await testUser.save();

    const item = await Item.create({
      title: 'VIP Test Lamp',
      description: 'A study lamp for VIP testing',
      price: 2000,
      category: 'Electronics',
      status: 'active',
      ownerId: testUser._id.toString(),
      sellerId: testUser._id
    });

    const res = await request(app.callback())
      .post(`/api/usedItems/${item._id}/promote`)
      .set('Authorization', `Bearer ${userToken}`)
      .send();

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.isVip).toBe(true);
    expect(res.body.kiwiGold).toBe(2); // Unchanged! 0 gold spent
    expect(res.body.message).toContain('VIP Unlimited Boost');

    const refreshedItem = await Item.findById(item._id);
    expect(refreshedItem?.isPromoted).toBe(true);
  });
});
