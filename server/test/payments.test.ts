import jwt from 'jsonwebtoken';
import request from 'supertest';
import mongoose from 'mongoose';
import app from '../src/app';
import Order from '../src/models/Order';
import Item from '../src/models/Item';
import User from '../src/models/User';
import Conversation from '../src/models/Conversation';
import { getPlatformFeeSettings } from '../src/models/PlatformSetting';
import { resolveOrderEffectivePriceCents } from '../src/routes/payments';

function generateToken(userId: string, role = 'user', email = 'test@example.com') {
  const secret = process.env.JWT_SECRET || 'kiwishare-dev-jwt-secret-key-2026-safe-and-secure';
  return jwt.sign({ id: userId, email, role }, secret, { expiresIn: '1h' });
}

describe('Payments & Price Synchronization', () => {
  const buyerId = new mongoose.Types.ObjectId().toHexString();
  const sellerId = new mongoose.Types.ObjectId().toHexString();
  const adminId = new mongoose.Types.ObjectId().toHexString();
  const itemId = new mongoose.Types.ObjectId().toHexString();

  beforeAll(async () => {
    // Ensure test users exist if needed
    await User.create([
      {
        _id: buyerId,
        email: 'buyer@example.com',
        displayName: 'Test Buyer',
        role: 'user'
      },
      {
        _id: sellerId,
        email: 'seller@example.com',
        displayName: 'Test Seller',
        role: 'user'
      },
      {
        _id: adminId,
        email: 'admin@example.com',
        displayName: 'Test Admin',
        role: 'admin'
      }
    ]).catch(() => {});
  });

  describe('Fee Configuration API', () => {
    it('GET /api/config/fees returns current fee settings', async () => {
      const res = await request(app.callback()).get('/api/config/fees');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(typeof res.body.data.buyerFeePercent).toBe('number');
      expect(typeof res.body.data.minFeeCents).toBe('number');
    });

    it('PUT /api/admin/settings/fees updates platform fee settings for admin', async () => {
      const token = generateToken(adminId, 'admin', 'admin@example.com');
      const res = await request(app.callback())
        .put('/api/admin/settings/fees')
        .set('Authorization', `Bearer ${token}`)
        .send({ buyerFeePercent: 4.5, minFeeCents: 75 });

      expect(res.status).toBe(200);
      expect(res.body.data.buyerFeePercent).toBe(4.5);
      expect(res.body.data.minFeeCents).toBe(75);

      // Verify persistent setting retrieval
      const settings = await getPlatformFeeSettings();
      expect(settings.buyerFeePercent).toBe(4.5);
      expect(settings.minFeeCents).toBe(75);
    });

    it('PUT /api/admin/settings/fees rejects non-admin users with 403', async () => {
      const token = generateToken(buyerId, 'user', 'buyer@example.com');
      const res = await request(app.callback())
        .put('/api/admin/settings/fees')
        .set('Authorization', `Bearer ${token}`)
        .send({ buyerFeePercent: 10, minFeeCents: 100 });

      expect(res.status).toBe(403);
    });
  });

  describe('resolveOrderEffectivePriceCents', () => {
    it('uses item listing price when no special price exists', async () => {
      const item = await Item.create({
        _id: itemId,
        ownerId: sellerId,
        sellerId: sellerId,
        title: 'Desk Lamp',
        price: 2500, // $25.00 NZD
        priceNzd: '25.00',
        status: 'active'
      }).catch(() => Item.findById(itemId));

      const order = {
        itemId: item._id,
        buyerId: new mongoose.Types.ObjectId(buyerId),
        sellerId: new mongoose.Types.ObjectId(sellerId),
        itemAmount: 3000
      };

      const resolved = await resolveOrderEffectivePriceCents(order);
      expect(resolved).toBe(2500);
    });

    it('overrides item listing price with conversation specialPrice if seller made special offer', async () => {
      const conv = await Conversation.create({
        itemId: itemId,
        buyerId: buyerId,
        sellerId: sellerId,
        status: 'active',
        itemTitle: 'Desk Lamp',
        specialPrice: 18.5 // Seller discounted to $18.50
      });

      const order = {
        itemId: new mongoose.Types.ObjectId(itemId),
        buyerId: new mongoose.Types.ObjectId(buyerId),
        sellerId: new mongoose.Types.ObjectId(sellerId),
        itemAmount: 2500
      };

      const resolved = await resolveOrderEffectivePriceCents(order);
      expect(resolved).toBe(1850); // $18.50 in cents

      await Conversation.findByIdAndDelete(conv._id);
    });
  });

  describe('Payment Intent & Meetup QR Gating', () => {
    it('creates payment intent with dynamic fee calculation and price sync', async () => {
      const order = await Order.create({
        orderNumber: `ORD_TEST_${Date.now()}`,
        itemId: itemId,
        buyerId: buyerId,
        sellerId: sellerId,
        status: 'meeting_scheduled',
        currency: 'NZD',
        itemAmount: 2000,
        buyerFeeAmount: 0,
        sellerFeeAmount: 0,
        buyerTotalAmount: 2000,
        sellerReceiveAmount: 2000
      });

      const buyerToken = generateToken(buyerId, 'user', 'buyer@example.com');
      const res = await request(app.callback())
        .post('/api/payments/create-intent')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ orderId: order._id.toString() });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.data.orderNumber).toBe(order.orderNumber);
      expect(res.body.data.amountCents).toBeGreaterThan(0);

      // Confirm order was saved with fee and item amount
      const updatedOrder = await Order.findById(order._id);
      expect(updatedOrder?.buyerFeeAmount).toBeGreaterThan(0);
      expect(updatedOrder?.buyerTotalAmount).toBe(updatedOrder!.itemAmount + updatedOrder!.buyerFeeAmount);

      await Order.findByIdAndDelete(order._id);
    });

    it('confirms payment, marks order paid, and unlocks dynamic QR token', async () => {
      const order = await Order.create({
        orderNumber: `ORD_CONFIRM_${Date.now()}`,
        itemId: itemId,
        buyerId: buyerId,
        sellerId: sellerId,
        status: 'meeting_scheduled',
        currency: 'NZD',
        itemAmount: 1500,
        buyerFeeAmount: 75,
        buyerTotalAmount: 1575,
        sellerReceiveAmount: 1500
      });

      const buyerToken = generateToken(buyerId, 'user', 'buyer@example.com');
      const res = await request(app.callback())
        .post('/api/payments/confirm')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ orderId: order._id.toString() });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.data.paidAt).toBeDefined();
      expect(res.body.data.qrToken).toMatch(/^QR_HANDOVER_TOKEN_/);

      const confirmedOrder = await Order.findById(order._id);
      expect(confirmedOrder?.paidAt).toBeDefined();

      await Order.findByIdAndDelete(order._id);
    });
  });
});
