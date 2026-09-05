import request from 'supertest';
import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import app from '../src/app';
import Conversation from '../src/models/Conversation';
import Item from '../src/models/Item';
import Message from '../src/models/Message';
import PushDevice from '../src/models/PushDevice';
import {
  CHAT_PUSH_NOTIFICATION_BODY,
  CHAT_PUSH_NOTIFICATION_TITLE,
  ChatReadReceiptPushPayload,
  ChatPushPayload,
  resolveFirebaseCredentialConfiguration,
  setChatReadReceiptPushGatewayForTests,
  setChatPushGatewayForTests
} from '../src/services/pushNotification';

jest.setTimeout(60000);

async function waitFor(condition: () => boolean | Promise<boolean>, timeoutMs = 2000) {
  const deadline = Date.now() + timeoutMs;
  while (!(await condition())) {
    if (Date.now() >= deadline) throw new Error('Timed out waiting for notification work.');
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

describe('KiwiShare chat push notifications', () => {
  let mongoServer: MongoMemoryReplSet;
  let buyerId = '';
  let sellerId = '';
  let buyerToken = '';
  let sellerToken = '';
  let conversationId = '';

  const buyerDeviceToken = 'buyer-device-token-value-123456789';
  const sellerDeviceToken = 'seller-device-token-value-12345678';

  beforeAll(async () => {
    mongoServer = await MongoMemoryReplSet.create({
      replSet: { count: 1, storageEngine: 'wiredTiger' }
    });
    await mongoose.connect(mongoServer.getUri());

    const [buyerResponse, sellerResponse] = await Promise.all([
      request(app.callback()).post('/api/auth/register').send({
        email: 'push-buyer@example.com',
        password: 'password123',
        displayName: 'Push Buyer'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'push-seller@example.com',
        password: 'password123',
        displayName: 'Push Seller'
      })
    ]);
    buyerId = buyerResponse.body.user.id;
    sellerId = sellerResponse.body.user.id;
    buyerToken = buyerResponse.body.token;
    sellerToken = sellerResponse.body.token;

    const item = await Item.create({
      sellerId: new mongoose.Types.ObjectId(sellerId),
      ownerId: sellerId,
      title: 'Notification Test Chair',
      description: 'Used to test chat push delivery.',
      category: 'Furniture',
      condition: 'good',
      price: 100,
      currency: 'NZD',
      images: [],
      imageUrl: '',
      priceNzd: '1',
      status: 'active'
    });
    const conversation = await Conversation.create({
      itemId: item._id,
      buyerId: new mongoose.Types.ObjectId(buyerId),
      sellerId: new mongoose.Types.ObjectId(sellerId),
      status: 'active'
    });
    conversationId = conversation.id;
  });

  afterEach(async () => {
    setChatPushGatewayForTests(null);
    setChatReadReceiptPushGatewayForTests(null);
    await PushDevice.deleteMany({});
  });

  afterAll(async () => {
    setChatPushGatewayForTests(null);
    setChatReadReceiptPushGatewayForTests(null);
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  test('requires authentication and validates device registrations', async () => {
    const anonymous = await request(app.callback())
      .post('/api/notifications/devices')
      .send({ token: buyerDeviceToken, platform: 'android' });
    const invalid = await request(app.callback())
      .post('/api/notifications/devices')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ token: 'short', platform: 'desktop' });

    expect(anonymous.status).toBe(401);
    expect(invalid.status).toBe(400);
    expect(await PushDevice.countDocuments()).toBe(0);
  });

  test('registers a token idempotently and moves it to the current account', async () => {
    const first = await request(app.callback())
      .post('/api/notifications/devices')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ token: buyerDeviceToken, platform: 'android' });
    const moved = await request(app.callback())
      .post('/api/notifications/devices')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ token: buyerDeviceToken, platform: 'ios' });

    expect(first.status).toBe(200);
    expect(moved.status).toBe(200);
    expect(await PushDevice.countDocuments()).toBe(1);
    const registration = await PushDevice.findOne().select('+token');
    expect(registration?.userId.toString()).toBe(sellerId);
    expect(registration?.platform).toBe('ios');
    expect(registration?.token).toBe(buyerDeviceToken);
  });

  test('only removes a device token owned by the authenticated account', async () => {
    await request(app.callback())
      .post('/api/notifications/devices')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ token: sellerDeviceToken, platform: 'android' });

    const wrongAccount = await request(app.callback())
      .delete('/api/notifications/devices')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ token: sellerDeviceToken });
    expect(wrongAccount.status).toBe(200);
    expect(await PushDevice.countDocuments()).toBe(1);

    const owner = await request(app.callback())
      .delete('/api/notifications/devices')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ token: sellerDeviceToken });
    expect(owner.status).toBe(200);
    expect(await PushDevice.countDocuments()).toBe(0);
  });

  test('allows exact device cleanup with an expired but valid signed session', async () => {
    await PushDevice.create({
      userId: new mongoose.Types.ObjectId(sellerId),
      token: sellerDeviceToken,
      platform: 'android'
    });
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new Error('JWT_SECRET is required by the test setup.');
    const expiredToken = jwt.sign(
      { id: sellerId, email: 'push-seller@example.com' },
      secret,
      { expiresIn: -1 }
    );
    const invalidToken = jwt.sign(
      { id: sellerId, email: 'push-seller@example.com' },
      'not-the-kiwishare-signing-secret',
      { expiresIn: -1 }
    );

    const invalidSignature = await request(app.callback())
      .delete('/api/notifications/devices')
      .set('Authorization', `Bearer ${invalidToken}`)
      .send({ token: sellerDeviceToken });
    expect(invalidSignature.status).toBe(403);
    expect(await PushDevice.countDocuments()).toBe(1);

    const expiredSession = await request(app.callback())
      .delete('/api/notifications/devices')
      .set('Authorization', `Bearer ${expiredToken}`)
      .send({ token: sellerDeviceToken });
    expect({ status: expiredSession.status, body: expiredSession.body }).toEqual({
      status: 200,
      body: { status: 'success' }
    });
    expect(await PushDevice.countDocuments()).toBe(0);
  });

  test('accepts a credential-file deployment without a project ID override', () => {
    expect(
      resolveFirebaseCredentialConfiguration({
        GOOGLE_APPLICATION_CREDENTIALS: '/private/firebase-admin.json'
      })
    ).toEqual({ source: 'application-default' });
  });

  test('uses account-neutral system notification text', () => {
    expect(CHAT_PUSH_NOTIFICATION_TITLE).toBe('New KiwiShare message');
    expect(CHAT_PUSH_NOTIFICATION_BODY).toBe('Open KiwiShare to view it.');
    expect(`${CHAT_PUSH_NOTIFICATION_TITLE} ${CHAT_PUSH_NOTIFICATION_BODY}`)
      .not.toMatch(/sender|seller|buyer|item|chair/i);
  });

  test('notifies only the receiver with privacy-safe chat metadata', async () => {
    await PushDevice.create({
      userId: new mongoose.Types.ObjectId(sellerId),
      token: sellerDeviceToken,
      platform: 'android'
    });
    const deliveries: Array<{ tokens: string[]; payload: ChatPushPayload }> = [];
    setChatPushGatewayForTests({
      async send(tokens, payload) {
        deliveries.push({ tokens, payload });
        return { invalidTokens: [] };
      }
    });

    const sent = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'This private content must not appear in the push payload.' });

    expect(sent.status).toBe(201);
    await waitFor(() => deliveries.length === 1);
    expect(deliveries).toHaveLength(1);
    expect(deliveries[0].tokens).toEqual([sellerDeviceToken]);
    expect(deliveries[0].payload).toEqual(
      expect.objectContaining({
        receiverId: new mongoose.Types.ObjectId(sellerId),
        conversationId,
        senderId: buyerId,
        senderName: 'Push Buyer',
        itemTitle: 'Notification Test Chair',
        messageType: 'text'
      })
    );
    expect(JSON.stringify(deliveries[0])).not.toContain('private content');
  });

  test('cleans invalid tokens without affecting the stored message', async () => {
    await PushDevice.create({
      userId: new mongoose.Types.ObjectId(sellerId),
      token: sellerDeviceToken,
      platform: 'ios'
    });
    setChatPushGatewayForTests({
      async send() {
        return { invalidTokens: [sellerDeviceToken] };
      }
    });

    const sent = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Clean stale registration.' });

    expect(sent.status).toBe(201);
    expect(await Message.findById(sent.body.message.id)).not.toBeNull();
    await waitFor(async () => (await PushDevice.countDocuments()) === 0);
    expect(await PushDevice.countDocuments()).toBe(0);
  });

  test('keeps a message successful when the notification gateway fails', async () => {
    await PushDevice.create({
      userId: new mongoose.Types.ObjectId(sellerId),
      token: sellerDeviceToken,
      platform: 'android'
    });
    setChatPushGatewayForTests({
      async send() {
        throw new Error('Simulated FCM outage');
      }
    });
    const warning = jest.spyOn(console, 'warn').mockImplementation(() => {});

    const sent = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Persist even if push is unavailable.' });

    expect(sent.status).toBe(201);
    expect(await Message.findById(sent.body.message.id)).not.toBeNull();
    await waitFor(() => warning.mock.calls.length > 0);
    expect(warning).toHaveBeenCalledWith(
      '[Push Notification] Chat notification delivery failed.',
      'Simulated FCM outage'
    );
    warning.mockRestore();
  });

  test('notifies the sender once when newly received messages are read', async () => {
    await PushDevice.create({
      userId: new mongoose.Types.ObjectId(buyerId),
      token: buyerDeviceToken,
      platform: 'android'
    });
    const receipts: Array<{
      tokens: string[];
      payload: ChatReadReceiptPushPayload;
    }> = [];
    setChatReadReceiptPushGatewayForTests({
      async send(tokens, payload) {
        receipts.push({ tokens, payload });
        return { invalidTokens: [] };
      }
    });

    const sent = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Read receipt integration test.' });
    expect(sent.status).toBe(201);

    const read = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: sent.body.message.id });
    expect(read.status).toBe(200);
    expect(read.body.readCount).toBeGreaterThanOrEqual(1);
    await waitFor(() => receipts.length === 1);

    expect(receipts).toEqual([
      {
        tokens: [buyerDeviceToken],
        payload: {
          recipientId: new mongoose.Types.ObjectId(buyerId),
          conversationId
        }
      }
    ]);
    expect(JSON.stringify(receipts)).not.toContain('integration test');

    const repeated = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: sent.body.message.id });
    expect(repeated.status).toBe(200);
    expect(repeated.body.readCount).toBe(0);
    expect(receipts).toHaveLength(1);
  });

  test('keeps the read request successful when receipt delivery fails', async () => {
    await PushDevice.create({
      userId: new mongoose.Types.ObjectId(buyerId),
      token: buyerDeviceToken,
      platform: 'android'
    });
    setChatReadReceiptPushGatewayForTests({
      async send() {
        throw new Error('Simulated receipt outage');
      }
    });
    const warning = jest.spyOn(console, 'warn').mockImplementation(() => {});

    const sent = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Persist read state if receipt delivery fails.' });
    expect(sent.status).toBe(201);

    const read = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: sent.body.message.id });
    expect(read.status).toBe(200);
    expect(read.body.readCount).toBeGreaterThanOrEqual(1);
    await waitFor(() => warning.mock.calls.length > 0);
    expect(warning).toHaveBeenCalledWith(
      '[Push Notification] Chat read receipt delivery failed.',
      'Simulated receipt outage'
    );
    warning.mockRestore();
  });
});
