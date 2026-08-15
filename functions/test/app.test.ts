import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';

jest.setTimeout(180000);

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

  test('GET /api/listings - returns listings array', async () => {
    const res = await request(app.callback())
      .get('/api/listings');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('GET /api/listings - supports search, category, location and price sorting', async () => {
    const searchRes = await request(app.callback())
      .get('/api/listings')
      .query({ query: 'bike', category: 'Transport', location: 'Auckland' });

    expect(searchRes.status).toBe(200);
    expect(searchRes.body).toHaveLength(1);
    expect(searchRes.body[0].title).toContain('Bike');

    const sortRes = await request(app.callback())
      .get('/api/listings')
      .query({ sort: 'price_asc' });
    const prices = sortRes.body.map((item: any) => Number(item.priceNzd));
    expect(prices).toEqual([...prices].sort((a: number, b: number) => a - b));
  });

  test('GET /api/listings - returns nearby listings with distance', async () => {
    const res = await request(app.callback())
      .get('/api/listings')
      .query({ latitude: -36.8485, longitude: 174.7633, radiusKm: 5, sort: 'nearest' });

    expect(res.status).toBe(200);
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body.every((item: any) => item.distanceKm <= 5)).toBe(true);
    expect(res.body[0].distanceKm).toBeLessThanOrEqual(res.body[res.body.length - 1].distanceKm);
  });

  test('GET /api/listings/:id - returns one listing and handles missing ids', async () => {
    const listRes = await request(app.callback()).get('/api/listings');
    const itemId = listRes.body[0].id;

    const detailRes = await request(app.callback()).get(`/api/listings/${itemId}`);
    expect(detailRes.status).toBe(200);
    expect(detailRes.body.id).toBe(itemId);

    const missingRes = await request(app.callback()).get('/api/listings/not-an-id');
    expect(missingRes.status).toBe(404);
  });

  test('POST /api/listings - rejects unauthenticated calls', async () => {
    const res = await request(app.callback())
      .post('/api/listings')
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

  test('POST /api/listings - allows authenticated calls to publish product', async () => {
    const res = await request(app.callback())
      .post('/api/listings')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        title: 'Organic Fertilizer',
        priceNzd: '12',
        location: 'Hamilton',
        imageUrl: 'https://images.unsplash.com/photo-1545241047-6083a3684587',
        isSustainable: true,
        category: 'Plants'
      });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('created');
    expect(res.body.item.title).toBe('Organic Fertilizer');
  });

  test('POST /api/transactions/handover/claim - verifies QR codes and updates ownership', async () => {
    // Publish an item to claim
    const pubRes = await request(app.callback())
      .post('/api/listings')
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
