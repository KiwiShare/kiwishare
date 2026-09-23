import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import bcrypt from 'bcryptjs';
import app from '../src/app';
import Item from '../src/models/Item';
import User from '../src/models/User';
import Category from '../src/models/Category';
import Order from '../src/models/Order';
import Conversation from '../src/models/Conversation';
import Message from '../src/models/Message';
import { DEFAULT_CATEGORIES } from '../src/config/seed';
import { runMongoTransaction } from '../src/services/mongoTransaction';

jest.mock('../src/config/r2', () => {
  const actual = jest.requireActual('../src/config/r2');
  const config = {
    accountId: 'test-account',
    bucketName: 'kiwishare-test',
    endpoint: 'https://r2.test.invalid',
    accessKeyId: '',
    secretAccessKey: '',
    publicUrlBase: 'https://assets.test.invalid'
  };

  return {
    ...actual,
    R2_CONFIG: config,
    uploadToR2: async (
      _fileBuffer: Buffer,
      fileName: string,
      _contentType: string,
      folder?: unknown
    ) => {
      const root = actual.normalizeR2Folder(folder);
      const key = `${root}/mock-${fileName}`;
      return {
        url: `${config.publicUrlBase}/${key}`,
        key,
        bucket: config.bucketName
      };
    },
    getPresignedUploadUrl: async (
      fileName: string,
      _contentType: string,
      _expiresInSeconds: number,
      folder?: unknown
    ) => {
      const root = actual.normalizeR2Folder(folder);
      const key = `${root}/mock-${fileName}`;
      return {
        uploadUrl: `${config.endpoint}/${config.bucketName}/${key}`,
        publicUrl: `${config.publicUrlBase}/${key}`,
        key
      };
    },
    getR2ObjectStream: async () => {
      throw new Error('Object is not present in the isolated R2 test double.');
    }
  };
});

jest.setTimeout(60000);

function validPublishPayload(overrides: Record<string, unknown> = {}) {
  return {
    title: 'Solid Wood Desk',
    priceNzd: '120.00',
    location: {
      city: 'Auckland',
      suburb: 'Mount Eden',
      latitude: -36.8802,
      longitude: 174.7615
    },
    images: [
      {
        url: 'https://assets.kiwishare.online/test/desk.jpg',
        thumbnailUrl: 'https://assets.kiwishare.online/test/desk-thumb.jpg'
      }
    ],
    isSustainable: true,
    category: 'Furniture',
    condition: 'like_new',
    description: 'A sturdy desk ready for another home.',
    ...overrides
  };
}

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
    expect(res.body.item.ownerId).toBe(userId);
    createdItemId = res.body.item.id;
  });

  test('GET /api/usedItems - exposes a newly published item in discovery', async () => {
    const res = await request(app.callback())
      .get('/api/usedItems')
      .query({ query: 'Organic Fertilizer' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual([
      expect.objectContaining({
        id: createdItemId,
        title: 'Organic Fertilizer',
        ownerId: userId,
        status: 'active'
      })
    ]);
  });

  test('POST /api/usedItems - derives ownership only from the authenticated user', async () => {
    const attemptedOwnerId = new mongoose.Types.ObjectId().toString();
    const res = await request(app.callback())
      .post('/api/usedItems')
      .set('Authorization', `Bearer ${userToken}`)
      .send(validPublishPayload({
        sellerId: attemptedOwnerId,
        targetUserId: attemptedOwnerId,
        targetUserEmail: 'another-user@example.com'
      }));

    expect(res.status).toBe(201);
    expect(res.body.item.ownerId).toBe(userId);
    expect(res.body.item.sellerId).toBe(userId);

    const storedItem = await Item.findById(res.body.item.id);
    expect(storedItem?.ownerId).toBe(userId);
    expect(storedItem?.sellerId.toString()).toBe(userId);
  });

  test('POST /api/usedItems - accepts a manual suburb and city label', async () => {
    const res = await request(app.callback())
      .post('/api/usedItems')
      .set('Authorization', `Bearer ${userToken}`)
      .send(validPublishPayload({ location: 'Te Aro, Wellington' }));

    expect(res.status).toBe(201);
    expect(res.body.item.location).toBe('Te Aro, Wellington');
    expect(res.body.item.latitude).toBeNull();
    expect(res.body.item.longitude).toBeNull();
  });

  test('POST /api/usedItems - keeps the documented imageUrl compatibility field', async () => {
    const imageUrl = 'https://assets.kiwishare.online/test/legacy-photo.jpg';
    const res = await request(app.callback())
      .post('/api/usedItems')
      .set('Authorization', `Bearer ${userToken}`)
      .send(validPublishPayload({ images: [], imageUrl }));

    expect(res.status).toBe(201);
    expect(res.body.item.imageUrl).toBe(imageUrl);
    expect(res.body.item.images).toEqual([
      expect.objectContaining({ url: imageUrl, thumbnailUrl: imageUrl, sortOrder: 0 })
    ]);
  });

  test.each([
    ['missing location', { location: undefined }, 'suburb or city'],
    ['missing images', { images: undefined, imageUrl: undefined }, 'imageUrl'],
    ['too many decimals', { priceNzd: '12.345' }, 'two decimal places'],
    ['invalid condition', { condition: 'excellent' }, 'Condition must be one of'],
    ['blank category', { category: '   ' }, 'Category must be between'],
    ['invalid image URL', { images: [{ url: 'file:///desk.jpg' }] }, 'valid HTTP(S) URL'],
    [
      'too many images',
      { images: Array.from({ length: 11 }, () => ({ url: 'https://example.com/item.jpg' })) },
      'at most 10 images'
    ],
    [
      'incomplete coordinates',
      { location: { city: 'Auckland', latitude: -36.85 } },
      'supplied together'
    ],
    [
      'out-of-range coordinates',
      { location: { city: 'Auckland', latitude: -136.85, longitude: 174.76 } },
      'coordinates are invalid'
    ],
    [
      'empty coordinates',
      { location: { city: 'Auckland', latitude: ' ', longitude: ' ' } },
      'coordinates are invalid'
    ],
    ['overlong title', { title: 'x'.repeat(121) }, 'between 3 and 120'],
    [
      'overlong description',
      { description: 'x'.repeat(2001) },
      'between 0 and 2000'
    ]
  ])('POST /api/usedItems - rejects %s', async (_caseName, overrides, message) => {
    const res = await request(app.callback())
      .post('/api/usedItems')
      .set('Authorization', `Bearer ${userToken}`)
      .send(validPublishPayload(overrides));

    expect(res.status).toBe(400);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toContain(message);
  });

  test('POST /api/usedItems - accepts a valid free item', async () => {
    const res = await request(app.callback())
      .post('/api/usedItems')
      .set('Authorization', `Bearer ${userToken}`)
      .send(validPublishPayload({ priceNzd: '0' }));

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('created');
    expect(res.body.item).toEqual(
      expect.objectContaining({
        price: 0,
        priceNzd: '0',
        isFree: true,
        status: 'active'
      })
    );
  });

  test('POST /api/usedItems - returns a safe server error body', async () => {
    const createSpy = jest
      .spyOn(Item, 'create')
      .mockRejectedValueOnce(new Error('database details must stay private') as never);

    const res = await request(app.callback())
      .post('/api/usedItems')
      .set('Authorization', `Bearer ${userToken}`)
      .send(validPublishPayload());
    createSpy.mockRestore();

    expect(res.status).toBe(500);
    expect(res.body).toEqual({
      status: 'error',
      message: 'Internal Server Error. Please contact support if this persists.'
    });
    expect(JSON.stringify(res.body)).not.toContain('database details');
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
    expect(res.body.status).toBe('active');
    expect(res.body.item.status).toBe('active');
    expect(res.body.id).toBe(res.body.item.id);
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

  test('POST /api/transactions/handover/claim - fails safely on standalone MongoDB', async () => {
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

    expect(res.status).toBe(503);
    expect(res.body.status).toBe('error');
    expect(res.body.message).toContain('transaction-capable MongoDB');
    expect((await Item.findById(itemId))?.status).not.toBe('sold');
  });

  test('Watchlist CRUD - add, list, ids, check, and delete items from watchlist', async () => {
    const watcher = await request(app.callback()).post('/api/auth/register').send({
      email: `watcher_${Date.now()}@kiwishare.co.nz`,
      password: 'password123',
      displayName: 'Watchlist User'
    });
    const watcherToken = watcher.body.token;

    // 1. Check initial watch status
    const checkBefore = await request(app.callback())
      .get(`/api/watchlist/check/${createdItemId}`)
      .set('Authorization', `Bearer ${watcherToken}`);
    expect(checkBefore.status).toBe(200);
    expect(checkBefore.body.isWatched).toBe(false);

    // 2. Add item to watchlist
    const addRes = await request(app.callback())
      .post(`/api/watchlist/${createdItemId}`)
      .set('Authorization', `Bearer ${watcherToken}`);
    expect(addRes.status).toBe(200);
    expect(addRes.body.status).toBe('success');
    expect(addRes.body.isWatched).toBe(true);

    // 3. Verify favouriteCount on Item increased
    const itemAfterAdd = await Item.findById(createdItemId);
    expect(itemAfterAdd?.favouriteCount).toBeGreaterThanOrEqual(1);

    // 4. Retrieve watchlist list
    const listRes = await request(app.callback())
      .get('/api/watchlist')
      .set('Authorization', `Bearer ${watcherToken}`);
    expect(listRes.status).toBe(200);
    expect(listRes.body.status).toBe('success');
    expect(listRes.body.count).toBeGreaterThanOrEqual(1);
    expect(listRes.body.data.some((i: any) => i.id === createdItemId)).toBe(true);

    // 5. Retrieve watchlist IDs array
    const idsRes = await request(app.callback())
      .get('/api/watchlist/ids')
      .set('Authorization', `Bearer ${watcherToken}`);
    expect(idsRes.status).toBe(200);
    expect(idsRes.body.status).toBe('success');
    expect(idsRes.body.itemIds).toContain(createdItemId);

    // 6. Check watch status is now true
    const checkAfter = await request(app.callback())
      .get(`/api/watchlist/check/${createdItemId}`)
      .set('Authorization', `Bearer ${watcherToken}`);
    expect(checkAfter.status).toBe(200);
    expect(checkAfter.body.isWatched).toBe(true);

    // 7. Remove item from watchlist
    const delRes = await request(app.callback())
      .delete(`/api/watchlist/${createdItemId}`)
      .set('Authorization', `Bearer ${watcherToken}`);
    expect(delRes.status).toBe(200);
    expect(delRes.body.status).toBe('success');
    expect(delRes.body.isWatched).toBe(false);

    // 8. Verify status is false again
    const checkFinal = await request(app.callback())
      .get(`/api/watchlist/check/${createdItemId}`)
      .set('Authorization', `Bearer ${watcherToken}`);
    expect(checkFinal.status).toBe(200);
    expect(checkFinal.body.isWatched).toBe(false);
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
    expect(res.body.bucket).toBe('kiwishare-test');
    expect(res.body.key).toMatch(/^images\//);

    // 3. The isolated R2 double deliberately returns no stored object.
    const filename = res.body.key.replace(/^images\//, '');
    const imgGetRes = await request(app.callback()).get(`/api/images/${filename}`);
    expect(imgGetRes.status).toBe(404);
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
    expect(res.body.bucket).toBe('kiwishare-test');
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

  test('POST /api/upload/presign - accepts the controlled audio folder', async () => {
    const res = await request(app.callback())
      .post('/api/upload/presign')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        fileName: 'voice.m4a',
        contentType: 'audio/mp4',
        folder: 'audio/chat'
      });

    expect(res.status).toBe(200);
    expect(res.body.key).toContain('audio/chat/');
    expect(res.body.publicUrl).toContain('audio/chat/');
  });

  test('chat and meetup writes work with the default standalone MongoDB topology', async () => {
    const seller = await request(app.callback())
      .post('/api/auth/register')
      .send({
        email: `standalone_seller_${Date.now()}@kiwishare.co.nz`,
        password: 'password123',
        displayName: 'Standalone Seller'
      });
    expect(seller.status).toBe(201);

    const item = await Item.create({
      sellerId: new mongoose.Types.ObjectId(seller.body.user.id),
      ownerId: seller.body.user.id,
      title: 'Standalone Chat Item',
      description: 'Exercises chat writes without replica-set transactions.',
      category: 'Furniture',
      condition: 'good',
      price: 2500,
      currency: 'NZD',
      status: 'active'
    });
    const conversation = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ itemId: item.id });
    expect(conversation.status).toBe(201);
    const conversationId = conversation.body.conversation.id;

    const sent = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${userToken}`)
      .send({ text: 'Standalone delivery test.' });
    expect(sent.status).toBe(201);

    const read = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${seller.body.token}`)
      .send({ throughMessageId: sent.body.message.id });
    expect(read.status).toBe(200);
    expect(read.body.unreadCount).toBe(0);

    const meetup = await request(app.callback())
      .post('/api/meetups/propose')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        itemId: item.id,
        conversationId,
        scheduledAt: new Date(Date.now() + 86400000).toISOString(),
        locationName: 'UoA Student Hub'
      });
    expect(meetup.status).toBe(200);
    expect(meetup.body.meetup.proposalStatus).toBe('proposed');

    let releaseConfirmationBlocker!: () => void;
    let signalConfirmationBlocker!: () => void;
    const confirmationBlockerStarted = new Promise<void>((resolve) => {
      signalConfirmationBlocker = resolve;
    });
    const confirmationBlocker = new Promise<void>((resolve) => {
      releaseConfirmationBlocker = resolve;
    });
    const blockedConfirmationWork = runMongoTransaction(async () => {
      signalConfirmationBlocker();
      await confirmationBlocker;
    });
    await confirmationBlockerStarted;
    const confirmationMessageFilter = {
      conversationId,
      type: 'meetup',
      text: /^✅ Meetup confirmed:/
    };
    const confirmationsBefore = await Message.countDocuments(confirmationMessageFilter);
    const confirmation = request(app.callback())
      .post(`/api/meetups/${meetup.body.meetup.id}/accept`)
      .set('Authorization', `Bearer ${seller.body.token}`)
      .then((response) => response);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(
      await Message.countDocuments(confirmationMessageFilter)
    ).toBe(confirmationsBefore);
    releaseConfirmationBlocker();
    expect((await confirmation).status).toBe(200);
    await blockedConfirmationWork;
    expect(
      await Message.countDocuments(confirmationMessageFilter)
    ).toBe(confirmationsBefore + 1);

    const sequence: string[] = [];
    let startSecond!: () => void;
    const secondMayStart = new Promise<void>((resolve) => {
      startSecond = resolve;
    });
    let releaseFirst!: () => void;
    const firstMayFinish = new Promise<void>((resolve) => {
      releaseFirst = resolve;
    });
    const first = runMongoTransaction(async (session) => {
      expect(session).toBeNull();
      sequence.push('first-start');
      startSecond();
      await firstMayFinish;
      sequence.push('first-end');
    });
    await secondMayStart;
    const second = runMongoTransaction(async (session) => {
      expect(session).toBeNull();
      sequence.push('second-start');
      sequence.push('second-end');
    });
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(sequence).toEqual(['first-start']);
    releaseFirst();
    await Promise.all([first, second]);
    expect(sequence).toEqual([
      'first-start',
      'first-end',
      'second-start',
      'second-end'
    ]);

    let releaseWatermarkBlocker!: () => void;
    let signalWatermarkBlocker!: () => void;
    const watermarkBlockerStarted = new Promise<void>((resolve) => {
      signalWatermarkBlocker = resolve;
    });
    const watermarkBlocker = new Promise<void>((resolve) => {
      releaseWatermarkBlocker = resolve;
    });
    const blockedWatermarkWork = runMongoTransaction(async () => {
      signalWatermarkBlocker();
      await watermarkBlocker;
    });
    await watermarkBlockerStarted;
    const findMessageSpy = jest.spyOn(Message, 'findOne');
    const legacyRead = request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${seller.body.token}`)
      .then((response) => response);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(findMessageSpy).not.toHaveBeenCalled();
    releaseWatermarkBlocker();
    expect((await legacyRead).status).toBe(200);
    await blockedWatermarkWork;
    findMessageSpy.mockRestore();

    let releasePartialSend!: () => void;
    let signalPartialSend!: () => void;
    const partialSendStarted = new Promise<void>((resolve) => {
      signalPartialSend = resolve;
    });
    const partialSendMayFinish = new Promise<void>((resolve) => {
      releasePartialSend = resolve;
    });
    const originalConversationUpdate =
      Conversation.findByIdAndUpdate.bind(Conversation);
    const conversationUpdateSpy = jest
      .spyOn(Conversation, 'findByIdAndUpdate')
      .mockImplementationOnce((async (...args: any[]) => {
        signalPartialSend();
        await partialSendMayFinish;
        return (originalConversationUpdate as any)(...args);
      }) as any);
    try {
      const partialSend = request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${userToken}`)
        .send({ text: 'Completed after the legacy read request began.' })
        .then((response) => response);
      await partialSendStarted;
      const overlappingLegacyRead = request(app.callback())
        .patch(`/api/conversations/${conversationId}/read`)
        .set('Authorization', `Bearer ${seller.body.token}`)
        .then((response) => response);
      await new Promise((resolve) => setTimeout(resolve, 20));
      releasePartialSend();
      const [sentAfterBoundary, boundedLegacyRead] = await Promise.all([
        partialSend,
        overlappingLegacyRead
      ]);
      expect(sentAfterBoundary.status).toBe(201);
      expect(boundedLegacyRead.status).toBe(200);
      expect(
        (await Message.findById(sentAfterBoundary.body.message.id))?.status
      ).toBe('sent');
    } finally {
      releasePartialSend();
      conversationUpdateSpy.mockRestore();
    }

    const legacyTimestamp = new Date();
    await Conversation.findByIdAndUpdate(conversationId, {
      $set: { lastMessageAt: legacyTimestamp },
      $unset: { lastMessageId: 1 }
    });
    const equalTimeMessage = await Message.create({
      conversationId,
      senderId: new mongoose.Types.ObjectId(userId),
      receiverId: new mongoose.Types.ObjectId(seller.body.user.id),
      type: 'text',
      text: 'Same-millisecond message beyond a legacy boundary.',
      status: 'sent',
      createdAt: legacyTimestamp,
      updatedAt: legacyTimestamp
    });
    const equalTimeRead = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${seller.body.token}`);
    expect(equalTimeRead.status).toBe(200);
    expect((await Message.findById(equalTimeMessage._id))?.status).toBe('sent');

    let releaseRemovalBlocker!: () => void;
    let signalRemovalBlocker!: () => void;
    const removalBlockerStarted = new Promise<void>((resolve) => {
      signalRemovalBlocker = resolve;
    });
    const removalBlocker = new Promise<void>((resolve) => {
      releaseRemovalBlocker = resolve;
    });
    const blockedRemovalWork = runMongoTransaction(async () => {
      signalRemovalBlocker();
      await removalBlocker;
    });
    await removalBlockerStarted;
    const removal = request(app.callback())
      .delete(`/api/conversations/${conversationId}`)
      .set('Authorization', `Bearer ${seller.body.token}`)
      .then((response) => response);
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(
      (await Conversation.findById(conversationId))?.hiddenForUserIds.map(String)
    ).not.toContain(seller.body.user.id);
    releaseRemovalBlocker();
    expect((await removal).status).toBe(200);
    await blockedRemovalWork;
    expect(
      (await Conversation.findById(conversationId))?.hiddenForUserIds.map(String)
    ).toContain(seller.body.user.id);
  });

  describe('Admin Listing Assignment and Stats', () => {
    let adminToken = '';

    beforeAll(async () => {
      const loginRes = await request(app.callback())
        .post('/api/auth/login')
        .send({
          email: 'admin@kiwishare.online',
          password: 'password123'
        });
      adminToken = loginRes.body.token;
    });

    test('POST /api/usedItems - admin can assign listing to another user account', async () => {
      const res = await request(app.callback())
        .post('/api/usedItems')
        .set('Authorization', `Bearer ${adminToken}`)
        .send(validPublishPayload({
          title: 'Admin Assigned Product',
          targetUserEmail: testUser.email
        }));

      expect(res.status).toBe(201);
      expect(res.body.item.ownerId).toBe(userId);
      expect(res.body.item.sellerId).toBe(userId);
      expect(res.body.item.seller?.email).toBe(testUser.email);
    });

    test('POST /api/usedItems - admin assigning to non-existent email returns 400', async () => {
      const res = await request(app.callback())
        .post('/api/usedItems')
        .set('Authorization', `Bearer ${adminToken}`)
        .send(validPublishPayload({
          targetUserEmail: 'nonexistent@example.com'
        }));

      expect(res.status).toBe(400);
      expect(res.body.status).toBe('error');
      expect(res.body.message).toContain('Target user with email');
    });

    test('PATCH /api/admin/items/:id/assign - admin can reassign existing listing', async () => {
      const createRes = await request(app.callback())
        .post('/api/usedItems')
        .set('Authorization', `Bearer ${adminToken}`)
        .send(validPublishPayload({ title: 'Item to Reassign' }));

      const itemId = createRes.body.item.id;

      const assignRes = await request(app.callback())
        .patch(`/api/admin/items/${itemId}/assign`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ targetUserEmail: testUser.email });

      expect(assignRes.status).toBe(200);
      expect(assignRes.body.status).toBe('success');
      expect(assignRes.body.item.ownerId).toBe(userId);
      expect(assignRes.body.item.sellerId).toBe(userId);
    });

    test('GET /api/admin/stats - returns orderStats with GMV and KiwiShare fees', async () => {
      const item = await Item.findOne({ status: 'active' });
      await Order.create({
        orderNumber: 'KS-TEST-001',
        itemId: item?._id,
        buyerId: new mongoose.Types.ObjectId(userId),
        sellerId: item?.sellerId,
        status: 'completed',
        itemSnapshot: { title: item?.title || 'Test Item' },
        currency: 'NZD',
        itemAmount: 10000,
        buyerFeeAmount: 500,
        sellerFeeAmount: 500,
        buyerTotalAmount: 10500,
        sellerReceiveAmount: 9500
      });

      const statsRes = await request(app.callback())
        .get('/api/admin/stats')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(statsRes.status).toBe(200);
      expect(statsRes.body.stats.orderStats).toBeDefined();
      expect(statsRes.body.stats.orderStats.totalOrders).toBeGreaterThanOrEqual(1);
      expect(statsRes.body.stats.orderStats.completedOrders).toBeGreaterThanOrEqual(1);
      expect(parseFloat(statsRes.body.stats.orderStats.totalGmvNzd)).toBeGreaterThanOrEqual(105);
      expect(parseFloat(statsRes.body.stats.orderStats.totalPlatformFeesNzd)).toBeGreaterThanOrEqual(10);
      expect(statsRes.body.stats.orderStats.recentOrders.length).toBeGreaterThanOrEqual(1);
    });
  });
});
