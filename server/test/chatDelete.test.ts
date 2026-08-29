import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import Conversation from '../src/models/Conversation';
import Item from '../src/models/Item';

jest.setTimeout(60000);

describe('KiwiShare per-member chat removal', () => {
  let mongoServer: MongoMemoryServer;
  let buyerId = '';
  let buyerToken = '';
  let sellerToken = '';
  let outsiderToken = '';
  let itemId = '';
  let conversationId = '';

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    await mongoose.connect(mongoServer.getUri());

    const registrations = await Promise.all([
      request(app.callback()).post('/api/auth/register').send({
        email: 'delete-chat-buyer@example.com',
        password: 'password123',
        displayName: 'Delete Chat Buyer'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'delete-chat-seller@example.com',
        password: 'password123',
        displayName: 'Delete Chat Seller'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'delete-chat-outsider@example.com',
        password: 'password123',
        displayName: 'Delete Chat Outsider'
      })
    ]);
    const [buyer, seller, outsider] = registrations.map((res) => res.body);
    buyerId = buyer.user.id;
    buyerToken = buyer.token;
    sellerToken = seller.token;
    outsiderToken = outsider.token;

    const item = await Item.create({
      sellerId: new mongoose.Types.ObjectId(seller.user.id),
      ownerId: seller.user.id,
      title: 'Swipe Delete Test Chair',
      description: 'An isolated test listing for chat removal.',
      category: 'Furniture',
      condition: 'good',
      price: 100,
      currency: 'NZD',
      images: [{ url: 'https://example.com/chair.jpg', sortOrder: 0 }],
      imageUrl: 'https://example.com/chair.jpg',
      priceNzd: '1',
      status: 'active'
    });
    itemId = item.id;

    const created = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ itemId });
    conversationId = created.body.conversation.id;
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  test('prevents an outsider from removing another member conversation', async () => {
    const response = await request(app.callback())
      .delete(`/api/conversations/${conversationId}`)
      .set('Authorization', `Bearer ${outsiderToken}`);

    expect(response.status).toBe(403);
  });

  test('hides only the current member view and restores it after a new message', async () => {
    const removed = await request(app.callback())
      .delete(`/api/conversations/${conversationId}`)
      .set('Authorization', `Bearer ${buyerToken}`);
    expect(removed.status).toBe(200);

    const buyerAfterRemoval = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`);
    const sellerAfterRemoval = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${sellerToken}`);
    expect(buyerAfterRemoval.body.conversations).toEqual([]);
    expect(sellerAfterRemoval.body.conversations).toHaveLength(1);

    const stored = await Conversation.findById(conversationId);
    expect(stored?.hiddenForUserIds.map(String)).toContain(buyerId);

    const reply = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ text: 'This chat should return for the buyer.' });
    expect(reply.status).toBe(201);

    const buyerAfterReply = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`);
    expect(buyerAfterReply.body.conversations).toEqual([
      expect.objectContaining({ id: conversationId, unreadCount: 1 })
    ]);
  });

  test('reopening an item reuses and unhides the existing conversation', async () => {
    await request(app.callback())
      .delete(`/api/conversations/${conversationId}`)
      .set('Authorization', `Bearer ${buyerToken}`);

    const reopened = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ itemId });

    expect(reopened.status).toBe(200);
    expect(reopened.body.conversation.id).toBe(conversationId);
    expect(await Conversation.countDocuments()).toBe(1);
  });
});
