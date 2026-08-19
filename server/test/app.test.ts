import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';

jest.setTimeout(60000);

describe('KiwiShare Backend REST Gateway Tests', () => {
  let mongoServer: MongoMemoryServer;

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    const mongoUri = mongoServer.getUri();
    await mongoose.connect(mongoUri);
    
    // Seed initial mock listings
    const { seedInitialData } = require('../src/index');
    await seedInitialData();
  });

  afterAll(async () => {
    await mongoose.connection.close();
    if (mongoServer) {
      await mongoServer.stop();
    }
  });

  let userToken = '';
  let userId = '';
  const testUser = {
    email: `tester_${Date.now()}@kiwishare.co.nz`,
    password: 'password123',
    displayName: 'Test User'
  };

  test('POST /api/auth/register - success registers user', async () => {
    const res = await request(app.callback())
      .post('/api/auth/register')
      .send(testUser);

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('success');
    expect(res.body.token).toBeDefined();
    expect(res.body.user.displayName).toBe(testUser.displayName);
    expect(res.body.user.trustScore).toBe(100);
    userId = res.body.user.id;
  });

  test('POST /api/auth/login - success authenticates user', async () => {
    const res = await request(app.callback())
      .post('/api/auth/login')
      .send({
        email: testUser.email,
        password: testUser.password
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.token).toBeDefined();
    userToken = res.body.token; // Save token for authenticated requests
  });

  test('GET /api/users/me - returns authenticated user profile', async () => {
    const res = await request(app.callback())
      .get('/api/users/me')
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.user.id).toBe(userId);
    expect(res.body.user.displayName).toBe(testUser.displayName);
  });

  test('PATCH /api/users/me - updates user profile', async () => {
    const res = await request(app.callback())
      .patch('/api/users/me')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ displayName: 'Updated User Name' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.user.displayName).toBe('Updated User Name');
  });

  test('GET /api/usedItems - returns used items array', async () => {
    const res = await request(app.callback())
      .get('/api/usedItems');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('GET /api/listings - returns listings array (backwards compatible)', async () => {
    const res = await request(app.callback())
      .get('/api/listings');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('POST /api/usedItems - rejects unauthenticated calls', async () => {
    const res = await request(app.callback())
      .post('/api/usedItems')
      .send({
        title: 'Unauthorized Item',
        priceNzd: '20',
        location: 'Auckland',
        imageUrl: 'https://...',
        isSustainable: true,
        category: 'Plants'
      });

    expect(res.status).toBe(401);
  });

  let createdItemId = '';

  test('POST /api/usedItems - allows authenticated calls to publish item', async () => {
    const res = await request(app.callback())
      .post('/api/usedItems')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        title: 'Organic Fertilizer',
        priceNzd: '12',
        location: 'Hamilton',
        imageUrl: 'https://images.unsplash.com/photo-1545241047-6083a3684587',
        isSustainable: true,
        category: 'Plants',
        description: 'Eco-friendly garden fertilizer'
      });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('created');
    expect(res.body.item.title).toBe('Organic Fertilizer');
    createdItemId = res.body.item.id;
  });

  test('GET /api/usedItems/:id - retrieves specific item details', async () => {
    const res = await request(app.callback())
      .get(`/api/usedItems/${createdItemId}`);

    expect(res.status).toBe(200);
    expect(res.body.id).toBe(createdItemId);
    expect(res.body.title).toBe('Organic Fertilizer');
  });

  test('PATCH /api/usedItems/:id - updates item price and status', async () => {
    const res = await request(app.callback())
      .patch(`/api/usedItems/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`)
      .send({ priceNzd: '10', description: 'Updated discount description' });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.item.priceNzd).toBe('10');
    expect(res.body.item.description).toBe('Updated discount description');
  });

  test('GET /api/users/me/usedItems - returns user created items', async () => {
    const res = await request(app.callback())
      .get('/api/users/me/usedItems')
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.some((it: any) => it.id === createdItemId)).toBe(true);
  });

  test('POST /api/transactions/handover/claim - verifies QR codes and updates ownership', async () => {
    // Publish an item to claim
    const pubRes = await request(app.callback())
      .post('/api/usedItems')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        title: 'Sustainable Backpack',
        priceNzd: '50',
        location: 'Auckland',
        imageUrl: 'https://images.unsplash.com/photo-1545241047-6083a3684587',
        isSustainable: true,
        category: 'Camping'
      });

    const itemId = pubRes.body.item.id;

    // Claim the item using another mock user token
    const clRegister = await request(app.callback())
      .post('/api/auth/register')
      .send({
        email: `claimer_${Date.now()}@kiwishare.co.nz`,
        password: 'password123',
        displayName: 'Claimer User'
      });

    const claimerToken = clRegister.body.token;

    const res = await request(app.callback())
      .post('/api/transactions/handover/claim')
      .set('Authorization', `Bearer ${claimerToken}`)
      .send({
        itemId,
        claimCode: 'QR_HANDOVER_TOKEN_12345'
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.newOwnerId).toBe(clRegister.body.user.id);
  });

  test('DELETE /api/usedItems/:id - deletes item', async () => {
    const res = await request(app.callback())
      .delete(`/api/usedItems/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');

    // Confirm it returns 404 when fetched
    const fetchRes = await request(app.callback()).get(`/api/usedItems/${createdItemId}`);
    expect(fetchRes.status).toBe(404);
  });

  test('GET / - returns homepage status', async () => {
    const res = await request(app.callback()).get('/');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.message).toContain('Server is running');
  });

  test('GET /health - returns OK', async () => {
    const res = await request(app.callback()).get('/health');
    expect(res.status).toBe(200);
    expect(res.text).toBe('OK');
  });
});
