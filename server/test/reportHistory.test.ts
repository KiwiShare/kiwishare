import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import request from 'supertest';

import app from '../src/app';
import Report from '../src/models/Report';
import User from '../src/models/User';

jest.setTimeout(60000);

describe('Report history', () => {
  let mongoServer: MongoMemoryServer;
  let reporterId: mongoose.Types.ObjectId;
  let otherUserId: mongoose.Types.ObjectId;
  let reporterToken: string;

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    await mongoose.connect(mongoServer.getUri());
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  beforeEach(async () => {
    await Promise.all([Report.deleteMany({}), User.deleteMany({})]);
    const [reporter, otherUser] = await User.create([
      {
        email: 'report-history@example.com',
        displayName: 'Report History Member',
      },
      {
        email: 'other-history@example.com',
        displayName: 'Other Member',
      },
    ]);
    reporterId = reporter._id;
    otherUserId = otherUser._id;
    reporterToken = jwt.sign(
      { id: reporterId.toString(), email: reporter.email },
      process.env.JWT_SECRET!,
    );
  });

  test('returns every report owned by the authenticated member newest first', async () => {
    const older = new Date('2026-08-18T02:00:00.000Z');
    const newer = new Date('2026-09-14T01:00:00.000Z');
    await Report.create([
      {
        reporterId,
        targetType: 'general',
        contextType: 'general',
        reason: 'other',
        details: 'This is the older safety concern.',
        status: 'reviewed',
        createdAt: older,
      },
      {
        reporterId,
        targetType: 'user',
        targetId: otherUserId.toString(),
        contextType: 'profile',
        reason: 'scam_or_fraud',
        details: 'This is the latest member concern.',
        status: 'pending',
        createdAt: newer,
      },
      {
        reporterId: otherUserId,
        targetType: 'general',
        contextType: 'general',
        reason: 'other',
        details: 'This belongs to a different member.',
        status: 'pending',
        createdAt: new Date('2026-09-14T03:00:00.000Z'),
      },
    ]);

    const response = await request(app.callback())
      .get('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`);

    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body.reports).toHaveLength(2);
    expect(response.body.reports.map((report: any) => report.details)).toEqual([
      'This is the latest member concern.',
      'This is the older safety concern.',
    ]);
    expect(response.body.reports[0]).toMatchObject({
      targetType: 'user',
      contextType: 'profile',
      reason: 'scam_or_fraud',
      status: 'pending',
      createdAt: newer.toISOString(),
    });
    expect(response.body.reports[0]).not.toHaveProperty('reporterId');
    expect(response.body.reports[0]).not.toHaveProperty('targetId');
    expect(response.body.reports[0]).not.toHaveProperty('contextId');
  });

  test('returns an honest empty history for a member with no reports', async () => {
    const response = await request(app.callback())
      .get('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`);

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'success', reports: [] });
  });

  test('does not expose report history without a current account session', async () => {
    await request(app.callback()).get('/api/reports').expect(401);

    await User.findByIdAndDelete(reporterId);
    const deletedAccount = await request(app.callback())
      .get('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`);

    expect(deletedAccount.status).toBe(401);
    expect(deletedAccount.body.message).toBe('Please sign in again.');
  });
});
