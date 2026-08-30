import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';

let mongoServer: MongoMemoryServer;

beforeAll(async () => {
  mongoServer = await MongoMemoryServer.create();
  const uri = mongoServer.getUri();
  await mongoose.connect(uri);
});

afterAll(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

describe('CORS and Preflight Middleware', () => {
  it('handles OPTIONS preflight with custom headers (x-user-id, x-client-platform)', async () => {
    const res = await request(app.callback())
      .options('/api/watchlist/ids?userId=6a8023abbb97b22496a63a9c')
      .set('Origin', 'http://localhost:3000')
      .set('Access-Control-Request-Method', 'GET')
      .set('Access-Control-Request-Headers', 'authorization,content-type,x-client-platform,x-user-id');

    expect(res.status).toBe(204);
    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:3000');
    expect(res.headers['access-control-allow-headers']).toContain('x-user-id');
    expect(res.headers['access-control-allow-headers']).toContain('x-client-platform');
    expect(res.headers['access-control-allow-methods']).toContain('GET');
    expect(res.headers['access-control-allow-methods']).toContain('PATCH');
    expect(res.headers['access-control-allow-credentials']).toBe('true');
  });

  it('handles OPTIONS preflight for orders checkout', async () => {
    const res = await request(app.callback())
      .options('/api/orders/checkout')
      .set('Origin', 'http://localhost:5173')
      .set('Access-Control-Request-Method', 'POST')
      .set('Access-Control-Request-Headers', 'content-type,authorization,x-user-id');

    expect(res.status).toBe(204);
    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:5173');
    expect(res.headers['access-control-allow-headers']).toContain('x-user-id');
  });

  it('returns CORS headers on actual GET requests', async () => {
    const res = await request(app.callback())
      .get('/api/watchlist/ids?userId=6a8023abbb97b22496a63a9c')
      .set('Origin', 'http://localhost:3000');

    expect(res.status).toBe(200);
    expect(res.headers['access-control-allow-origin']).toBe('http://localhost:3000');
  });
});
