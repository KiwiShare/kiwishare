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

    await Item.create([
      {
        sellerId: new mongoose.Types.ObjectId(),
        title: 'Retro Armchair',
        description: 'Comfortable vintage armchair.',
        category: 'Furniture',
        condition: 'good',
        price: 4500,
        currency: 'NZD',
        images: [{ url: 'https://example.com/armchair.jpg', sortOrder: 0 }],
        location: {
          city: 'Auckland',
          suburb: 'Central',
          coordinates: { type: 'Point', coordinates: [174.7633, -36.8485] }
        },
        status: 'active',
        imageUrl: 'https://example.com/armchair.jpg',
        priceNzd: '45',
        isSustainable: true,
        ownerId: 'fixture-owner-1'
      },
      {
        sellerId: new mongoose.Types.ObjectId(),
        title: 'Monstera Deliciosa',
        description: 'Healthy indoor plant.',
        category: 'Plants',
        condition: 'good',
        price: 1500,
        currency: 'NZD',
        images: [{ url: 'https://example.com/plant.jpg', sortOrder: 0 }],
        location: {
          city: 'Wellington',
          suburb: 'Te Aro',
          coordinates: { type: 'Point', coordinates: [174.7762, -41.2865] }
        },
        status: 'active',
        imageUrl: 'https://example.com/plant.jpg',
        priceNzd: '15',
        isSustainable: true,
        ownerId: 'fixture-owner-2'
      }
    ]);
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

  test('POST /api/auth/send-otp and verify-otp flow with rate limiting', async () => {
    const otpEmail = `otp_user_${Date.now()}@kiwishare.co.nz`;

    // 1. Send OTP first time -> success
    const sendRes1 = await request(app.callback())
      .post('/api/auth/send-otp')
      .send({ email: otpEmail });

    expect(sendRes1.status).toBe(200);
    expect(sendRes1.body.status).toBe('success');
    const devCode = sendRes1.body.devCode;
    expect(devCode).toBeDefined();

    // 2. Send OTP second time immediately -> 429 Cooldown
    const sendRes2 = await request(app.callback())
      .post('/api/auth/send-otp')
      .send({ email: otpEmail });

    expect(sendRes2.status).toBe(429);
    expect(sendRes2.body.message).toContain('Please wait');

    // 3. Verify OTP with wrong code -> 401
    const verifyWrong = await request(app.callback())
      .post('/api/auth/verify-otp')
      .send({ email: otpEmail, code: '000000', displayName: 'Kia User' });

    expect(verifyWrong.status).toBe(401);

    // 4. Verify OTP with correct code -> 200 and registers/logs in
    const verifySuccess = await request(app.callback())
      .post('/api/auth/verify-otp')
      .send({ email: otpEmail, code: devCode, displayName: 'Kia User' });

    expect(verifySuccess.status).toBe(200);
    expect(verifySuccess.body.status).toBe('success');
    expect(verifySuccess.body.token).toBeDefined();
    expect(verifySuccess.body.user.displayName).toBe('Kia User');
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
    expect(res.body.every((item: any) =>
      typeof item.latitude === 'number' && typeof item.longitude === 'number'
    )).toBe(true);
  });

  test('GET /api/usedItems/discovery-options - derives filters from MongoDB', async () => {
    const res = await request(app.callback())
      .get('/api/usedItems/discovery-options');

    expect(res.status).toBe(200);
    expect(res.body.categories).toEqual(expect.arrayContaining([
      expect.objectContaining({ value: 'Furniture', count: 1 }),
      expect.objectContaining({ value: 'Plants', count: 1 })
    ]));
    expect(res.body.locations).toEqual(expect.arrayContaining([
      expect.objectContaining({
        value: 'Auckland',
        latitude: expect.any(Number),
        longitude: expect.any(Number)
      })
    ]));
    expect(res.body.priceRange).toEqual({ minimum: 15, maximum: 45 });
  });

  test('GET /api/usedItems - filters and sorts against stored fields', async () => {
    const res = await request(app.callback())
      .get('/api/usedItems')
      .query({
        category: 'Furniture',
        location: 'Auckland',
        minPrice: '40',
        maxPrice: '50',
        sustainable: 'true',
        sort: 'price_asc'
      });

    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].title).toBe('Retro Armchair');
  });

  test('GET /api/listings - does not invent coordinates for legacy records', async () => {
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
    expect(listing.latitude).toBeNull();
    expect(listing.longitude).toBeNull();
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
        location: {
          city: 'Hamilton',
          suburb: 'Hamilton Central',
          latitude: -37.7870,
          longitude: 175.2793
        },
        imageUrl: 'https://images.unsplash.com/photo-1545241047-6083a3684587',
        isSustainable: true,
        category: 'Plants',
        description: 'Eco-friendly garden fertilizer'
      });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('created');
    expect(res.body.item.title).toBe('Organic Fertilizer');
    expect(res.body.item.latitude).toBeCloseTo(-37.7870, 1);
    expect(res.body.item.longitude).toBeCloseTo(175.2793, 1);
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
