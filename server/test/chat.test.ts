import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import app from '../src/app';
import Conversation from '../src/models/Conversation';
import Message from '../src/models/Message';
import Item from '../src/models/Item';
import { getR2ObjectBytes, storeImmutableVoiceObject } from '../src/config/r2';
import {
  acquireVoiceProcessingAdmission,
  probeVoiceAudio
} from '../src/services/voiceAudio';

function mp4Box(type: string, payload: Buffer): Buffer {
  const box = Buffer.alloc(8 + payload.length);
  box.writeUInt32BE(box.length, 0);
  box.write(type, 4, 4, 'ascii');
  payload.copy(box, 8);
  return box;
}

function validVoiceMp4(durationMs = 12500): Buffer {
  const movieHeader = Buffer.alloc(20);
  movieHeader.writeUInt32BE(1000, 12);
  movieHeader.writeUInt32BE(durationMs, 16);
  const handler = Buffer.alloc(12);
  handler.write('soun', 8, 4, 'ascii');
  return Buffer.concat([
    mp4Box('ftyp', Buffer.from('M4A \u0000\u0000\u0000\u0000M4A ', 'binary')),
    mp4Box(
      'moov',
      Buffer.concat([
        mp4Box('mvhd', movieHeader),
        mp4Box('trak', mp4Box('mdia', mp4Box('hdlr', handler)))
      ])
    ),
    mp4Box('mdat', Buffer.from([1]))
  ]);
}

jest.mock('../src/config/r2', () => {
  const actual = jest.requireActual('../src/config/r2');
  return {
    ...actual,
    getR2ObjectBytes: jest.fn(async () => ({
      bytes: validVoiceMp4(),
      contentType: 'audio/mp4'
    })),
    storeImmutableVoiceObject: jest.fn(async () => ({
      key: 'audio/messages/immutable.m4a',
      url: 'https://assets.kiwishare.online/audio/messages/immutable.m4a'
    }))
  };
});

jest.mock('../src/services/voiceAudio', () => ({
  acquireVoiceProcessingAdmission: jest.fn(() => ({ release: jest.fn() })),
  probeVoiceAudio: jest.fn(async () => ({
    contentType: 'audio/mp4',
    extension: 'm4a',
    durationMs: 12500
  }))
}));

const mockedGetR2ObjectBytes = jest.mocked(getR2ObjectBytes);
const mockedStoreImmutableVoiceObject = jest.mocked(storeImmutableVoiceObject);
const mockedAcquireVoiceProcessingAdmission = jest.mocked(
  acquireVoiceProcessingAdmission
);
const mockedProbeVoiceAudio = jest.mocked(probeVoiceAudio);

jest.setTimeout(60000);

describe('KiwiShare text chat API', () => {
  let mongoServer: MongoMemoryReplSet;
  let buyerId = '';
  let sellerId = '';
  let buyerToken = '';
  let sellerToken = '';
  let outsiderToken = '';
  let itemId = '';
  let conversationId = '';

  beforeEach(() => {
    mockedGetR2ObjectBytes.mockClear();
    mockedStoreImmutableVoiceObject.mockClear();
    mockedAcquireVoiceProcessingAdmission.mockReset();
    mockedProbeVoiceAudio.mockReset();
    mockedAcquireVoiceProcessingAdmission.mockImplementation(() => ({
      release: jest.fn()
    }));
    mockedGetR2ObjectBytes.mockResolvedValue({
      bytes: validVoiceMp4(),
      contentType: 'audio/mp4'
    });
    mockedStoreImmutableVoiceObject.mockResolvedValue({
      key: 'audio/messages/immutable.m4a',
      url: 'https://assets.kiwishare.online/audio/messages/immutable.m4a'
    });
    mockedProbeVoiceAudio.mockResolvedValue({
      contentType: 'audio/mp4',
      extension: 'm4a',
      durationMs: 12500
    });
  });

  beforeAll(async () => {
    mongoServer = await MongoMemoryReplSet.create({
      replSet: { count: 1, storageEngine: 'wiredTiger' }
    });
    await mongoose.connect(mongoServer.getUri());

    const registrations = await Promise.all([
      request(app.callback()).post('/api/auth/register').send({
        email: 'chat-buyer@example.com',
        password: 'password123',
        displayName: 'Chat Buyer'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'chat-seller@example.com',
        password: 'password123',
        displayName: 'Chat Seller'
      }),
      request(app.callback()).post('/api/auth/register').send({
        email: 'chat-outsider@example.com',
        password: 'password123',
        displayName: 'Chat Outsider'
      })
    ]);
    const [buyer, seller, outsider] = registrations.map((res) => res.body);

    buyerId = buyer.user.id;
    sellerId = seller.user.id;
    buyerToken = buyer.token;
    sellerToken = seller.token;
    outsiderToken = outsider.token;

    const item = await Item.create({
      sellerId: new mongoose.Types.ObjectId(sellerId),
      ownerId: sellerId,
      title: 'Chat Test Desk',
      description: 'An item used by isolated chat integration tests.',
      category: 'Furniture',
      condition: 'good',
      price: 2500,
      currency: 'NZD',
      images: [{ url: 'https://example.com/chat-desk.jpg', sortOrder: 0 }],
      imageUrl: 'https://example.com/chat-desk.jpg',
      priceNzd: '25',
      status: 'active'
    });
    itemId = item._id.toString();
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  test('requires authentication for conversation history', async () => {
    const res = await request(app.callback()).get('/api/conversations');

    expect(res.status).toBe(401);
  });

  test('rejects invalid item identifiers before creating a conversation', async () => {
    const malformed = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ itemId: 'not-an-object-id' });
    const missing = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({});

    expect(malformed.status).toBe(400);
    expect(missing.status).toBe(400);
    expect(await Conversation.countDocuments()).toBe(0);
  });

  test('creates one buyer-seller conversation per item idempotently', async () => {
    const created = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ itemId });

    expect(created.status).toBe(201);
    expect(created.body.status).toBe('created');
    expect(created.body.conversation).toEqual(
      expect.objectContaining({
        direction: 'buying',
        unreadCount: 0,
        item: expect.objectContaining({ id: itemId, title: 'Chat Test Desk' }),
        participant: expect.objectContaining({
          id: sellerId,
          displayName: 'Chat Seller'
        })
      })
    );
    conversationId = created.body.conversation.id;

    const existing = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ itemId });

    expect(existing.status).toBe(200);
    expect(existing.body.conversation.id).toBe(conversationId);
    expect(await Conversation.countDocuments()).toBe(1);
  });

  test('does not allow a seller to start a conversation with themselves', async () => {
    const res = await request(app.callback())
      .post('/api/conversations')
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ itemId });

    expect(res.status).toBe(400);
    expect(res.body.message).toContain('cannot message yourself');
  });

  test('lists only conversations belonging to the authenticated user', async () => {
    const buyer = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`);
    const seller = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${sellerToken}`);
    const outsider = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${outsiderToken}`);

    expect(buyer.status).toBe(200);
    expect(buyer.body.conversations).toEqual([
      expect.objectContaining({ id: conversationId, direction: 'buying' })
    ]);
    expect(seller.body.conversations).toEqual([
      expect.objectContaining({ id: conversationId, direction: 'selling' })
    ]);
    expect(outsider.body.conversations).toEqual([]);
  });

  test('rejects invalid text and prevents outsider access', async () => {
    const empty = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: '   ' });
    const overlong = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'x'.repeat(2001) });
    const outsider = await request(app.callback())
      .get(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${outsiderToken}`);
    const externalImage = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ type: 'image', imageUrl: 'https://example.com/not-r2.jpg' });
    const unsupportedType = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ type: 'video', imageUrl: 'https://assets.kiwishare.online/images/chat/a.jpg' });

    expect(empty.status).toBe(400);
    expect(overlong.status).toBe(400);
    expect(outsider.status).toBe(403);
    expect(externalImage.status).toBe(400);
    expect(unsupportedType.status).toBe(400);
    expect(await Message.countDocuments()).toBe(0);
  });

  test('sanitises accepted text before storing and returning it', async () => {
    const conversationBefore = await Conversation.findById(conversationId);
    const response = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: '  Ｈｅｌｌｏ\u200b\t  seller\r\n  Is this available?  ' });

    expect(response.status).toBe(201);
    expect(response.body.message.text).toBe('Hello seller\nIs this available?');
    expect(
      await Message.findOne({ conversationId, text: 'Hello seller\nIs this available?' })
    ).not.toBeNull();

    await Message.findByIdAndDelete(response.body.message.id);
    await Conversation.findByIdAndUpdate(conversationId, {
      $set: {
        lastMessageText: conversationBefore?.lastMessageText ?? '',
        lastMessageAt: conversationBefore?.lastMessageAt ?? null,
        lastMessageSenderId: conversationBefore?.lastMessageSenderId ?? null,
        buyerUnreadCount: conversationBefore?.buyerUnreadCount ?? 0,
        sellerUnreadCount: conversationBefore?.sellerUnreadCount ?? 0
      }
    });
  });

  test('rejects sensitive content without storing it or changing the preview', async () => {
    const conversationBefore = await Conversation.findById(conversationId);
    const messageCountBefore = await Message.countDocuments({ conversationId });

    const response = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'This contains F.U_C K obfuscation.' });

    const conversationAfter = await Conversation.findById(conversationId);
    expect(response.status).toBe(422);
    expect(response.body).toEqual({
      status: 'error',
      code: 'MESSAGE_CONTENT_NOT_ALLOWED',
      message:
        'Your message contains language that is not allowed. Please edit it and try again.'
    });
    expect(JSON.stringify(response.body)).not.toContain('F.U_C K');
    expect(await Message.countDocuments({ conversationId })).toBe(messageCountBefore);
    expect(conversationAfter?.lastMessageText).toBe(conversationBefore?.lastMessageText);
    expect(conversationAfter?.lastMessageAt).toEqual(conversationBefore?.lastMessageAt);
  });

  test('returns safe errors for malformed, missing, and invalid history cursors', async () => {
    const malformedId = await request(app.callback())
      .get('/api/conversations/not-an-object-id/messages')
      .set('Authorization', `Bearer ${buyerToken}`);
    const missingId = new mongoose.Types.ObjectId().toString();
    const missing = await request(app.callback())
      .get(`/api/conversations/${missingId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`);
    const invalidCursor = await request(app.callback())
      .get(`/api/conversations/${conversationId}/messages`)
      .query({ before: 'not-a-date' })
      .set('Authorization', `Bearer ${buyerToken}`);

    expect(malformedId.status).toBe(400);
    expect(malformedId.body.message).toBe('Invalid conversation ID.');
    expect(missing.status).toBe(404);
    expect(missing.body.message).toBe('Conversation not found.');
    expect(invalidCursor.status).toBe(400);
    expect(invalidCursor.body.message).toContain('valid date');
  });

  test('sends and paginates text history while updating unread state', async () => {
    const first = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: '  Is this desk still available?  ' });

    expect(first.status).toBe(201);
    expect(first.body.message).toEqual(
      expect.objectContaining({
        text: 'Is this desk still available?',
        senderId: buyerId,
        receiverId: sellerId,
        isMine: true,
        status: 'sent'
      })
    );

    await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'I can collect it tomorrow.' });

    const sellerList = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${sellerToken}`);
    expect(sellerList.body.conversations[0]).toEqual(
      expect.objectContaining({
        unreadCount: 2,
        lastMessageText: 'I can collect it tomorrow.'
      })
    );

    const history = await request(app.callback())
      .get(`/api/conversations/${conversationId}/messages`)
      .query({ limit: 1 })
      .set('Authorization', `Bearer ${sellerToken}`);

    expect(history.status).toBe(200);
    expect(history.body.messages).toHaveLength(1);
    expect(history.body.messages[0]).toEqual(
      expect.objectContaining({
        text: 'I can collect it tomorrow.',
        isMine: false
      })
    );
    expect(history.body.pagination.hasMore).toBe(true);
    expect(history.body.pagination.nextBefore).toBeTruthy();
  });

  test('marks incoming messages as read and clears only the reader count', async () => {
    const sellerWatermark = await Message.findOne({
      conversationId,
      receiverId: sellerId
    }).sort({ _id: -1 });
    const read = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: sellerWatermark!._id.toString() });

    expect(read.status).toBe(200);
    expect(read.body.readCount).toBe(2);
    expect(read.body.unreadCount).toBe(0);

    const storedConversation = await Conversation.findById(conversationId);
    expect(storedConversation?.sellerUnreadCount).toBe(0);
    expect(storedConversation?.buyerUnreadCount).toBe(0);
    expect(
      await Message.countDocuments({
        conversationId,
        receiverId: sellerId,
        status: 'read'
      })
    ).toBe(2);

    await Conversation.findByIdAndUpdate(conversationId, {
      $set: { sellerUnreadCount: 5 }
    });
    const repairedRead = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: sellerWatermark!._id.toString() });
    expect(repairedRead.status).toBe(200);
    expect(repairedRead.body.readCount).toBe(0);
    expect(repairedRead.body.unreadCount).toBe(0);
    expect(
      (await Conversation.findById(conversationId))?.sellerUnreadCount
    ).toBe(0);

    const reply = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ text: 'Yes, it is available.' });
    expect(reply.status).toBe(201);
    expect(reply.body.message.isMine).toBe(true);

    const buyerList = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${buyerToken}`);
    expect(buyerList.body.conversations[0].unreadCount).toBe(1);

    const buyerRead = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ throughMessageId: reply.body.message.id });
    expect(buyerRead.status).toBe(200);
    expect(buyerRead.body.readCount).toBe(1);
    expect(buyerRead.body.unreadCount).toBe(0);

    const messages = await Message.find({ conversationId }).sort({ createdAt: 1 });
    expect(messages.filter((message) => message.status === 'read')).toHaveLength(3);
    expect(messages.at(-1)?.receiverId.toString()).toBe(buyerId);
  });

  test('does not mark a message persisted after the displayed watermark', async () => {
    const first = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Displayed before the read request.' });
    const later = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Persisted after the displayed snapshot.' });

    const read = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: first.body.message.id });

    expect(read.status).toBe(200);
    expect(read.body.readCount).toBe(1);
    expect(read.body.unreadCount).toBe(1);
    expect((await Message.findById(first.body.message.id))?.status).toBe('read');
    expect((await Message.findById(later.body.message.id))?.status).toBe('sent');
    expect(
      (await Conversation.findById(conversationId))?.sellerUnreadCount
    ).toBe(1);

    const legacyRead = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`);
    expect(legacyRead.status).toBe(200);
    expect(legacyRead.body.readCount).toBe(1);
    expect(legacyRead.body.unreadCount).toBe(0);
    expect((await Message.findById(later.body.message.id))?.status).toBe('read');

    const invalidWatermark = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: 'not-an-object-id' });
    expect(invalidWatermark.status).toBe(400);
  });

  test('bounds reads by history chronology when object ids sort oppositely', async () => {
    const olderId = new mongoose.Types.ObjectId('68b8f000ffffffffffffffff');
    const newerId = new mongoose.Types.ObjectId('68b8f0000000000000000000');
    const olderTime = new Date('2026-09-04T23:20:00.100Z');
    const newerTime = new Date('2026-09-04T23:20:00.900Z');

    await Message.create([
      {
        _id: olderId,
        conversationId,
        senderId: buyerId,
        receiverId: sellerId,
        type: 'text',
        text: 'Displayed chronological message.',
        status: 'sent',
        createdAt: olderTime,
        updatedAt: olderTime
      },
      {
        _id: newerId,
        conversationId,
        senderId: buyerId,
        receiverId: sellerId,
        type: 'text',
        text: 'Newer message with a lower object id.',
        status: 'sent',
        createdAt: newerTime,
        updatedAt: newerTime
      }
    ]);
    await Conversation.findByIdAndUpdate(conversationId, {
      $set: { sellerUnreadCount: 2 }
    });

    const read = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: olderId.toString() });

    expect(read.status).toBe(200);
    expect(read.body.readCount).toBe(1);
    expect(read.body.unreadCount).toBe(1);
    expect((await Message.findById(olderId))?.status).toBe('read');
    expect((await Message.findById(newerId))?.status).toBe('sent');

    await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: newerId.toString() });
  });

  test('treats an empty legacy read snapshot as a no-op', async () => {
    const emptyRead = await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`);

    expect(emptyRead.status).toBe(200);
    expect(emptyRead.body.readCount).toBe(0);
    expect(emptyRead.body.unreadCount).toBe(0);

    const later = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Arrived after the empty read snapshot.' });

    expect(later.status).toBe(201);
    expect((await Message.findById(later.body.message.id))?.status).toBe('sent');
    expect(
      (await Conversation.findById(conversationId))?.sellerUnreadCount
    ).toBe(1);

    await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: later.body.message.id });
  });

  test('freezes a legacy watermark across a transaction retry', async () => {
    const displayed = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Displayed before the legacy read request.' });
    expect(displayed.status).toBe(201);

    let releaseFirstUpdate!: () => void;
    const firstUpdateReleased = new Promise<void>((resolve) => {
      releaseFirstUpdate = resolve;
    });
    let signalFirstUpdate!: () => void;
    const firstUpdateStarted = new Promise<void>((resolve) => {
      signalFirstUpdate = resolve;
    });
    const originalUpdateMany = Message.updateMany.bind(Message);
    const updateSpy = jest
      .spyOn(Message, 'updateMany')
      .mockImplementationOnce((async (...args: any[]) => {
        signalFirstUpdate();
        await firstUpdateReleased;
        return (originalUpdateMany as any)(...args);
      }) as any);

    try {
      const legacyRead = request(app.callback())
        .patch(`/api/conversations/${conversationId}/read`)
        .set('Authorization', `Bearer ${sellerToken}`);
      const readResponse = legacyRead.then((response) => response);
      await firstUpdateStarted;

      const later = await request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ text: 'Arrived while the legacy read transaction was active.' });
      expect(later.status).toBe(201);
      releaseFirstUpdate();

      const read = await readResponse;
      expect(read.status).toBe(200);
      expect((await Message.findById(displayed.body.message.id))?.status).toBe(
        'read'
      );
      expect((await Message.findById(later.body.message.id))?.status).toBe(
        'sent'
      );
      expect(read.body.unreadCount).toBe(1);
    } finally {
      releaseFirstUpdate();
      updateSpy.mockRestore();
    }
  });

  test('keeps the unread counter consistent during concurrent send and read', async () => {
    const displayed = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'Visible before concurrent delivery.' });
    expect(displayed.status).toBe(201);

    const [read, later] = await Promise.all([
      request(app.callback())
        .patch(`/api/conversations/${conversationId}/read`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ throughMessageId: displayed.body.message.id }),
      request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ text: 'Delivered concurrently with the read receipt.' })
    ]);

    expect(read.status).toBe(200);
    expect(later.status).toBe(201);
    expect((await Message.findById(displayed.body.message.id))?.status).toBe(
      'read'
    );
    expect((await Message.findById(later.body.message.id))?.status).toBe('sent');

    const storedUnreadCount = await Message.countDocuments({
      conversationId,
      receiverId: sellerId,
      status: { $in: ['sent', 'delivered'] }
    });
    expect(storedUnreadCount).toBe(1);
    expect(
      (await Conversation.findById(conversationId))?.sellerUnreadCount
    ).toBe(storedUnreadCount);

    await request(app.callback())
      .patch(`/api/conversations/${conversationId}/read`)
      .set('Authorization', `Bearer ${sellerToken}`)
      .send({ throughMessageId: later.body.message.id });
  });

  test('stores an R2 image URL and returns it in chat history', async () => {
    const imageUrl = 'https://assets.kiwishare.online/images/chat/photo.jpg';
    const sent = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ type: 'image', imageUrl });

    expect(sent.status).toBe(201);
    expect(sent.body.message).toEqual(
      expect.objectContaining({
        type: 'image',
        imageUrl,
        text: '',
        isMine: true
      })
    );

    const stored = await Message.findById(sent.body.message.id);
    expect(stored?.type).toBe('image');
    expect(stored?.imageUrl).toBe(imageUrl);
    expect(stored?.text).toBeUndefined();

    const sellerList = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${sellerToken}`);
    expect(sellerList.body.conversations[0].lastMessageText).toBe('Photo');

    const history = await request(app.callback())
      .get(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${sellerToken}`);
    expect(history.body.messages).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ type: 'image', imageUrl, isMine: false })
      ])
    );
  });

  test('stores a bounded R2 voice message and returns it in chat history', async () => {
    const audioUrl = 'https://assets.kiwishare.online/audio/chat/voice.m4a';
    const immutableAudioUrl =
      'https://assets.kiwishare.online/audio/messages/immutable.m4a';
    const sent = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ type: 'voice', audioUrl, durationMs: 12500 });

    expect(sent.status).toBe(201);
    expect(sent.body.message).toEqual(
      expect.objectContaining({
        type: 'voice',
        audioUrl: immutableAudioUrl,
        durationMs: 12500,
        text: '',
        isMine: true
      })
    );

    const stored = await Message.findById(sent.body.message.id);
    expect(stored?.type).toBe('voice');
    expect(stored?.audioUrl).toBe(immutableAudioUrl);
    expect(stored?.durationMs).toBe(12500);
    expect(mockedGetR2ObjectBytes).toHaveBeenCalledWith(
      'audio/chat/voice.m4a',
      5 * 1024 * 1024
    );
    expect(mockedStoreImmutableVoiceObject).toHaveBeenCalledWith(
      expect.any(Buffer),
      'audio/mp4',
      'm4a',
      'audio/chat/voice.m4a'
    );
    expect(mockedProbeVoiceAudio).toHaveBeenCalledWith(
      expect.any(Buffer),
      60000,
      expect.objectContaining({ release: expect.any(Function) })
    );

    const sellerList = await request(app.callback())
      .get('/api/conversations')
      .set('Authorization', `Bearer ${sellerToken}`);
    expect(sellerList.body.conversations[0].lastMessageText).toBe('Voice message');
  });

  test('rejects invalid voice URLs and durations without storing messages', async () => {
    const countBefore = await Message.countDocuments({ conversationId });
    const invalidUrl = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        type: 'voice',
        audioUrl: 'https://example.com/voice.m4a',
        durationMs: 1000
      });
    const excessiveDuration = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        type: 'voice',
        audioUrl: 'https://assets.kiwishare.online/audio/chat/voice.m4a',
        durationMs: 60001
      });

    expect(invalidUrl.status).toBe(400);
    expect(excessiveDuration.status).toBe(400);
    expect(await Message.countDocuments({ conversationId })).toBe(countBefore);
  });

  test('rejects voice work before downloading when admission is full', async () => {
    mockedAcquireVoiceProcessingAdmission.mockReturnValueOnce(null);

    const response = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        type: 'voice',
        audioUrl: 'https://assets.kiwishare.online/audio/chat/busy.m4a',
        durationMs: 1000
      });

    expect(response.status).toBe(429);
    expect(mockedGetR2ObjectBytes).not.toHaveBeenCalled();
    expect(mockedProbeVoiceAudio).not.toHaveBeenCalled();
  });

  test('rejects oversized or invalid R2 bytes before storing voice messages', async () => {
    const countBefore = await Message.countDocuments({ conversationId });
    mockedGetR2ObjectBytes
      .mockRejectedValueOnce(new Error('R2 object exceeds the permitted size.'))
      .mockResolvedValueOnce({
        bytes: Buffer.from('not audio'),
        contentType: 'image/jpeg'
      });
    mockedProbeVoiceAudio.mockResolvedValueOnce(null);

    const oversized = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        type: 'voice',
        audioUrl: 'https://assets.kiwishare.online/audio/chat/oversized.m4a',
        durationMs: 1000
      });
    const nonAudio = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        type: 'voice',
        audioUrl: 'https://assets.kiwishare.online/audio/chat/not-audio.m4a',
        durationMs: 1000
      });

    expect(oversized.status).toBe(400);
    expect(oversized.body.message).toContain('could not be verified');
    expect(nonAudio.status).toBe(400);
    expect(nonAudio.body.message).toContain('valid audio');
    expect(await Message.countDocuments({ conversationId })).toBe(countBefore);
  });

  test('rejects a media stream whose measured duration exceeds 60 seconds', async () => {
    const countBefore = await Message.countDocuments({ conversationId });
    mockedProbeVoiceAudio.mockResolvedValueOnce(null);

    const response = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({
        type: 'voice',
        audioUrl: 'https://assets.kiwishare.online/audio/chat/overlong.m4a',
        durationMs: 1000
      });

    expect(response.status).toBe(400);
    expect(response.body.message).toContain('up to 60 seconds');
    expect(mockedStoreImmutableVoiceObject).not.toHaveBeenCalled();
    expect(await Message.countDocuments({ conversationId })).toBe(countBefore);
  });

  test('accepts the relative image proxy when R2 uses local serving', async () => {
    const originalPublicUrl = process.env.R2_PUBLIC_URL;
    process.env.R2_PUBLIC_URL = 'relative';
    const imageUrl = '/api/images/test/pr-97/chat/recovered-photo.jpg';

    try {
      const sent = await request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'image', imageUrl });

      expect(sent.status).toBe(201);
      expect(sent.body.message.imageUrl).toBe(imageUrl);
      expect((await Message.findById(sent.body.message.id))?.imageUrl).toBe(
        imageUrl
      );

      const external = await request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({
          type: 'image',
          imageUrl: 'https://example.com/api/images/external.jpg'
        });
      expect(external.status).toBe(400);

      const traversal = await request(app.callback())
        .post(`/api/conversations/${conversationId}/messages`)
        .set('Authorization', `Bearer ${buyerToken}`)
        .send({ type: 'image', imageUrl: '/api/images/../auth/login' });
      expect(traversal.status).toBe(400);
    } finally {
      if (originalPublicUrl == null) {
        delete process.env.R2_PUBLIC_URL;
      } else {
        process.env.R2_PUBLIC_URL = originalPublicUrl;
      }
    }
  });

  test('omits soft-deleted messages from history', async () => {
    const deleted = await Message.create({
      conversationId: new mongoose.Types.ObjectId(conversationId),
      senderId: new mongoose.Types.ObjectId(buyerId),
      receiverId: new mongoose.Types.ObjectId(sellerId),
      type: 'text',
      text: 'This message was deleted.',
      status: 'deleted',
      deletedAt: new Date()
    });

    const history = await request(app.callback())
      .get(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${sellerToken}`);

    expect(history.status).toBe(200);
    expect(history.body.messages).not.toEqual(
      expect.arrayContaining([expect.objectContaining({ id: deleted.id })])
    );
  });

  test('does not send into a closed conversation', async () => {
    await Conversation.findByIdAndUpdate(conversationId, { status: 'closed' });

    const res = await request(app.callback())
      .post(`/api/conversations/${conversationId}/messages`)
      .set('Authorization', `Bearer ${buyerToken}`)
      .send({ text: 'This should not be sent.' });

    expect(res.status).toBe(409);
    expect(await Message.countDocuments({ text: 'This should not be sent.' })).toBe(0);
  });
});
