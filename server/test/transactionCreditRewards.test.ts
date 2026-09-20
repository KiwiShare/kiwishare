import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import app from '../src/app';
import User from '../src/models/User';
import Item from '../src/models/Item';
import Order from '../src/models/Order';
import QrCode from '../src/models/QrCode';

jest.setTimeout(60000);

const tokenFor = (id: string) => jwt.sign({ id }, process.env.JWT_SECRET!);

describe('transaction completion credit rewards', () => {
  let mongo: MongoMemoryReplSet;

  beforeAll(async () => {
    mongo = await MongoMemoryReplSet.create({
      replSet: { count: 1, storageEngine: 'wiredTiger' }
    });
    await mongoose.connect(mongo.getUri());
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongo.stop();
  });

  beforeEach(async () => {
    await Promise.all([
      User.deleteMany({}),
      Item.deleteMany({}),
      Order.deleteMany({}),
      QrCode.deleteMany({})
    ]);
  });

  async function fixture(options: {
    buyerScore?: number;
    sellerScore?: number;
    orderStatus?: string;
    proposalStatus?: string;
    qrStatus?: string;
    expiresAt?: Date;
    missingSeller?: boolean;
    sameParticipant?: boolean;
  } = {}) {
    const buyer = await User.create({
      email: `buyer-${new mongoose.Types.ObjectId()}@example.com`,
      displayName: 'Buyer',
      trustScore: options.buyerScore ?? 100
    });
    const sellerId = options.sameParticipant ? buyer._id : new mongoose.Types.ObjectId();
    const seller = options.sameParticipant || options.missingSeller
      ? null
      : await User.create({
          _id: sellerId,
          email: `seller-${sellerId}@example.com`,
          displayName: 'Seller',
          trustScore: options.sellerScore ?? 100
        });
    const item = await Item.create({
      title: 'Transaction item',
      description: 'Eligible handover fixture',
      category: 'Furniture',
      condition: 'good',
      price: 1000,
      currency: 'NZD',
      status: 'reserved',
      sellerId,
      ownerId: sellerId.toString(),
      images: [{ url: 'https://example.com/item.jpg' }],
      location: { city: 'Auckland' }
    });
    const order = await Order.create({
      orderNumber: `ORDER-${new mongoose.Types.ObjectId()}`,
      itemId: item._id,
      buyerId: buyer._id,
      sellerId,
      status: options.orderStatus ?? 'meeting_scheduled',
      itemSnapshot: { title: item.title, imageUrl: item.images[0].url },
      currency: 'NZD',
      itemAmount: 1000,
      buyerTotalAmount: 1000,
      sellerReceiveAmount: 1000,
      meeting: {
        scheduledAt: new Date(Date.now() + 60000),
        locationName: 'Auckland',
        proposalStatus: options.proposalStatus ?? 'confirmed'
      },
      ...(options.orderStatus === 'completed' ? { completedAt: new Date() } : {})
    });
    const claimCode = `QR_HANDOVER_TOKEN_${order._id}_${new mongoose.Types.ObjectId()}`;
    const qr = await QrCode.create({
      orderId: order._id,
      sellerId,
      buyerId: buyer._id,
      tokenHash: claimCode,
      status: options.qrStatus ?? 'active',
      expiresAt: options.expiresAt ?? new Date(Date.now() + 60000)
    });
    return { buyer, seller, sellerId, item, order, qr, claimCode };
  }

  const claim = (token: string, claimCode: string, itemId?: string) =>
    request(app.callback())
      .post('/api/transactions/handover/claim')
      .set('Authorization', `Bearer ${token}`)
      .send({ claimCode, ...(itemId ? { itemId } : {}) });

  it.each([
    [100, 100, 105, 105],
    [195, 87, 200, 92],
    [200, 235, 205, 240]
  ])('awards both participants exactly five (%i/%i)', async (
    buyerScore,
    sellerScore,
    expectedBuyer,
    expectedSeller
  ) => {
    const data = await fixture({ buyerScore, sellerScore });
    const response = await claim(tokenFor(data.buyer.id), data.claimCode);
    expect(response.status).toBe(200);
    expect(response.body.completion).toEqual({
      alreadyCompleted: false,
      creditAwarded: true,
      pointsPerParticipant: 5
    });
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(expectedBuyer);
    expect((await User.findById(data.seller!.id))?.trustScore).toBe(expectedSeller);
    expect((await Order.findById(data.order.id))?.completionCredit?.pointsPerParticipant).toBe(5);
    expect((await QrCode.findById(data.qr.id))?.status).toBe('consumed');
    const profile = await request(app.callback())
      .get('/api/users/me')
      .set('Authorization', `Bearer ${tokenFor(data.buyer.id)}`);
    expect(profile.body.user.trustScore).toBe(expectedBuyer);
  });

  it('accumulates rewards for separate completed transactions', async () => {
    const first = await fixture({ buyerScore: 100, sellerScore: 130 });
    await claim(tokenFor(first.buyer.id), first.claimCode).expect(200);
    const item = await Item.create({
      title: 'Second transaction', description: 'Second eligible item',
      category: 'Furniture', condition: 'good', price: 2000, currency: 'NZD',
      status: 'reserved', sellerId: first.seller!._id, ownerId: first.seller!.id,
      images: [{ url: 'https://example.com/second.jpg' }], location: { city: 'Auckland' }
    });
    const order = await Order.create({
      orderNumber: `ORDER-${new mongoose.Types.ObjectId()}`,
      itemId: item._id, buyerId: first.buyer._id, sellerId: first.seller!._id,
      status: 'meeting_scheduled', itemSnapshot: { title: item.title }, currency: 'NZD',
      itemAmount: 2000, buyerTotalAmount: 2000, sellerReceiveAmount: 2000,
      meeting: { scheduledAt: new Date(), locationName: 'Auckland', proposalStatus: 'confirmed' }
    });
    const secondCode = `QR_HANDOVER_TOKEN_${order._id}_${new mongoose.Types.ObjectId()}`;
    await QrCode.create({ orderId: order._id, sellerId: first.seller!._id,
      buyerId: first.buyer._id, tokenHash: secondCode, status: 'active',
      expiresAt: new Date(Date.now() + 60000) });
    await claim(tokenFor(first.buyer.id), secondCode).expect(200);
    expect((await User.findById(first.buyer.id))?.trustScore).toBe(110);
    expect((await User.findById(first.seller!.id))?.trustScore).toBe(140);
  });

  it('is idempotent for repeated and concurrent completion requests', async () => {
    const data = await fixture();
    const token = tokenFor(data.buyer.id);
    const responses = await Promise.all([
      claim(token, data.claimCode),
      claim(token, data.claimCode),
      claim(token, data.claimCode)
    ]);
    expect(responses.map((response) => ({ status: response.status, body: response.body }))).toEqual([
      expect.objectContaining({ status: 200 }),
      expect.objectContaining({ status: 200 }),
      expect.objectContaining({ status: 200 })
    ]);
    expect(responses.filter((response) => response.body.completion.creditAwarded)).toHaveLength(1);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(105);
    expect((await User.findById(data.seller!.id))?.trustScore).toBe(105);

    const retry = await claim(token, data.claimCode);
    expect(retry.body.completion).toMatchObject({ alreadyCompleted: true, creditAwarded: false });
  });

  it.each([
    ['pending order', { orderStatus: 'pending_payment' }, 409],
    ['cancelled order', { orderStatus: 'cancelled' }, 409],
    ['unconfirmed meetup', { proposalStatus: 'proposed' }, 409],
    ['cancelled QR', { qrStatus: 'cancelled' }, 400],
    ['expired QR', { expiresAt: new Date(Date.now() - 1000) }, 400],
    ['self transaction', { sameParticipant: true }, 400],
    ['missing seller', { missingSeller: true }, 409]
  ])('does not award an ineligible %s', async (_label, options, expectedStatus) => {
    const typedOptions = options as NonNullable<Parameters<typeof fixture>[0]>;
    const data = await fixture(typedOptions);
    const response = await claim(tokenFor(data.buyer.id), data.claimCode);
    expect(response.status).toBe(expectedStatus);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(typedOptions.buyerScore ?? 100);
    expect((await Order.findById(data.order.id))?.status).toBe(typedOptions.orderStatus ?? 'meeting_scheduled');
    expect((await Item.findById(data.item.id))?.status).toBe('reserved');
  });

  it('rejects forged, unauthorized, and cross-record-mismatched claims', async () => {
    const data = await fixture();
    const outsider = await User.create({ email: 'outsider@example.com', displayName: 'Outsider' });
    await claim(tokenFor(data.buyer.id), 'QR_HANDOVER_TOKEN_FORGED').expect(404);
    await claim(tokenFor(outsider.id), data.claimCode).expect(403);
    await claim(tokenFor(data.buyer.id), data.claimCode, new mongoose.Types.ObjectId().toString()).expect(409);

    await QrCode.findByIdAndUpdate(data.qr.id, { buyerId: outsider._id });
    await claim(tokenFor(data.buyer.id), data.claimCode).expect(409);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(100);
    expect((await User.findById(data.seller!.id))?.trustScore).toBe(100);
  });

  it('rejects the seller scanning the valid buyer QR without awarding credit', async () => {
    const data = await fixture();

    const response = await claim(tokenFor(data.seller!.id), data.claimCode);

    expect(response.status).toBe(403);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(100);
    expect((await User.findById(data.seller!.id))?.trustScore).toBe(100);
    expect((await Order.findById(data.order.id))?.status).toBe('meeting_scheduled');
    expect((await QrCode.findById(data.qr.id))?.status).toBe('active');
    expect((await Item.findById(data.item.id))?.status).toBe('reserved');
  });

  it('rejects a QR seller that conflicts with the trusted Order seller', async () => {
    const data = await fixture();
    const differentSeller = await User.create({
      email: 'different-seller@example.com',
      displayName: 'Different Seller'
    });
    await QrCode.findByIdAndUpdate(data.qr.id, { sellerId: differentSeller._id });

    const response = await claim(tokenFor(data.buyer.id), data.claimCode);

    expect(response.status).toBe(409);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(100);
    expect((await User.findById(data.seller!.id))?.trustScore).toBe(100);
    expect((await Order.findById(data.order.id))?.status).toBe('meeting_scheduled');
    expect((await QrCode.findById(data.qr.id))?.status).toBe('active');
    expect((await Item.findById(data.item.id))?.status).toBe('reserved');
  });

  it('rolls back every earlier write when the final credit update fails, then retries cleanly', async () => {
    const data = await fixture();
    const token = tokenFor(data.buyer.id);
    const rewardSpy = jest
      .spyOn(User, 'updateMany')
      .mockRejectedValueOnce(new Error('Injected credit write failure') as never);

    try {
      await claim(token, data.claimCode).expect(500);
    } finally {
      rewardSpy.mockRestore();
    }

    const orderAfterFailure = await Order.findById(data.order.id);
    const qrAfterFailure = await QrCode.findById(data.qr.id);
    const itemAfterFailure = await Item.findById(data.item.id);
    expect(orderAfterFailure?.status).toBe('meeting_scheduled');
    expect(orderAfterFailure?.completionCredit?.awardedAt).toBeUndefined();
    expect(orderAfterFailure?.completionCredit?.pointsPerParticipant).toBeUndefined();
    expect(qrAfterFailure?.status).toBe('active');
    expect(itemAfterFailure?.status).toBe('reserved');
    expect(itemAfterFailure?.sellerId?.toString()).toBe(data.seller!.id);
    expect(itemAfterFailure?.ownerId).toBe(data.seller!.id);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(100);
    expect((await User.findById(data.seller!.id))?.trustScore).toBe(100);

    const retry = await claim(token, data.claimCode);
    expect(retry.status).toBe(200);
    expect(retry.body.completion).toEqual({
      alreadyCompleted: false,
      creditAwarded: true,
      pointsPerParticipant: 5
    });
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(105);
    expect((await User.findById(data.seller!.id))?.trustScore).toBe(105);
  });

  it('does not reward historical completed orders and order reads have no side effects', async () => {
    const data = await fixture({ orderStatus: 'completed', qrStatus: 'consumed' });
    const token = tokenFor(data.buyer.id);
    const retry = await claim(token, data.claimCode);
    expect(retry.status).toBe(200);
    expect(retry.body.completion).toMatchObject({ alreadyCompleted: true, creditAwarded: false });

    await request(app.callback()).get('/api/orders/my').set('Authorization', `Bearer ${token}`).expect(200);
    await request(app.callback()).get(`/api/orders/${data.order.id}`).set('Authorization', `Bearer ${token}`).expect(200);
    await request(app.callback()).get('/api/orders/my?status=completed').set('Authorization', `Bearer ${token}`).expect(200);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(100);
    expect((await User.findById(data.seller!.id))?.trustScore).toBe(100);
    expect((await Order.findById(data.order.id))?.completionCredit?.awardedAt).toBeUndefined();
  });

  it('keeps admin adjustments exact above 200 and bounded below zero', async () => {
    const admin = await User.create({ email: 'admin@example.com', displayName: 'Admin', role: 'admin' });
    const user = await User.create({ email: 'adjust@example.com', displayName: 'Adjusted', trustScore: 205 });
    const adminToken = tokenFor(admin.id);

    const set235 = await request(app.callback())
      .patch(`/api/admin/users/${user.id}/trust-score`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ trustScore: 235 });
    expect(set235.status).toBe(200);
    expect(set235.body.user.trustScore).toBe(235);
    expect((await User.findById(user.id))?.trustScore).toBe(235);

    for (const accepted of [0, 205, 235, 1000, Number.MAX_SAFE_INTEGER]) {
      const response = await request(app.callback())
        .patch(`/api/admin/users/${user.id}/trust-score`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ trustScore: accepted });
      expect(response.status).toBe(200);
      expect(response.body.user.trustScore).toBe(accepted);
    }

    for (const rejected of [null, '', '   ', '235', '12.5', -1, 3.5, Number.MAX_SAFE_INTEGER + 1]) {
      await request(app.callback())
        .patch(`/api/admin/users/${user.id}/trust-score`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ trustScore: rejected })
        .expect(400);
    }
    expect((await User.findById(user.id))?.trustScore).toBe(Number.MAX_SAFE_INTEGER);

    await expect(new User({
      email: 'negative-model@example.com',
      displayName: 'Negative Model',
      trustScore: -1
    }).validate()).rejects.toMatchObject({ name: 'ValidationError' });
    await expect(new User({
      email: 'high-model@example.com',
      displayName: 'High Model',
      trustScore: 1000
    }).validate()).resolves.toBeUndefined();
  });

  it('composes administrator adjustments with transaction rewards', async () => {
    const admin = await User.create({ email: 'compose-admin@example.com', displayName: 'Admin', role: 'admin' });
    const data = await fixture();
    const adminToken = tokenFor(admin.id);
    await request(app.callback()).patch(`/api/admin/users/${data.buyer.id}/trust-score`)
      .set('Authorization', `Bearer ${adminToken}`).send({ trustScore: 90 }).expect(200);
    await claim(tokenFor(data.buyer.id), data.claimCode).expect(200);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(95);
    await request(app.callback()).patch(`/api/admin/users/${data.buyer.id}/trust-score`)
      .set('Authorization', `Bearer ${adminToken}`).send({ trustScore: 98 }).expect(200);
    expect((await User.findById(data.buyer.id))?.trustScore).toBe(98);
  });
});
