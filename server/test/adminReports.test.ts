import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import request from 'supertest';
import { MongoMemoryReplSet } from 'mongodb-memory-server';

import app from '../src/app';
import Report from '../src/models/Report';
import User from '../src/models/User';

jest.setTimeout(60000);

function token(userId: string, role: 'user' | 'admin') {
  const secret =
    process.env.JWT_SECRET ||
    'kiwishare-jest-only-signing-secret-never-use-outside-tests-2026';
  return jwt.sign(
    { id: userId, email: `${role}@example.com`, role },
    secret,
    { expiresIn: '1h' }
  );
}

describe('Admin report moderation', () => {
  let mongo: MongoMemoryReplSet;
  const adminId = new mongoose.Types.ObjectId();
  const userId = new mongoose.Types.ObjectId();
  const targetId = new mongoose.Types.ObjectId();

  beforeAll(async () => {
    mongo = await MongoMemoryReplSet.create({
      replSet: { count: 1, storageEngine: 'wiredTiger' }
    });
    await mongoose.connect(mongo.getUri());

    await User.create([
      {
        _id: adminId,
        email: 'admin@example.com',
        displayName: 'Admin',
        role: 'admin'
      },
      {
        _id: userId,
        email: 'reporter@example.com',
        displayName: 'Reporter',
        role: 'user'
      }
    ]);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongo.stop();
  });

  beforeEach(async () => {
    await Report.deleteMany({});
  });

  test('ordinary users cannot access mobile report moderation', async () => {
    const response = await request(app.callback())
      .get('/api/admin/reports')
      .set('Authorization', `Bearer ${token(userId.toString(), 'user')}`);

    expect(response.status).toBe(403);
  });

  test('admin can review mobile report content and approve it', async () => {
    const report = await Report.create({
      reporterId: userId,
      targetType: 'user',
      targetId,
      contextType: 'profile',
      contextId: targetId,
      reason: 'harassment_or_abusive_behaviour',
      details: 'Repeated abusive messages were sent after I asked the user to stop.',
      status: 'pending'
    });

    const listResponse = await request(app.callback())
      .get('/api/admin/reports?status=pending')
      .set('Authorization', `Bearer ${token(adminId.toString(), 'admin')}`);

    expect(listResponse.status).toBe(200);
    expect(listResponse.body.count).toBe(1);
    expect(listResponse.body.reports[0]).toMatchObject({
      id: report._id.toString(),
      reporterId: userId.toString(),
      targetType: 'user',
      targetId: targetId.toString(),
      contextType: 'profile',
      contextId: targetId.toString(),
      reason: 'harassment_or_abusive_behaviour',
      details: 'Repeated abusive messages were sent after I asked the user to stop.',
      status: 'pending'
    });

    const approveResponse = await request(app.callback())
      .patch(`/api/admin/reports/${report._id.toString()}/status`)
      .set('Authorization', `Bearer ${token(adminId.toString(), 'admin')}`)
      .send({ status: 'reviewed' });

    expect(approveResponse.status).toBe(200);
    expect(approveResponse.body.message).toBe('Report approved.');
    expect(approveResponse.body.report.status).toBe('reviewed');

    const updated = await Report.findById(report._id);
    expect(updated?.status).toBe('reviewed');
  });

  test('admin moderation rejects unsupported report statuses', async () => {
    const report = await Report.create({
      reporterId: userId,
      targetType: 'general',
      contextType: 'general',
      reason: 'other',
      details: 'This is a general safety concern that needs an administrator review.',
      status: 'pending'
    });

    const response = await request(app.callback())
      .patch(`/api/admin/reports/${report._id.toString()}/status`)
      .set('Authorization', `Bearer ${token(adminId.toString(), 'admin')}`)
      .send({ status: 'approved_forever' });

    expect(response.status).toBe(400);
    expect(response.body.message).toBe('Invalid report status.');
  });
});
