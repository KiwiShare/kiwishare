import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import Item from '../src/models/Item';
import QrCode from '../src/models/QrCode';
import Order from '../src/models/Order';

jest.setTimeout(60000);

describe('Meetup Scheduling & QR Code API', () => {
  let mongoServer: MongoMemoryServer;
  let buyerToken = '';
  let sellerToken = '';
  let outsiderToken = '';
  let sellerId = '';
  let itemId = '';
  let conversationId = '';

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
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

    it('accepts the proposed meetup by seller and generates QR handover token', async () => {
      const res = await request(app.callback())
        .post(`/api/meetups/${createdOrderId}/accept`)
        .set('Authorization', `Bearer ${sellerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.meetup.proposalStatus).toBe('confirmed');
      expect(res.body.meetup.qrToken).toBeTruthy();
      expect(res.body.meetup.qrToken).toMatch(/^QR_HANDOVER_TOKEN_/);

      // Verify QR Code document exists and is active
      const qrDoc = await QrCode.findOne({ orderId: createdOrderId });
      expect(qrDoc).toBeDefined();
      expect(qrDoc?.status).toBe('active');
      expect(qrDoc?.tokenHash).toBe(res.body.meetup.qrToken);

      // Verify Order status
      const orderDoc = await Order.findById(createdOrderId);
      expect(orderDoc?.status).toBe('meeting_scheduled');
      expect(orderDoc?.meeting?.proposalStatus).toBe('confirmed');
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
      expect(found.qrToken).toBeTruthy();
    });

    it('retrieves single meetup details via GET /api/meetups/:orderId', async () => {
      const res = await request(app.callback())
        .get(`/api/meetups/${createdOrderId}`)
        .set('Authorization', `Bearer ${buyerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('success');
      expect(res.body.meetup.id).toBe(createdOrderId);
      expect(res.body.meetup.qrToken).toMatch(/^QR_HANDOVER_TOKEN_/);
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

      // Active QR codes are cancelled
      const qrDoc = await QrCode.findOne({ orderId: createdOrderId });
      expect(qrDoc?.status).toBe('cancelled');
    });
  });
});
