import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import app from '../src/app';
import Conversation from '../src/models/Conversation';
import Item from '../src/models/Item';
import Message from '../src/models/Message';

jest.setTimeout(60000);

describe('KiwiShare per-member chat removal', () => {
  let mongoServer: MongoMemoryReplSet;
  let buyerId = '';
  let sellerId = '';
  let buyerToken = '';
  let sellerToken = '';
  let outsiderToken = '';
  let itemId = '';
  let conversationId = '';

  beforeAll(async () => {
    mongoServer = await MongoMemoryReplSet.create({
      replSet: { count: 1, storageEngine: 'wiredTiger' }
    });
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
    sellerId = seller.user.id;
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

  test('a concurrent bounded read cannot restore unread state after removal', async () => {
    const displayed = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Displayed before removing the seller chat.' });
    const unseen = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Unseen before removing the seller chat.' });
    expect(displayed.status).toBe(201);
    expect(unseen.status).toBe(201);

    let releaseFirstUpdate!: () => void;
    const firstUpdateReleased = new Promise<void>((resolve) => {
      releaseFirstUpdate = resolve;
    });
    let signalFirstUpdate!: () => void;
    const firstUpdateStarted = new Promise<void>((resolve) => {
      signalFirstUpdate = resolve;
    });
    const originalUpdateMany = Message.updateMany.bind(Message);
    const updateSpy = jest
      .spyOn(Message, 'updateMany')
      .mockImplementationOnce((async (...args: any[]) => {
        signalFirstUpdate();
        await firstUpdateReleased;
        return (originalUpdateMany as any)(...args);
      }) as any);

    try {
      const readResponse = request(app.callback())
        .patch(`/api/conversations/${conversationId}/read`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ throughMessageId: displayed.body.message.id })
        .then((response) => response);
      await firstUpdateStarted;

      const removed = await request(app.callback())
        .delete(`/api/conversations/${conversationId}`)
        .set('Authorization', `Bearer ${sellerToken}`);
      expect(removed.status).toBe(200);
      releaseFirstUpdate();
      expect((await readResponse).status).toBe(200);

      const hidden = await Conversation.findById(conversationId);
      expect(hidden?.hiddenForUserIds.map(String)).toContain(sellerId);
      expect(hidden?.sellerUnreadCount).toBe(0);

      const deliveredAfterRemoval = await request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ text: 'Only this message should restore the seller badge.' });
      expect(deliveredAfterRemoval.status).toBe(201);
      const restored = await Conversation.findById(conversationId);
      expect(restored?.hiddenForUserIds.map(String)).not.toContain(sellerId);
      expect(restored?.sellerUnreadCount).toBe(1);
    } finally {
      releaseFirstUpdate();
      updateSpy.mockRestore();
    }
  });
});
