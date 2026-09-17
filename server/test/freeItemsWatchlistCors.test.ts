import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import jwt from 'jsonwebtoken';
import app from '../src/app';
import Item from '../src/models/Item';
import User from '../src/models/User';
import Watchlist from '../src/models/Watchlist';
import { getJwtSecret } from '../src/middleware/auth';
import {
  setWatchlistEmailSenderForTests,
  WatchlistPriceEmailOptions
} from '../src/services/watchlistNotification';
import { setPushGatewayForTests } from '../src/services/pushNotification';

describe('New Features: CORS PATCH, Free ($0) Items, Watchlist Count & Price Drop Email', () => {
  let mongoServer: MongoMemoryServer;
  let sentEmails: WatchlistPriceEmailOptions[] = [];

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    const uri = mongoServer.getUri();
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
    await mongoose.connect(uri);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  beforeEach(async () => {
    sentEmails = [];
    setWatchlistEmailSenderForTests(async (options) => {
      sentEmails.push(options);
    });
    setPushGatewayForTests({
      async sendPriceDrop() {
        return { invalidTokens: [], successCount: 1, failureCount: 0 };
      }
    });

    await User.deleteMany({});
    await Item.deleteMany({});
    await Watchlist.deleteMany({});
  });

  afterEach(() => {
    setWatchlistEmailSenderForTests(null);
  });

  function createAuthToken(user: any): string {
    return jwt.sign({ id: user._id.toString(), email: user.email }, getJwtSecret(), {
      expiresIn: '1h'
    });
  }

  describe('1. CORS Header for PATCH requests', () => {
    it('allows PATCH method in preflight OPTIONS response', async () => {
      const res = await request(app.callback())
        .options('/api/admin/users/dummyid/trust-score')
        .set('Origin', 'http://localhost:5173')
        .set('Access-Control-Request-Method', 'PATCH')
        .set('Access-Control-Request-Headers', 'Content-Type, Authorization');

      expect(res.status).toBe(204);
      expect(res.headers['access-control-allow-methods']).toContain('PATCH');
      expect(res.headers['access-control-allow-origin']).toBe('http://localhost:5173');
    });
  });

  describe('2. Free Items ($0 price support)', () => {
    it('accepts priceNzd: "0" when creating a listing and sets isFree to true', async () => {
      const seller = await User.create({
        email: 'seller_free@test.com',
        displayName: 'Free Seller',
        authProvider: 'email_otp'
      });
      const token = createAuthToken(seller);

      const res = await request(app.callback())
        .post('/api/usedItems')
        .set('Authorization', `Bearer ${token}`)
        .send({
          title: 'Free Chemistry Textbook',
          category: 'Books',
          condition: 'good',
          priceNzd: '0',
          location: 'Auckland City',
          imageUrl: 'https://example.com/book.jpg'
        });

      expect(res.status).toBe(201);
      expect(res.body.status).toBe('created');
      expect(res.body.item.price).toBe(0);
      expect(res.body.item.priceNzd).toBe('0');
      expect(res.body.item.isFree).toBe(true);

      // Verify fetching item by ID returns isFree = true and price = 0
      const getRes = await request(app.callback()).get(`/api/usedItems/${res.body.item.id}`);
      expect(getRes.status).toBe(200);
      expect(getRes.body.item.isFree).toBe(true);
      expect(getRes.body.item.priceNzd).toBe('0');
    });

    it('rejects negative price', async () => {
      const seller = await User.create({
        email: 'seller_neg@test.com',
        displayName: 'Negative Seller',
        authProvider: 'email_otp'
      });
      const token = createAuthToken(seller);

      const res = await request(app.callback())
        .post('/api/usedItems')
        .set('Authorization', `Bearer ${token}`)
        .send({
          title: 'Negative Price Item',
          category: 'Books',
          condition: 'good',
          priceNzd: '-10',
          location: 'Auckland City',
          imageUrl: 'https://example.com/book.jpg'
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toMatch(/non-negative|cannot be negative/);
    });
  });

  describe('3. Watchlist Count Endpoint & Item Detail Count', () => {
    it('returns watchlist count via public endpoint and increments/decrements with watchlist actions', async () => {
      const seller = await User.create({
        email: 'seller_wl@test.com',
        displayName: 'Seller WL',
        authProvider: 'email_otp'
      });
      const watcher1 = await User.create({
        email: 'watcher1@test.com',
        displayName: 'Watcher 1',
        authProvider: 'email_otp'
      });
      const watcher2 = await User.create({
        email: 'watcher2@test.com',
        displayName: 'Watcher 2',
        authProvider: 'email_otp'
      });

      const item = await Item.create({
        sellerId: seller._id,
        title: 'Study Desk',
        category: 'Furniture',
        price: 4500,
        priceNzd: '45.00',
        imageUrl: 'https://example.com/desk.jpg',
        images: [{ url: 'https://example.com/desk.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });

      // Initially count is 0
      const initialCountRes = await request(app.callback()).get(`/api/watchlist/count/${item._id}`);
      expect(initialCountRes.status).toBe(200);
      expect(initialCountRes.body.count).toBe(0);

      // Watcher 1 adds to watchlist
      const token1 = createAuthToken(watcher1);
      await request(app.callback())
        .post(`/api/watchlist/${item._id}`)
        .set('Authorization', `Bearer ${token1}`);

      // Count is now 1
      const count1Res = await request(app.callback()).get(`/api/watchlist/count/${item._id}`);
      expect(count1Res.body.count).toBe(1);

      // Detail endpoint also reflects count 1
      const detailRes = await request(app.callback()).get(`/api/usedItems/${item._id}`);
      expect(detailRes.body.item.watchlistCount).toBe(1);

      // Watcher 2 adds to watchlist
      const token2 = createAuthToken(watcher2);
      await request(app.callback())
        .post(`/api/watchlist/${item._id}`)
        .set('Authorization', `Bearer ${token2}`);

      const count2Res = await request(app.callback()).get(`/api/watchlist/count/${item._id}`);
      expect(count2Res.body.count).toBe(2);

      // Watcher 1 removes from watchlist
      await request(app.callback())
        .delete(`/api/watchlist/${item._id}`)
        .set('Authorization', `Bearer ${token1}`);

      const countAfterRemove = await request(app.callback()).get(`/api/watchlist/count/${item._id}`);
      expect(countAfterRemove.body.count).toBe(1);
    });
  });

  describe('4. Watchlist Price Drop Notification & Email', () => {
    it('sends both push notification and email alert when price drops to free ($0)', async () => {
      const seller = await User.create({
        email: 'seller_notify@test.com',
        displayName: 'Seller Notify',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher_notify@test.com',
        displayName: 'Watcher Person',
        authProvider: 'email_otp'
      });

      const item = await Item.create({
        sellerId: seller._id,
        title: 'Desk Lamp',
        category: 'Furniture',
        price: 3000,
        priceNzd: '30.00',
        imageUrl: 'https://example.com/lamp.jpg',
        images: [{ url: 'https://example.com/lamp.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });

      // Watcher saves item
      await Watchlist.create({ userId: watcher._id, itemId: item._id });

      // Seller updates price from $30.00 to $0 (Free)
      const sellerToken = createAuthToken(seller);
      const updateRes = await request(app.callback())
        .put(`/api/usedItems/${item._id}`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({
          priceNzd: '0'
        });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.item.price).toBe(0);
      expect(updateRes.body.item.isFree).toBe(true);

      // Wait briefly for background dispatch
      for (let i = 0; i < 20; i++) {
        if (sentEmails.length > 0) break;
        await new Promise((resolve) => setTimeout(resolve, 50));
      }

      expect(sentEmails.length).toBe(1);
      expect(sentEmails[0].to).toBe('watcher_notify@test.com');
      expect(sentEmails[0].itemTitle).toBe('Desk Lamp');
      expect(sentEmails[0].oldPriceNzd).toBe('30.00');
      expect(sentEmails[0].newPriceNzd).toBe('0');
      expect(sentEmails[0].newPriceCents).toBe(0);
    });
  });
});
