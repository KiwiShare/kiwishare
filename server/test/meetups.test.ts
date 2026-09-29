import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import app from '../src/app';
import Item from '../src/models/Item';
import QrCode from '../src/models/QrCode';
import Order from '../src/models/Order';
import Conversation from '../src/models/Conversation';
import Message from '../src/models/Message';

jest.setTimeout(60000);

describe('Meetup Scheduling & QR Code API', () => {
  let mongoServer: MongoMemoryReplSet;
  let buyerToken = '';
  let sellerToken = '';
  let outsiderToken = '';
  let sellerId = '';
  let itemId = '';
  let conversationId = '';

  beforeAll(async () => {
    mongoServer = await MongoMemoryReplSet.create({
      replSet: { count: 1, storageEngine: 'wiredTiger' }
    });
    await mongoose.connect(mongoServer.getUri());

    const registrations = await Promise.all([
      request(app.callback()).post('/api/auth/register').send({
        email: 'meetup-buyer@example.com',
        password: 'password123',
        displayName: 'Meetup Buyer'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'meetup-seller@example.com',
        password: 'password123',
        displayName: 'Meetup Seller'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'meetup-outsider@example.com',
        password: 'password123',
        displayName: 'Meetup Outsider'
      })
    ]);

    const [buyer, seller, outsider] = registrations.map((r) => r.body);
    buyerToken = buyer.token;
    sellerToken = seller.token;
    outsiderToken = outsider.token;
    sellerId = seller.user.id;

    const itemDoc = await Item.create({
      title: 'Ergonomic Desk Chair',
      description: 'Barely used university study chair',
      price: 120,
      category: 'furniture',
      condition: 'like_new',
      status: 'active',
      ownerId: sellerId,
      sellerId: new mongoose.Types.ObjectId(sellerId),
      location: 'Auckland Central',
      imageUrl: 'https://example.com/chair.jpg'
    });
    itemId = itemDoc._id.toString();

    // Initiate conversation between buyer and seller
    const convRes = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ itemId });

    conversationId = convRes.body.conversation.id;
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  describe('Paid-first meetup state machine regression', () => {
    it('reuses the paid order instead of creating a second unpaid order', async () => {
      const item = await Item.create({
        title: 'Paid-first test item',
        description: 'Regression fixture',
        price: 4200,
        category: 'electronics',
        condition: 'good',
        status: 'active',
        ownerId: sellerId,
        sellerId: new mongoose.Types.ObjectId(sellerId),
        location: 'Auckland Central'
      });
      const paidItemId = item._id.toString();

      const convRes = await request(app.callback())
        .post('/api/conversations')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ itemId: paidItemId });
      const paidConversationId = convRes.body.conversation.id;

      const orderRes = await request(app.callback())
        .post('/api/orders')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ itemId: paidItemId });
      expect(orderRes.status).toBe(201);
      const paidOrderId = orderRes.body.order.id;

      await Order.findByIdAndUpdate(paidOrderId, {
        $set: { paidAt: new Date(), status: 'paid' }
      });
      await Item.findByIdAndUpdate(paidItemId, { status: 'sold' });

      const totalBefore = await Order.countDocuments({ itemId: item._id });

      const proposed = await request(app.callback())
        .post('/api/meetups/propose')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          itemId: paidItemId,
          conversationId: paidConversationId,
          scheduledAt: new Date(Date.now() + 86400000).toISOString(),
          locationName: 'Kate Edger Commons'
        });

      expect(proposed.status).toBe(200);
      expect(proposed.body.meetup.id).toBe(paidOrderId);
      expect(proposed.body.meetup.isPaid).toBe(true);
      expect(proposed.body.meetup.isMeetupConfirmed).toBe(false);
      expect(proposed.body.meetup.isHandoverReady).toBe(false);
      expect(proposed.body.meetup.qrToken).toBeNull();
      expect(await Order.countDocuments({ itemId: item._id })).toBe(totalBefore);

      const afterProposal = await Order.findById(paidOrderId);
      expect(afterProposal?.status).toBe('paid');
      expect(afterProposal?.meeting?.proposalStatus).toBe('proposed');

      const accepted = await request(app.callback())
        .post(`/api/meetups/${paidOrderId}/accept`)
        .set('Authorization', `Bearer ${sellerToken}`);

      expect(accepted.status).toBe(200);
      expect(accepted.body.meetup.isPaid).toBe(true);
      expect(accepted.body.meetup.isMeetupConfirmed).toBe(true);
      expect(accepted.body.meetup.isHandoverReady).toBe(true);
      expect(accepted.body.meetup.qrToken).toMatch(/^QR_HANDOVER_TOKEN_/);

      const finalOrder = await Order.findById(paidOrderId);
      expect(finalOrder?.status).toBe('meeting_scheduled');
      expect(finalOrder?.meeting?.proposalStatus).toBe('confirmed');

      const activeQr = await QrCode.findOne({
        orderId: paidOrderId,
        status: 'active'
      });
      expect(activeQr?.tokenHash).toBe(accepted.body.meetup.qrToken);
    });
  });

  describe('Location Chat Messages (Bug #1 Fix)', () => {
    it('sends a location message with name and coordinates', async () => {
      const res = await request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          type: 'location',
          location: {
            name: 'UoA Student Hub',
            latitude: -36.8523,
            longitude: 174.7691
          }
        });

      expect(res.status).toBe(201);
      expect(res.body.status).toBe('created');
      expect(res.body.message.type).toBe('location');
      expect(res.body.message.location).toEqual({
        name: 'UoA Student Hub',
        latitude: -36.8523,
        longitude: 174.7691
      });
      expect(res.body.message.text).toContain('UoA Student Hub');
    });

    it('rejects invalid location payloads', async () => {
      const res = await request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          type: 'location',
          location: { name: 'Invalid', latitude: 'not-a-number', longitude: 100 }
        });

      expect(res.status).toBe(400);
      expect(res.body.message).toContain('Valid latitude and longitude');
    });
  });

  describe('Meetup Proposal and Confirmation Flow', () => {
    let createdOrderId = '';

    it('proposes a meetup from buyer', async () => {
      const scheduledTime = new Date(Date.now() + 86400000).toISOString();
      const res = await request(app.callback())
        .post('/api/meetups/propose')
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          itemId,
          conversationId,
          scheduledAt: scheduledTime,
          locationName: 'Auckland University Library',
          note: 'Meet near entrance'
        });

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.meetup).toBeDefined();
      expect(res.body.meetup.itemTitle).toBe('Ergonomic Desk Chair');
      expect(res.body.meetup.locationName).toBe('Auckland University Library');
      expect(res.body.meetup.proposalStatus).toBe('proposed');
      expect(res.body.meetup.role).toBe('buying');
      expect(res.body.meetup.note).toBe('Meet near entrance');

      createdOrderId = res.body.meetup.id;
      expect(createdOrderId).toBeTruthy();

      // Check that a meetup message was posted in the conversation
      const messagesRes = await request(app.callback())
        .get(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`);

      const meetupMsg = messagesRes.body.messages.find(
        (m: any) => m.type === 'meetup' && m.meetup?.proposalStatus === 'proposed'
      );
      expect(meetupMsg).toBeDefined();
      expect(meetupMsg.meetup.locationName).toBe('Auckland University Library');
    });

    it('keeps unread count consistent during concurrent proposal and read', async () => {
      const history = await request(app.callback())
        .get(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${sellerToken}`);
      const currentWatermark = history.body.messages.at(-1)?.id;
      expect(currentWatermark).toBeTruthy();
      await request(app.callback())
        .patch(`/api/conversations/${conversationId}/read`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ throughMessageId: currentWatermark });

      const [proposal, read] = await Promise.all([
        request(app.callback())
          .post('/api/meetups/propose')
          .set('Authorization', `Bearer ${buyerToken}`)
          .send({
            itemId,
            conversationId,
            scheduledAt: new Date(
              Date.now() + 3 * 24 * 60 * 60 * 1000
            ).toISOString(),
            locationName: 'Auckland University Library'
          }),
        request(app.callback())
          .patch(`/api/conversations/${conversationId}/read`)
          .set('Authorization', `Bearer ${sellerToken}`)
      ]);

      expect(proposal.status).toBe(200);
      expect(read.status).toBe(200);
      const actualUnread = await Message.countDocuments({
        conversationId,
        receiverId: sellerId,
        status: { $in: ['sent', 'delivered'] }
      });
      expect(
        (await Conversation.findById(conversationId))?.sellerUnreadCount
      ).toBe(actualUnread);
    });

    it('accepts an unpaid meetup but keeps handover QR locked', async () => {
      const res = await request(app.callback())
        .post(`/api/meetups/${createdOrderId}/accept`)
        .set('Authorization', `Bearer ${sellerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.meetup.proposalStatus).toBe('confirmed');
      expect(res.body.meetup.isPaid).toBe(false);
      expect(res.body.meetup.isMeetupConfirmed).toBe(true);
      expect(res.body.meetup.isHandoverReady).toBe(false);
      expect(res.body.meetup.qrToken).toBeNull();

      // Unpaid meetup confirmation must not create an active handover QR.
      const qrDoc = await QrCode.findOne({
        orderId: createdOrderId,
        status: 'active'
      });
      expect(qrDoc).toBeNull();

      // Meetup is confirmed, but the order stays pending until payment succeeds.
      const orderDoc = await Order.findById(createdOrderId);
      expect(orderDoc?.status).toBe('pending_payment');
      expect(orderDoc?.meeting?.proposalStatus).toBe('confirmed');

      const directConfirm = await request(app.callback())
        .post(`/api/meetups/${createdOrderId}/confirm-handover`)
        .set('Authorization', `Bearer ${buyerToken}`);
      expect(directConfirm.status).toBe(400);
      expect(directConfirm.body.message).toContain('paid');
    });

    it('retrieves user meetups via GET /api/meetups/my', async () => {
      const res = await request(app.callback())
        .get('/api/meetups/my')
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(Array.isArray(res.body.meetups)).toBe(true);
      expect(res.body.meetups.length).toBeGreaterThanOrEqual(1);

      const found = res.body.meetups.find((m: any) => m.id === createdOrderId);
      expect(found).toBeDefined();
      expect(found.proposalStatus).toBe('confirmed');
      expect(found.isPaid).toBe(false);
      expect(found.isHandoverReady).toBe(false);
      expect(found.qrToken).toBeNull();
    });

    it('retrieves single meetup details via GET /api/meetups/:orderId', async () => {
      const res = await request(app.callback())
        .get(`/api/meetups/${createdOrderId}`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.meetup.id).toBe(createdOrderId);
      expect(res.body.meetup.isHandoverReady).toBe(false);
      expect(res.body.meetup.qrToken).toBeNull();
      expect(res.body.meetup.locationName).toBe('Auckland University Library');
    });

    it('forbids outsider from viewing or accepting meetup', async () => {
      const getRes = await request(app.callback())
        .get(`/api/meetups/${createdOrderId}`)
        .set('Authorization', `Bearer ${outsiderToken}`);

      expect(getRes.status).toBe(403);

      const acceptRes = await request(app.callback())
        .post(`/api/meetups/${createdOrderId}/accept`)
        .set('Authorization', `Bearer ${outsiderToken}`);

      expect(acceptRes.status).toBe(403);
    });

    it('allows declining or cancelling a meetup', async () => {
      const res = await request(app.callback())
        .post(`/api/meetups/${createdOrderId}/decline`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');

      const orderDoc = await Order.findById(createdOrderId);
      expect(orderDoc?.meeting?.proposalStatus).toBe('declined');

      // This flow never unlocked a QR because payment was still pending.
      const qrDoc = await QrCode.findOne({ orderId: createdOrderId });
      expect(qrDoc).toBeNull();
    });
  });
});
