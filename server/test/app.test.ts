import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import bcrypt from 'bcryptjs';
import app from '../src/app';
import Item from '../src/models/Item';
import User from '../src/models/User';
import Category from '../src/models/Category';
import { DEFAULT_CATEGORIES } from '../src/config/seed';

jest.setTimeout(60000);

describe('KiwiShare Backend REST Gateway Tests', () => {
  let mongoServer: MongoMemoryServer;

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    const mongoUri = mongoServer.getUri();
    await mongoose.connect(mongoUri);

    // Seed categories and admin user
    await Category.insertMany(DEFAULT_CATEGORIES);
    const passwordHash = await bcrypt.hash('password123', 12);
    await User.create({
      email: 'admin@kiwishare.online',
      displayName: 'Kiwi Admin',
      role: 'admin',
      trustScore: 100,
      isVerified: true,
      authProvider: 'email_password',
      registrationPlatform: 'web',
      lastUsedPlatform: 'web',
      passwordHash
    });

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

  test('POST /api/auth/register - success registers user with web platform header', async () => {
    const res = await request(app.callback())
      .post('/api/auth/register')
      .set('x-client-platform', 'web')
      .send(testUser);

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('success');
    expect(res.body.token).toBeDefined();
    expect(res.body.user.displayName).toBe(testUser.displayName);
    expect(res.body.user.trustScore).toBe(100);
    expect(res.body.user.registrationPlatform).toBe('web');
    expect(res.body.user.lastUsedPlatform).toBe('web');
    userId = res.body.user.id;
  });

  test('POST /api/auth/login - success authenticates user and updates lastUsedPlatform', async () => {
    const res = await request(app.callback())
      .post('/api/auth/login')
      .set('x-client-platform', 'web')
      .send({
        email: testUser.email,
        password: testUser.password
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.token).toBeDefined();
    expect(res.body.user.lastUsedPlatform).toBe('web');
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

  test('GET /api/usedItems/recommended - returns recommended items scored by popularity and sustainability', async () => {
    const res = await request(app.callback())
      .get('/api/usedItems/recommended')
      .query({ limit: '10' });

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
    expect(res.body.length).toBeLessThanOrEqual(10);
    // Sustainable items and items with views/favourites should be included
    expect(res.body.every((item: any) => item.status === 'active')).toBe(true);
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
    expect(res.body.conditions).toEqual(expect.arrayContaining([
      expect.objectContaining({ value: 'good', count: 2 })
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

  test('GET /api/usedItems - does not invent coordinates for legacy records', async () => {
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

    const res = await request(app.callback()).get('/api/usedItems');
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
    expect(res.body.item.id).toBe(createdItemId);
    expect(res.body.item.currency).toBe('NZD');
    expect(res.body.item.seller.displayName).toBe('Updated User Name');
    expect(res.body.item.viewCount).toBeGreaterThanOrEqual(1);
  });

  test('PATCH /api/usedItems/:id - updates owner-editable listing fields', async () => {
    const res = await request(app.callback())
      .patch(`/api/usedItems/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        priceNzd: '10',
        description: 'Updated discount description',
        category: 'Furniture',
        condition: 'refurbished',
        negotiable: true
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.item.priceNzd).toBe('10');
    expect(res.body.item.description).toBe('Updated discount description');
    expect(res.body.item.category).toBe('Furniture');
    expect(res.body.item.condition).toBe('refurbished');
    expect(res.body.item.negotiable).toBe(true);
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

  test('Watchlist CRUD - add, list, ids, check, and delete items from watchlist', async () => {
    // 1. Check initial watch status
    const checkBefore = await request(app.callback())
      .get(`/api/watchlist/check/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(checkBefore.status).toBe(200);
    expect(checkBefore.body.isWatched).toBe(false);

    // 2. Add item to watchlist
    const addRes = await request(app.callback())
      .post(`/api/watchlist/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(addRes.status).toBe(200);
    expect(addRes.body.status).toBe('success');
    expect(addRes.body.isWatched).toBe(true);

    // 3. Verify favouriteCount on Item increased
    const itemAfterAdd = await Item.findById(createdItemId);
    expect(itemAfterAdd?.favouriteCount).toBeGreaterThanOrEqual(1);

    // 4. Retrieve watchlist list
    const listRes = await request(app.callback())
      .get('/api/watchlist')
      .set('Authorization', `Bearer ${userToken}`);
    expect(listRes.status).toBe(200);
    expect(listRes.body.status).toBe('success');
    expect(listRes.body.count).toBeGreaterThanOrEqual(1);
    expect(listRes.body.data.some((i: any) => i.id === createdItemId)).toBe(true);

    // 5. Retrieve watchlist IDs array
    const idsRes = await request(app.callback())
      .get('/api/watchlist/ids')
      .set('Authorization', `Bearer ${userToken}`);
    expect(idsRes.status).toBe(200);
    expect(idsRes.body.status).toBe('success');
    expect(idsRes.body.itemIds).toContain(createdItemId);

    // 6. Check watch status is now true
    const checkAfter = await request(app.callback())
      .get(`/api/watchlist/check/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(checkAfter.status).toBe(200);
    expect(checkAfter.body.isWatched).toBe(true);

    // 7. Remove item from watchlist
    const delRes = await request(app.callback())
      .delete(`/api/watchlist/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(delRes.status).toBe(200);
    expect(delRes.body.status).toBe('success');
    expect(delRes.body.isWatched).toBe(false);

    // 8. Verify status is false again
    const checkFinal = await request(app.callback())
      .get(`/api/watchlist/check/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`);
    expect(checkFinal.status).toBe(200);
    expect(checkFinal.body.isWatched).toBe(false);
  });

  test('DELETE /api/usedItems/:id - soft-deletes the listing', async () => {
    const res = await request(app.callback())
      .delete(`/api/usedItems/${createdItemId}`)
      .set('Authorization', `Bearer ${userToken}`);

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');

    // Confirm it returns 404 when fetched
    const fetchRes = await request(app.callback()).get(`/api/usedItems/${createdItemId}`);
    expect(fetchRes.status).toBe(404);
    const retainedItem = await Item.findById(createdItemId);
    expect(retainedItem).not.toBeNull();
    expect(retainedItem?.status).toBe('deleted');
    expect(retainedItem?.deletedAt).toBeInstanceOf(Date);
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

  test('GET /api/categories - returns seeded and dynamic categories', async () => {
    const res = await request(app.callback()).get('/api/categories');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.categories.length).toBeGreaterThan(0);
    expect(res.body.categories.some((c: any) => c.name === 'Furniture')).toBe(true);
  });

  test('POST /api/categories - allows authenticated users to create category', async () => {
    const res = await request(app.callback())
      .post('/api/categories')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        name: 'Art & Crafts',
        icon: 'Sparkles',
        description: 'Handmade paintings, pottery, and art'
      });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('success');
    expect(res.body.category.slug).toBe('art-crafts');
  });

  test('GET /api/admin/stats and PATCH /api/admin/items/:id/status - admin controls', async () => {
    // 1. Log in as admin
    const adminLoginRes = await request(app.callback())
      .post('/api/auth/login')
      .send({
        email: 'admin@kiwishare.online',
        password: 'password123'
      });

    expect(adminLoginRes.status).toBe(200);
    expect(adminLoginRes.body.user.role).toBe('admin');
    const adminToken = adminLoginRes.body.token;

    // 2. Fetch admin dashboard stats
    const statsRes = await request(app.callback())
      .get('/api/admin/stats')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(statsRes.status).toBe(200);
    expect(statsRes.body.status).toBe('success');
    expect(statsRes.body.stats.totalUsers).toBeGreaterThanOrEqual(1);
    expect(statsRes.body.stats.activeItems).toBeGreaterThanOrEqual(1);
    expect(statsRes.body.stats.platformStats).toBeDefined();

    // 3. Takedown / Revoke an item as admin
    const itemsRes = await request(app.callback()).get('/api/usedItems');
    const itemsList = Array.isArray(itemsRes.body) ? itemsRes.body : itemsRes.body.items;
    const targetItem = itemsList && itemsList[0];
    if (targetItem) {
      const revokeRes = await request(app.callback())
        .patch(`/api/admin/items/${targetItem.id}/status`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ status: 'revoked' });

      expect(revokeRes.status).toBe(200);
      expect(revokeRes.body.item.status).toBe('revoked');
    }
  });

  test('POST /api/upload and GET /api/images/:filename - uploads image to Cloudflare R2 and serves it', async () => {
    // 1. Rejects unauthenticated upload
    const unauthRes = await request(app.callback())
      .post('/api/upload')
      .send({ imageBase64: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==' });
    expect(unauthRes.status).toBe(401);

    // 2. Uploads 1x1 png pixel via base64
    const res = await request(app.callback())
      .post('/api/upload')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        fileName: 'test_pixel.png',
        contentType: 'image/png'
      });

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('success');
    expect(res.body.bucket).toBe('kiwishare');
    expect(res.body.key).toMatch(/^images\//);

    // 3. Fetch the image via /api/images/ (200 when R2 credentials configured, 404 in mock CI)
    const filename = res.body.key.replace(/^images\//, '');
    const imgGetRes = await request(app.callback()).get(`/api/images/${filename}`);
    expect([200, 404]).toContain(imgGetRes.status);
  });

  test('POST /api/upload/presign - generates S3 presigned upload URL for Cloudflare R2', async () => {
    const res = await request(app.callback())
      .post('/api/upload/presign')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        fileName: 'sample.jpg',
        contentType: 'image/jpeg',
        folder: 'test/pr-171'
      });

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('success');
    expect(res.body.bucket).toBe('kiwishare');
    expect(res.body.uploadUrl).toBeDefined();
    expect(res.body.publicUrl).toBeDefined();
    expect(res.body.key).toMatch(/^test\/pr-171\//);
  });

  test('POST /api/upload/presign - rejects unsafe R2 folders', async () => {
    const res = await request(app.callback())
      .post('/api/upload/presign')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        fileName: 'sample.jpg',
        contentType: 'image/jpeg',
        folder: '../production'
      });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toBe('Invalid R2 upload folder.');
  });

  test('POST /api/upload/presign - rejects unapproved R2 folder roots', async () => {
    const res = await request(app.callback())
      .post('/api/upload/presign')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        fileName: 'sample.jpg',
        contentType: 'image/jpeg',
        folder: 'production'
      });

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
  });
});
