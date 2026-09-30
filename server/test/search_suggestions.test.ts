import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';

import app from '../src/app';
import Category from '../src/models/Category';
import Item from '../src/models/Item';
import User from '../src/models/User';

describe('listing search suggestions', () => {
  let mongoServer: MongoMemoryServer;

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
    await mongoose.connect(mongoServer.getUri());
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  beforeEach(async () => {
    await Promise.all([
      User.deleteMany({}),
      Item.deleteMany({}),
      Category.deleteMany({}),
    ]);
  });

  it('returns matching listing titles, categories and locations', async () => {
    const seller = await User.create({
      email: 'seller-search@test.com',
      displayName: 'Search Seller',
      authProvider: 'email_otp',
    });

    await Category.create({
      name: 'Camping',
      slug: 'camping',
      icon: 'Tent',
      sortOrder: 1,
      isActive: true,
    });

    await Item.create([
      {
        sellerId: seller._id,
        ownerId: seller._id.toString(),
        title: 'Camping Stove',
        description: 'Compact stove for weekend trips',
        category: 'Camping',
        price: 3500,
        priceNzd: '35.00',
        location: { city: 'Auckland', suburb: 'Mount Eden' },
        status: 'active',
        imageUrl: '',
        images: [],
      },
      {
        sellerId: seller._id,
        ownerId: seller._id.toString(),
        title: 'Tent - 2 Person',
        description: 'Lightweight camping tent',
        category: 'Camping',
        price: 6500,
        priceNzd: '65.00',
        location: { city: 'Christchurch', suburb: 'Riccarton' },
        status: 'active',
        imageUrl: '',
        images: [],
      },
      {
        sellerId: seller._id,
        ownerId: seller._id.toString(),
        title: 'Road Bike',
        category: 'Transport',
        price: 12000,
        priceNzd: '120.00',
        location: { city: 'Hamilton' },
        status: 'active',
        imageUrl: '',
        images: [],
      },
    ]);

    const response = await request(app.callback()).get(
      '/api/usedItems/search-suggestions?query=camp&limit=10',
    );

    expect(response.status).toBe(200);
    expect(response.body.suggestions).toEqual(
      expect.arrayContaining(['Camping Stove', 'Camping']),
    );
    expect(response.body.suggestions).not.toContain('Road Bike');
  });

  it('never returns inactive listings and respects the limit', async () => {
    const seller = await User.create({
      email: 'seller-limit@test.com',
      displayName: 'Limit Seller',
      authProvider: 'email_otp',
    });

    await Item.create([
      {
        sellerId: seller._id,
        ownerId: seller._id.toString(),
        title: 'Desk Lamp',
        category: 'Home',
        price: 2000,
        priceNzd: '20.00',
        location: { city: 'Auckland' },
        status: 'active',
        imageUrl: '',
        images: [],
      },
      {
        sellerId: seller._id,
        ownerId: seller._id.toString(),
        title: 'Desk Chair',
        category: 'Furniture',
        price: 4500,
        priceNzd: '45.00',
        location: { city: 'Auckland' },
        status: 'sold',
        imageUrl: '',
        images: [],
      },
    ]);

    const response = await request(app.callback()).get(
      '/api/usedItems/search-suggestions?query=desk&limit=1',
    );

    expect(response.status).toBe(200);
    expect(response.body.suggestions).toHaveLength(1);
    expect(response.body.suggestions[0]).toBe('Desk Lamp');
  });
});
