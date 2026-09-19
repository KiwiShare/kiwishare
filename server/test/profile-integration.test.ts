import request from 'supertest';
import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import User from '../src/models/User';
import Item from '../src/models/Item';
import Report from '../src/models/Report';
import Otp from '../src/models/Otp';

jest.setTimeout(60000);

describe('Profile database integration', () => {
  let mongo: MongoMemoryServer;
  let token: string;
  let userId: string;
  beforeAll(async () => {
    mongo = await MongoMemoryServer.create();
    await mongoose.connect(mongo.getUri());
  });
  afterAll(async () => {
    await mongoose.disconnect();
    if (mongo) await mongo.stop();
  });
  beforeEach(async () => {
    await Promise.all([User.deleteMany({}), Item.deleteMany({}), Report.deleteMany({}), Otp.deleteMany({})]);
    const user = await User.create({ email: 'profile@example.com', displayName: 'Jenny', trustScore: 87 });
    userId = user.id;
    token = jwt.sign({ id: userId }, process.env.JWT_SECRET!);
  });

  test('profile edits persist, default avatar clears, trust score remains server-owned', async () => {
    const edit = await request(app.callback()).patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ displayName: ' Jenny Yin ', avatarUrl: 'https://example.com/avatar.jpg', trustScore: 100 });
    expect(edit.status).toBe(200);
    const read = await request(app.callback()).get('/api/users/me').set('Authorization', `Bearer ${token}`);
    expect(read.body.user).toMatchObject({ displayName: 'Jenny Yin', trustScore: 87, avatarUrl: 'https://example.com/avatar.jpg' });
    await request(app.callback()).patch('/api/users/me').set('Authorization', `Bearer ${token}`).send({ avatarUrl: '' }).expect(200);
    expect((await User.findById(userId)).avatarUrl).toBeNull();
  });

  test.each([{ displayName: ' ' }, { displayName: 42 }, { avatarUrl: 'javascript:alert(1)' }])(
    'rejects invalid profile edits: %j', async (body) => {
      await request(app.callback()).patch('/api/users/me').set('Authorization', `Bearer ${token}`).send(body).expect(400);
      expect((await User.findById(userId)).displayName).toBe('Jenny');
    });

  test('report is stored with authenticated ownership, not client-supplied ownership/status', async () => {
    const response = await request(app.callback()).post('/api/reports').set('Authorization', `Bearer ${token}`)
      .send({ targetType: 'general', contextType: 'general', reason: 'other',
        details: 'A suspicious payment request.', reporterId: new mongoose.Types.ObjectId(), status: 'reviewed' });
    expect(response.status).toBe(201);
    const saved = await Report.findById(response.body.report.id);
    expect(saved.reporterId.toString()).toBe(userId);
    expect(saved.status).toBe('pending');
    expect(saved.details).toBe('A suspicious payment request.');
    expect((await User.findById(userId)).trustScore).toBe(87);
  });

  test('unauthenticated and invalid reports are not stored', async () => {
    await request(app.callback()).post('/api/reports').send({}).expect(401);
    await request(app.callback()).post('/api/reports').set('Authorization', `Bearer ${token}`).send({
      targetType: 'general', contextType: 'general', reason: 'other', details: 'short'
    }).expect(400);
    expect(await Report.countDocuments()).toBe(0);
  });

  test('selling/sold include only the signed-in seller and the requested statuses', async () => {
    const other = new mongoose.Types.ObjectId();
    for (const [sellerId, status] of [[userId, 'active'], [userId, 'reserved'], [userId, 'sold'], [other, 'active']]) {
      await Item.create({ sellerId, title: `${status} item`, description: 'Test listing',
        category: 'Furniture', condition: 'good', price: 1000, currency: 'NZD', status,
        images: [{ url: 'https://example.com/item.jpg' }], location: { city: 'Auckland' } });
    }
    const selling = await request(app.callback()).get('/api/users/me/usedItems?status=active,reserved').set('Authorization', `Bearer ${token}`);
    expect(selling.status).toBe(200);
    expect(selling.body).toHaveLength(2);
    const sold = await request(app.callback()).get('/api/users/me/usedItems?status=sold').set('Authorization', `Bearer ${token}`);
    expect(sold.body).toHaveLength(1);
    expect(sold.body[0].title).toBe('sold item');
  });

  test('forgotten password reset updates email-password accounts only after code verification', async () => {
    await User.create({
      email: 'reset@example.com',
      displayName: 'Reset User',
      trustScore: 100,
      isVerified: false,
      authProvider: 'email_password',
      passwordHash: await bcrypt.hash('old-password', 12)
    });

    const requestReset = await request(app.callback())
      .post('/api/auth/request-password-reset')
      .send({ email: 'reset@example.com' });
    expect(requestReset.status).toBe(200);
    const otp = await Otp.findOne({ email: 'reset@example.com', purpose: 'password_reset', used: false });
    expect(otp).toBeTruthy();

    await request(app.callback())
      .post('/api/auth/reset-password')
      .send({ email: 'reset@example.com', code: '000000', newPassword: 'new-password' })
      .expect(401);

    await request(app.callback())
      .post('/api/auth/reset-password')
      .send({ email: 'reset@example.com', code: otp!.code, newPassword: 'new-password' })
      .expect(200);

    await request(app.callback())
      .post('/api/auth/login')
      .send({ email: 'reset@example.com', password: 'old-password' })
      .expect(401);
    await request(app.callback())
      .post('/api/auth/login')
      .send({ email: 'reset@example.com', password: 'new-password' })
      .expect(200);
  });

  test('public profile, public items, and public reviews return correct details and bio update works', async () => {
    // 1. Update bio
    const bioRes = await request(app.callback())
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ bio: 'Computer Science student @ UoA • Moving sale' });
    expect(bioRes.status).toBe(200);
    expect(bioRes.body.user.bio).toBe('Computer Science student @ UoA • Moving sale');

    // 2. Add an active item and a sold item
    await Item.create({
      sellerId: new mongoose.Types.ObjectId(userId),
      title: 'Ergonomic Desk Chair',
      description: 'Used for 1 semester',
      category: 'Furniture',
      condition: 'like_new',
      price: 15000,
      priceNzd: '150.00',
      currency: 'NZD',
      status: 'active',
      images: [{ url: 'https://example.com/chair.jpg' }],
      location: { city: 'Auckland', suburb: 'Grafton' }
    });

    await Item.create({
      sellerId: new mongoose.Types.ObjectId(userId),
      title: 'Scientific Calculator',
      description: 'Casio fx-82AU',
      category: 'Electronics',
      condition: 'good',
      price: 2500,
      priceNzd: '25.00',
      currency: 'NZD',
      status: 'sold',
      images: [{ url: 'https://example.com/calc.jpg' }],
      location: { city: 'Auckland', suburb: 'CBD' }
    });

    // 3. Query public profile
    const pubProfile = await request(app.callback()).get(`/api/users/${userId}/public-profile`);
    expect(pubProfile.status).toBe(200);
    expect(pubProfile.body.status).toBe('success');
    expect(pubProfile.body.user).toMatchObject({
      id: userId,
      displayName: 'Jenny',
      bio: 'Computer Science student @ UoA • Moving sale',
      trustScore: 87,
      activeItemsCount: 1,
      soldItemsCount: 1
    });

    // 4. Query public active items
    const pubItems = await request(app.callback()).get(`/api/users/${userId}/public-items?status=active`);
    expect(pubItems.status).toBe(200);
    expect(pubItems.body.items).toHaveLength(1);
    expect(pubItems.body.items[0].title).toBe('Ergonomic Desk Chair');

    // 5. Query public sold items
    const pubSoldItems = await request(app.callback()).get(`/api/users/${userId}/public-items?status=sold`);
    expect(pubSoldItems.status).toBe(200);
    expect(pubSoldItems.body.items).toHaveLength(1);
    expect(pubSoldItems.body.items[0].title).toBe('Scientific Calculator');

    // 6. Post a review
    const reviewer = await User.create({ email: 'buyer@example.com', displayName: 'Liam', trustScore: 90 });
    const reviewerToken = jwt.sign({ id: reviewer.id }, process.env.JWT_SECRET!);

    const reviewRes = await request(app.callback())
      .post(`/api/users/${userId}/reviews`)
      .set('Authorization', `Bearer ${reviewerToken}`)
      .send({
        rating: 5,
        comment: 'Great seller! Desk chair was in perfect shape.',
        tags: ['Punctual', 'Item as described'],
        role: 'buyer',
        itemTitle: 'Ergonomic Desk Chair'
      });
    expect(reviewRes.status).toBe(201);

    // 7. Query reviews
    const pubReviews = await request(app.callback()).get(`/api/users/${userId}/public-reviews`);
    expect(pubReviews.status).toBe(200);
    expect(pubReviews.body.reviews).toHaveLength(1);
    expect(pubReviews.body.reviews[0]).toMatchObject({
      reviewerName: 'Liam',
      rating: 5,
      comment: 'Great seller! Desk chair was in perfect shape.',
      role: 'buyer'
    });
  });
});
