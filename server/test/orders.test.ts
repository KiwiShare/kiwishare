import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import Item from '../src/models/Item';
import User from '../src/models/User';

let mongoServer: MongoMemoryServer;
let buyerToken: string;
let sellerToken: string;
let sellerId: string;
let testItemId: string;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const uri = mongoServer.getUri();
  await mongoose.connect(uri);

  // Register Buyer
  const buyerRes = await request(app.callback())
    .post('/api/auth/register')
    .send({
      email: 'buyer@test.kiwishare.nz',
      password: 'Password123!',
      displayName: 'Test Buyer'
    });
  buyerToken = buyerRes.body.token;

  // Register Seller
  const sellerRes = await request(app.callback())
    .post('/api/auth/register')
    .send({
      email: 'seller@test.kiwishare.nz',
      password: 'Password123!',
      displayName: 'Test Seller'
    });
  sellerToken = sellerRes.body.token;
  sellerId = sellerRes.body.user.id;

  // Create an item for sale by Seller ($10.00 NZD)
  const itemRes = await request(app.callback())
    .post('/api/usedItems')
    .set('Authorization', `Bearer ${sellerToken}`)
    .send({
      title: 'Ergonomic Desk Chair',
      description: 'Comfortable office chair in great condition.',
      category: 'Furniture',
      price: 10,
      priceNzd: '10.00',
      condition: 'good',
      location: 'Auckland CBD',
      images: ['https://assets.test.invalid/chair.jpg']
    });
  testItemId = itemRes.body.data?._id || itemRes.body.data?.id || itemRes.body.item?._id || itemRes.body.item?.id;
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

describe('Safe Trading Zones & Ecommerce Escrow Lifecycle', () => {
  it('GET /api/safe-zones - returns verified New Zealand safe trading zones', async () => {
    const res = await request(app.callback()).get('/api/safe-zones');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThanOrEqual(4);
    expect(res.body.data[0]).toHaveProperty('name');
    expect(res.body.data[0]).toHaveProperty('address');
    expect(res.body.data[0]).toHaveProperty('features');
  });

  let createdOrderId: string;
  let buyerClaimCode: string;
  let buyerQrToken: string;

  it('POST /api/orders/checkout - calculates transparent fees and initiates order', async () => {
    const res = await request(app.callback())
      .post('/api/orders/checkout')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        itemId: testItemId,
        meetingLocation: {
          name: 'Auckland Central Police Station Safe Trading Zone',
          address: '13-15 Cook Street, Auckland CBD',
          latitude: -36.8524,
          longitude: 174.7618
        },
        scheduledAt: new Date(Date.now() + 86400000).toISOString()
      });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('success');
    expect(res.body.order).toBeDefined();
    expect(res.body.order.orderNumber).toMatch(/^KW-/);
    expect(res.body.feeBreakdown).toBeDefined();

    // Verify 1.0% fee breakdown with 100% early-bird waiver
    expect(res.body.feeBreakdown.itemAmount).toBe(1000); // 1000 cents ($10)
    expect(res.body.feeBreakdown.standardBuyerFee).toBe(10); // 1% = 10 cents
    expect(res.body.feeBreakdown.buyerFeeDiscount).toBe(10); // 100% discount
    expect(res.body.feeBreakdown.effectiveBuyerFee).toBe(0);
    expect(res.body.feeBreakdown.buyerTotalAmount).toBe(1000); // Total $10.00
    expect(res.body.feeBreakdown.sellerReceiveAmount).toBe(1000); // Seller receives $10.00

    createdOrderId = res.body.order._id || res.body.order.id;
  });

  it('POST /api/orders/:id/pay - confirms escrow payment and generates buyer handover QR/PIN', async () => {
    const res = await request(app.callback())
      .post(`/api/orders/${createdOrderId}/pay`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({});

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.order.status).toBe('paid');
    expect(res.body.handover).toBeDefined();
    expect(res.body.handover.claimCode).toBeDefined();
    expect(res.body.handover.qrToken).toBeDefined();

    buyerClaimCode = res.body.handover.claimCode;
    buyerQrToken = res.body.handover.qrToken;

    // Verify item is now marked as reserved
    const item = await Item.findById(testItemId);
    expect(item?.status).toBe('reserved');
  });

  it('GET /api/orders/:id - returns order with QR code for buyer', async () => {
    const res = await request(app.callback())
      .get(`/api/orders/${createdOrderId}`)
      .set('Authorization', `Bearer ${buyerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.userRole).toBe('buyer');
    expect(res.body.handover).toBeDefined();
    expect(res.body.handover.qrToken).toBe(buyerQrToken);
  });

  it('POST /api/orders/:id/verify-handover - seller verifies QR/PIN, completes order, and receives payout', async () => {
    const res = await request(app.callback())
      .post(`/api/orders/${createdOrderId}/verify-handover`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({
        qrToken: buyerQrToken,
        claimCode: buyerClaimCode
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.order.status).toBe('completed');
    expect(res.body.transfer).toBeDefined();
    expect(res.body.transfer.amount).toBe(1000); // 1000 cents ($10.00)

    // Verify item is now marked as sold
    const item = await Item.findById(testItemId);
    expect(item?.status).toBe('sold');

    // Verify seller's balance is updated
    const seller = await User.findById(sellerId);
    expect(seller?.sellerBalance).toBe(1000);
    expect(seller?.trustScore).toBeGreaterThanOrEqual(105);
  });

  it('POST /api/users/membership/boost - activates Turbo Boost Seller membership', async () => {
    const res = await request(app.callback())
      .post('/api/users/membership/boost')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ plan: 'monthly' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.membership.isTurboMember).toBe(true);
    expect(res.body.membership.benefits).toContain('Homepage & Search Priority Placement');

    const seller = await User.findById(sellerId);
    expect(seller?.isTurboMember).toBe(true);
  });
});
