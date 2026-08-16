import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';

import app from '../src/app';
import Item from '../src/models/Item';

jest.setTimeout(60000);

describe('Product detail listing API', () => {
  let mongoServer: MongoMemoryServer;
  let ownerToken: string;
  let otherToken: string;
  let listingId: string;

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    await mongoose.connect(mongoServer.getUri());

    const ownerResponse = await request(app.callback())
      .post('/api/auth/register')
      .send({
        email: 'detail-owner@kiwishare.test',
        password: 'password123',
        displayName: 'Detail Owner'
      });
    ownerToken = ownerResponse.body.token;

    const otherResponse = await request(app.callback())
      .post('/api/auth/register')
      .send({
        email: 'detail-other@kiwishare.test',
        password: 'password123',
        displayName: 'Other Member'
      });
    otherToken = otherResponse.body.token;

    const listingResponse = await request(app.callback())
      .post('/api/listings')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        title: 'Solid Rimu Desk',
        priceNzd: '120',
        location: 'Mt Eden, Auckland',
        imageUrl: 'https://images.example.test/rimu-desk.jpg',
        isSustainable: true,
        category: 'Furniture'
      });
    listingId = listingResponse.body.item.id;
  });

  afterAll(async () => {
    await mongoose.connection.close();
    await mongoServer.stop();
  });

  test('GET /api/listings/:id returns detail and public seller context', async () => {
    const response = await request(app.callback()).get(`/api/listings/${listingId}`);

    expect(response.status).toBe(200);
    expect(response.body).toMatchObject({
      id: listingId,
      title: 'Solid Rimu Desk',
      priceNzd: '120',
      location: 'Mt Eden, Auckland',
      imageUrl: 'https://images.example.test/rimu-desk.jpg',
      imageUrls: ['https://images.example.test/rimu-desk.jpg'],
      ownerId: expect.any(String),
      sellerName: 'Detail Owner',
      status: 'active'
    });
    expect(response.body).not.toHaveProperty('email');
    expect(response.body).not.toHaveProperty('passwordHash');
  });

  test('GET /api/listings/:id returns a safe 404 for invalid identifiers', async () => {
    const response = await request(app.callback()).get('/api/listings/not-an-object-id');

    expect(response.status).toBe(404);
    expect(response.body).toEqual({ status: 'error', message: 'Listing item not found.' });
  });

  test('PUT /api/listings/:id requires authentication', async () => {
    const response = await request(app.callback())
      .put(`/api/listings/${listingId}`)
      .send(validUpdate());

    expect(response.status).toBe(401);
  });

  test('PUT /api/listings/:id rejects a non-owner without changing the item', async () => {
    const response = await request(app.callback())
      .put(`/api/listings/${listingId}`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ ...validUpdate(), title: 'Unauthorized title' });

    expect(response.status).toBe(403);
    const item = await Item.findById(listingId);
    expect(item?.title).toBe('Solid Rimu Desk');
  });

  test('PUT /api/listings/:id validates editable fields', async () => {
    const response = await request(app.callback())
      .put(`/api/listings/${listingId}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ ...validUpdate(), priceNzd: '-1' });

    expect(response.status).toBe(400);
    expect(response.body.message).toBe('Please provide valid listing details.');
  });

  test('PUT /api/listings/:id lets the owner update approved fields only', async () => {
    const response = await request(app.callback())
      .put(`/api/listings/${listingId}`)
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        ...validUpdate(),
        ownerId: 'attacker-controlled-owner',
        status: 'sold',
        viewCount: 999999
      });

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('updated');
    expect(response.body.item).toMatchObject({
      id: listingId,
      title: 'Restored Rimu Desk',
      description: 'Restored locally and ready for a new home.',
      condition: 'good',
      priceNzd: '135.50',
      location: 'Kingsland, Auckland',
      negotiable: true,
      status: 'active'
    });
    expect(response.body.item.ownerId).not.toBe('attacker-controlled-owner');
    expect(response.body.item.viewCount).toBe(0);
  });

  test('DELETE /api/listings/:id rejects a non-owner', async () => {
    const response = await request(app.callback())
      .delete(`/api/listings/${listingId}`)
      .set('Authorization', `Bearer ${otherToken}`);

    expect(response.status).toBe(403);
    expect((await Item.findById(listingId))?.status).toBe('active');
  });

  test('DELETE /api/listings/:id soft-deletes for the owner', async () => {
    const response = await request(app.callback())
      .delete(`/api/listings/${listingId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('deleted');

    const retainedItem = await Item.findById(listingId);
    expect(retainedItem).not.toBeNull();
    expect(retainedItem?.status).toBe('deleted');
    expect(retainedItem?.deletedAt).toBeInstanceOf(Date);

    const detailResponse = await request(app.callback()).get(`/api/listings/${listingId}`);
    expect(detailResponse.status).toBe(404);
  });
});

function validUpdate() {
  return {
    title: 'Restored Rimu Desk',
    description: 'Restored locally and ready for a new home.',
    condition: 'good',
    category: 'Furniture',
    priceNzd: '135.50',
    location: 'Kingsland, Auckland',
    negotiable: true,
    isSustainable: true
  };
}
