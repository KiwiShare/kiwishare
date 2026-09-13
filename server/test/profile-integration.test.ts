import request from 'supertest';
import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import User from '../src/models/User';
import Item from '../src/models/Item';
import Report from '../src/models/Report';

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
    await Promise.all([User.deleteMany({}), Item.deleteMany({}), Report.deleteMany({})]);
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
});
