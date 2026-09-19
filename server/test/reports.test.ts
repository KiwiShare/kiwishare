import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import app from '../src/app';
import Conversation from '../src/models/Conversation';
import Item from '../src/models/Item';
import Report from '../src/models/Report';
import { sendReportConfirmationEmail } from '../src/services/reportConfirmationEmail';

jest.mock('../src/services/reportConfirmationEmail', () => ({
  sendReportConfirmationEmail: jest.fn()
}));

const mockedSendReportConfirmationEmail = jest.mocked(sendReportConfirmationEmail);

jest.setTimeout(60000);

describe('KiwiShare report persistence API', () => {
  let mongoServer: MongoMemoryServer;
  let reporterId = '';
  let reportedUserId = '';
  let reporterToken = '';
  let reportedUserToken = '';
  let outsiderToken = '';
  let listingId = '';
  let ownListingId = '';
  let conversationId = '';

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    await mongoose.connect(mongoServer.getUri());
    await Report.init();

    const [reporter, reportedUser, outsider] = await Promise.all([
      request(app.callback()).post('/api/auth/register').send({
        email: 'reporter@example.com',
        password: 'password123',
        displayName: 'Careful Buyer'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'reported-user@example.com',
        password: 'password123',
        displayName: 'Listing Owner'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'report-outsider@example.com',
        password: 'password123',
        displayName: 'Unrelated Member'
      })
    ]);

    reporterId = reporter.body.user.id;
    reportedUserId = reportedUser.body.user.id;
    reporterToken = reporter.body.token;
    reportedUserToken = reportedUser.body.token;
    outsiderToken = outsider.body.token;

    const [listing, ownListing] = await Promise.all([
      Item.create({
        sellerId: new mongoose.Types.ObjectId(reportedUserId),
        ownerId: reportedUserId,
        title: 'Reported test listing',
        description: 'A listing used by the report persistence tests.',
        category: 'Furniture',
        condition: 'good',
        price: 2500,
        currency: 'NZD',
        images: [],
        imageUrl: '',
        priceNzd: '25',
        status: 'active'
      }),
      Item.create({
        sellerId: new mongoose.Types.ObjectId(reporterId),
        ownerId: reporterId,
        title: 'Reporter owned listing',
        description: 'A listing used to verify self-report protection.',
        category: 'Furniture',
        condition: 'good',
        price: 1500,
        currency: 'NZD',
        images: [],
        imageUrl: '',
        priceNzd: '15',
        status: 'active'
      })
    ]);
    listingId = listing._id.toString();
    ownListingId = ownListing._id.toString();

    const conversation = await Conversation.create({
      itemId: listing._id,
      buyerId: new mongoose.Types.ObjectId(reporterId),
      sellerId: new mongoose.Types.ObjectId(reportedUserId),
      status: 'active'
    });
    conversationId = conversation._id.toString();
  });

  beforeEach(async () => {
    await Report.deleteMany({});
    mockedSendReportConfirmationEmail.mockReset();
    mockedSendReportConfirmationEmail.mockResolvedValue(undefined);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  test('requires authentication and stores nothing when it is absent', async () => {
    const response = await request(app.callback()).post('/api/reports').send({
      targetType: 'general',
      contextType: 'general',
      reason: 'other',
      details: 'A sufficiently detailed safety concern.'
    });

    expect(response.status).toBe(401);
    expect(await Report.countDocuments()).toBe(0);
    expect(mockedSendReportConfirmationEmail).not.toHaveBeenCalled();
  });

  test('persists a report with server-owned identity, status, and timestamp', async () => {
    const clientCreatedAt = '2000-01-01T00:00:00.000Z';
    const response = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send({
        targetType: 'general',
        contextType: 'general',
        reason: 'scam_or_fraud',
        details: '  A seller asked for gift cards before meeting.  ',
        reporterId: reportedUserId,
        status: 'closed',
        createdAt: clientCreatedAt
      });

    expect(response.status).toBe(201);
    expect(response.body).toEqual({
      status: 'success',
      report: expect.objectContaining({
        id: expect.any(String),
        reporterId,
        targetType: 'general',
        contextType: 'general',
        reason: 'scam_or_fraud',
        details: 'A seller asked for gift cards before meeting.',
        status: 'pending',
        createdAt: expect.any(String)
      })
    });

    const stored = await Report.findById(response.body.report.id);
    expect(stored).not.toBeNull();
    expect(stored!.reporterId.toString()).toBe(reporterId);
    expect(stored!.status).toBe('pending');
    expect(stored!.details).toBe(
      'A seller asked for gift cards before meeting.'
    );
    expect(stored!.createdAt.toISOString()).not.toBe(clientCreatedAt);
    expect(await Report.countDocuments()).toBe(1);
    expect(mockedSendReportConfirmationEmail).toHaveBeenCalledWith({
      email: 'reporter@example.com',
      displayName: 'Careful Buyer',
      reportId: response.body.report.id,
      submittedAt: expect.any(Date)
    });
  });

  test('persists listing target and context supplied by the mobile form', async () => {
    const response = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send({
        targetType: 'listing',
        targetId: listingId,
        contextType: 'listing',
        contextId: listingId,
        reason: 'misleading_information',
        details: 'The description does not match the item shown in the photos.'
      });

    expect(response.status).toBe(201);
    const stored = await Report.findById(response.body.report.id).lean();
    expect(stored).toEqual(
      expect.objectContaining({
        reporterId: new mongoose.Types.ObjectId(reporterId),
        targetType: 'listing',
        targetId: new mongoose.Types.ObjectId(listingId),
        contextType: 'listing',
        contextId: new mongoose.Types.ObjectId(listingId),
        reason: 'misleading_information',
        status: 'pending'
      })
    );
  });

  test('persists a chat report only when both users belong to the conversation', async () => {
    const response = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send({
        targetType: 'user',
        targetId: reportedUserId,
        contextType: 'chat',
        contextId: conversationId,
        reason: 'harassment_or_abusive_behaviour',
        details: 'The other participant repeatedly sent threatening messages.'
      });

    expect(response.status).toBe(201);
    const stored = await Report.findById(response.body.report.id).lean();
    expect(stored).toEqual(
      expect.objectContaining({
        reporterId: new mongoose.Types.ObjectId(reporterId),
        targetType: 'user',
        targetId: new mongoose.Types.ObjectId(reportedUserId),
        contextType: 'chat',
        contextId: new mongoose.Types.ObjectId(conversationId),
        reason: 'harassment_or_abusive_behaviour',
        status: 'pending'
      })
    );
  });

  test('rejects a chat report from a user outside the conversation', async () => {
    const response = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${outsiderToken}`)
      .send({
        targetType: 'user',
        targetId: reportedUserId,
        contextType: 'chat',
        contextId: conversationId,
        reason: 'other',
        details: 'This report should not be accepted without chat access.'
      });

    expect(response.status).toBe(403);
    expect(response.body.message).toContain('not available');
    expect(await Report.countDocuments()).toBe(0);
  });

  test.each([
    [
      'unknown target type',
      {
        targetType: 'message',
        contextType: 'general',
        reason: 'other',
        details: 'A sufficiently detailed safety concern.'
      }
    ],
    [
      'reason outside the listing catalogue',
      {
        targetType: 'listing',
        targetId: 'listing-id-is-validated-after-reason',
        contextType: 'listing',
        reason: 'harassment_or_abusive_behaviour',
        details: 'A sufficiently detailed safety concern.'
      }
    ],
    [
      'short details',
      {
        targetType: 'general',
        contextType: 'general',
        reason: 'other',
        details: 'Too short'
      }
    ],
    [
      'malformed target id',
      {
        targetType: 'listing',
        targetId: 'not-an-object-id',
        contextType: 'listing',
        reason: 'other',
        details: 'A sufficiently detailed safety concern.'
      }
    ]
  ])('rejects %s without creating a MongoDB document', async (_, payload) => {
    const response = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send(payload);

    expect(response.status).toBe(400);
    expect(await Report.countDocuments()).toBe(0);
  });

  test('rejects reports against the authenticated user or their listing', async () => {
    const ownAccount = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send({
        targetType: 'user',
        targetId: reporterId,
        contextType: 'profile',
        reason: 'other',
        details: 'A sufficiently detailed safety concern.'
      });
    const ownListing = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send({
        targetType: 'listing',
        targetId: ownListingId,
        contextType: 'listing',
        reason: 'other',
        details: 'A sufficiently detailed safety concern.'
      });

    expect(ownAccount.status).toBe(400);
    expect(ownListing.status).toBe(400);
    expect(await Report.countDocuments()).toBe(0);
  });

  async function expectSecondReportRejected(
    firstPayload: Record<string, unknown>,
    secondPayload: Record<string, unknown>,
    targetLabel: 'listing' | 'user'
  ) {
    const first = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send(firstPayload);
    const second = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send(secondPayload);

    expect(first.status).toBe(201);
    expect(second.status).toBe(409);
    expect(second.body.message).toContain(`already reported this ${targetLabel}`);
    expect(await Report.countDocuments()).toBe(1);
    expect(mockedSendReportConfirmationEmail).toHaveBeenCalledTimes(1);
  }

  test('allows one report per reporter and user across reasons and contexts', async () => {
    await expectSecondReportRejected(
      {
        targetType: 'user',
        targetId: reportedUserId,
        contextType: 'profile',
        reason: 'fake_identity_or_impersonation',
        details: 'This profile appears to be impersonating another student.'
      },
      {
        targetType: 'user',
        targetId: reportedUserId,
        contextType: 'chat',
        contextId: conversationId,
        reason: 'harassment_or_abusive_behaviour',
        details: 'The same user later sent an abusive message in our chat.'
      },
      'user'
    );
  });

  test('allows one report per reporter and listing across reasons', async () => {
    await expectSecondReportRejected(
      {
        targetType: 'listing',
        targetId: listingId,
        contextType: 'listing',
        reason: 'misleading_information',
        details: 'The description does not match the item in the photos.'
      },
      {
        targetType: 'listing',
        targetId: listingId,
        contextType: 'listing',
        reason: 'suspected_stolen_item',
        details: 'Changing the reason must not create a second report.'
      },
      'listing'
    );
  });

  test('allows different reporters to report the same user once each', async () => {
    const payload = {
      targetType: 'user',
      targetId: reportedUserId,
      contextType: 'profile',
      reason: 'fake_identity_or_impersonation',
      details: 'This profile appears to be impersonating another student.'
    };

    const responses = await Promise.all([
      request(app.callback())
        .post('/api/reports')
        .set('Authorization', `Bearer ${reporterToken}`)
        .send(payload),
      request(app.callback())
        .post('/api/reports')
        .set('Authorization', `Bearer ${outsiderToken}`)
        .send(payload)
    ]);

    expect(responses.map((response) => response.status)).toEqual([201, 201]);
    expect(await Report.countDocuments()).toBe(2);
    expect(mockedSendReportConfirmationEmail).toHaveBeenCalledTimes(2);
  });

  test('stores only one report when identical requests arrive concurrently', async () => {
    const payload = {
      targetType: 'listing',
      targetId: listingId,
      contextType: 'listing',
      reason: 'misleading_information',
      details: 'The description does not match the item in the photos.'
    };

    const responses = await Promise.all([
      request(app.callback())
        .post('/api/reports')
        .set('Authorization', `Bearer ${reporterToken}`)
        .send(payload),
      request(app.callback())
        .post('/api/reports')
        .set('Authorization', `Bearer ${reporterToken}`)
        .send(payload)
    ]);

    expect(responses.map((response) => response.status).sort()).toEqual([201, 409]);
    expect(await Report.countDocuments()).toBe(1);
    expect(mockedSendReportConfirmationEmail).toHaveBeenCalledTimes(1);
  });

  test('rejects a target that already exists in legacy report data', async () => {
    await Report.create({
      reporterId: new mongoose.Types.ObjectId(reporterId),
      targetType: 'listing',
      targetId: new mongoose.Types.ObjectId(listingId),
      contextType: 'listing',
      contextId: new mongoose.Types.ObjectId(listingId),
      reason: 'misleading_information',
      details: 'A legacy report created before database deduplication was introduced.',
      status: 'pending'
    });

    const response = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send({
        targetType: 'listing',
        targetId: listingId,
        contextType: 'listing',
        reason: 'suspected_stolen_item',
        details: 'This must reuse the existing moderation record.'
      });

    expect(response.status).toBe(409);
    expect(await Report.countDocuments()).toBe(1);
    expect(mockedSendReportConfirmationEmail).not.toHaveBeenCalled();
  });

  test('keeps general safety reports outside target deduplication', async () => {
    const payload = {
      targetType: 'general',
      contextType: 'general',
      reason: 'other',
      details: 'A general safety concern without a specific user or listing.'
    };

    const responses = await Promise.all([
      request(app.callback())
        .post('/api/reports')
        .set('Authorization', `Bearer ${reporterToken}`)
        .send(payload),
      request(app.callback())
        .post('/api/reports')
        .set('Authorization', `Bearer ${reporterToken}`)
        .send(payload)
    ]);

    expect(responses.map((response) => response.status)).toEqual([201, 201]);
    expect(await Report.countDocuments()).toBe(2);
    expect(mockedSendReportConfirmationEmail).toHaveBeenCalledTimes(2);
  });

  test('keeps the saved report when Resend delivery fails', async () => {
    const warning = jest.spyOn(console, 'warn').mockImplementation(() => {});
    mockedSendReportConfirmationEmail.mockRejectedValueOnce(new Error('Email rejected'));

    const response = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reporterToken}`)
      .send({
        targetType: 'general',
        contextType: 'general',
        reason: 'other',
        details: 'A report that remains stored when email delivery is unavailable.'
      });

    expect(response.status).toBe(201);
    expect(await Report.countDocuments()).toBe(1);
    expect(warning).toHaveBeenCalledWith(
      expect.stringContaining('[Report confirmation email]')
    );
    warning.mockRestore();
  });

  test('does not allow a listing owner to report their own listing', async () => {
    const response = await request(app.callback())
      .post('/api/reports')
      .set('Authorization', `Bearer ${reportedUserToken}`)
      .send({
        targetType: 'listing',
        targetId: listingId,
        contextType: 'listing',
        reason: 'other',
        details: 'A sufficiently detailed safety concern.'
      });

    expect(response.status).toBe(400);
    expect(await Report.countDocuments()).toBe(0);
  });
});
