import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import request from 'supertest';

import app from '../src/app';
import { getJwtSecret } from '../src/middleware/auth';
import Item from '../src/models/Item';
import User from '../src/models/User';
import Watchlist from '../src/models/Watchlist';

describe('Watchlist closeout', () => {
  let mongo: MongoMemoryServer;

  beforeAll(async () => {
    mongo = await MongoMemoryServer.create();
    if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
    await mongoose.connect(mongo.getUri());
    await Watchlist.syncIndexes();
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongo.stop();
  });

  beforeEach(async () => {
    await Promise.all([User.deleteMany({}), Item.deleteMany({}), Watchlist.deleteMany({})]);
  });

  const tokenFor = (user: any) => jwt.sign(
    { id: user._id.toString(), email: user.email },
    getJwtSecret(),
    { expiresIn: '1h' }
  );

  async function fixture() {
    const [seller, watcher, other] = await User.create([
      { email: 'seller@watch.test', displayName: 'Seller', authProvider: 'email_otp' },
      { email: 'watcher@watch.test', displayName: 'Watcher', authProvider: 'email_otp' },
      { email: 'other@watch.test', displayName: 'Other', authProvider: 'email_otp' }
    ]);
    const item = await Item.create({
      sellerId: seller._id,
      ownerId: seller._id.toString(),
      title: 'Active chair',
      category: 'Furniture',
      price: 1000,
      priceNzd: '10.00',
      status: 'active',
      favouriteCount: 0
    });
    return { seller, watcher, other, item };
  }

  it('makes duplicate and concurrent adds deterministic and increments once', async () => {
    const { watcher, item } = await fixture();
    const token = tokenFor(watcher);
    const responses = await Promise.all(Array.from({ length: 12 }, () =>
      request(app.callback())
        .post(`/api/watchlist/${item._id}`)
        .set('Authorization', `Bearer ${token}`)
    ));

    expect(responses.every((response) => response.status === 200)).toBe(true);
    expect(await Watchlist.countDocuments({ userId: watcher._id, itemId: item._id })).toBe(1);
    expect((await Item.findById(item._id))?.favouriteCount).toBe(1);
  });

  it('makes repeated removal deterministic and never makes the counter negative', async () => {
    const { watcher, item } = await fixture();
    const token = tokenFor(watcher);
    await request(app.callback()).post(`/api/watchlist/${item._id}`)
      .set('Authorization', `Bearer ${token}`);

    const first = await request(app.callback()).delete(`/api/watchlist/${item._id}`)
      .set('Authorization', `Bearer ${token}`);
    const second = await request(app.callback()).delete(`/api/watchlist/${item._id}`)
      .set('Authorization', `Bearer ${token}`);

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    expect(await Watchlist.countDocuments({ userId: watcher._id })).toBe(0);
    expect((await Item.findById(item._id))?.favouriteCount).toBe(0);
  });

  it.each([
    ['reserved', 409],
    ['sold', 409],
    ['hidden', 409],
    ['deleted', 404]
  ])('rejects an ineligible %s item with a safe response', async (status, expected) => {
    const { watcher, item } = await fixture();
    await Item.updateOne({ _id: item._id }, { $set: { status } });
    const response = await request(app.callback())
      .post(`/api/watchlist/${item._id}`)
      .set('Authorization', `Bearer ${tokenFor(watcher)}`);
    expect(response.status).toBe(expected);
    expect(response.body).not.toHaveProperty('error');
    expect(await Watchlist.countDocuments()).toBe(0);
  });

  it('rejects missing and own items without exposing internal errors', async () => {
    const { seller, watcher, item } = await fixture();
    const own = await request(app.callback()).post(`/api/watchlist/${item._id}`)
      .set('Authorization', `Bearer ${tokenFor(seller)}`);
    const missing = await request(app.callback())
      .post(`/api/watchlist/${new mongoose.Types.ObjectId()}`)
      .set('Authorization', `Bearer ${tokenFor(watcher)}`);
    expect(own.status).toBe(403);
    expect(missing.status).toBe(404);
    expect(own.body).not.toHaveProperty('error');
    expect(missing.body).not.toHaveProperty('error');
  });

  it('keeps Watchlists isolated between accounts', async () => {
    const { watcher, other, item } = await fixture();
    await request(app.callback()).post(`/api/watchlist/${item._id}`)
      .set('Authorization', `Bearer ${tokenFor(watcher)}`);
    const otherList = await request(app.callback()).get('/api/watchlist')
      .set('Authorization', `Bearer ${tokenFor(other)}`);
    expect(otherList.status).toBe(200);
    expect(otherList.body.data).toEqual([]);
  });

  it('paginates newest-first with a deterministic tie-breaker and no gaps', async () => {
    const { seller, watcher } = await fixture();
    const items = await Item.create(Array.from({ length: 7 }, (_, index) => ({
      sellerId: seller._id,
      ownerId: seller._id.toString(),
      title: `Item ${index}`,
      category: 'Other',
      price: 100,
      priceNzd: '1.00',
      status: 'active'
    })));
    const sameTime = new Date('2026-09-01T00:00:00.000Z');
    await Watchlist.collection.insertMany(items.map((item) => ({
      userId: watcher._id,
      itemId: item._id,
      createdAt: sameTime,
      updatedAt: sameTime
    })));
    const token = tokenFor(watcher);
    const collected: string[] = [];
    let cursor: string | undefined;
    do {
      const response = await request(app.callback())
        .get('/api/watchlist')
        .query({ limit: 3, ...(cursor ? { cursor } : {}) })
        .set('Authorization', `Bearer ${token}`);
      expect(response.status).toBe(200);
      expect(response.body.data.length).toBeLessThanOrEqual(3);
      collected.push(...response.body.data.map((entry: any) => entry.id));
      cursor = response.body.pagination.hasMore
        ? response.body.pagination.nextCursor
        : undefined;
    } while (cursor);

    expect(collected).toHaveLength(7);
    expect(new Set(collected).size).toBe(7);
    const expected = items.map((item) => item._id.toString()).sort().reverse();
    expect(collected).toEqual(expected);
  });
});
