import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import Item from '../src/models/Item';

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
    expect(res.body.every((item: any) =>
      typeof item.latitude === 'number' && typeof item.longitude === 'number'
    )).toBe(true);
  });

  test('GET /api/listings - maps legacy city-only listings approximately', async () => {
    const legacyItem = await Item.create({
      sellerId: new mongoose.Types.ObjectId(),
      title: 'Legacy Dunedin Chair',
      category: 'Furniture',
      price: 2000,
      currency: 'NZD',
      negotiable: false,
      images: [{ url: 'https://example.com/chair.jpg', sortOrder: 0 }],
      location: { city: 'Dunedin', suburb: 'North Dunedin' },
      status: 'active',
      imageUrl: 'https://example.com/chair.jpg',
      priceNzd: '20',
      isSustainable: true,
      ownerId: 'legacy-user'
    });

    const res = await request(app.callback()).get('/api/listings');
    const listing = res.body.find((item: any) => item.id === legacyItem.id);

    expect(listing).toBeDefined();
    expect(listing.latitude).toBeCloseTo(-45.8788, 1);
    expect(listing.longitude).toBeCloseTo(170.5028, 1);
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
    expect(res.body.item.latitude).toBeCloseTo(-37.7870, 1);
    expect(res.body.item.longitude).toBeCloseTo(175.2793, 1);
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
