import request from 'supertest';
import mongoose from 'mongoose';
import { MongoMemoryServer } from 'mongodb-memory-server';
import jwt from 'jsonwebtoken';
import app from '../src/app';
import Item from '../src/models/Item';
import User from '../src/models/User';
import Watchlist from '../src/models/Watchlist';
import PushDevice from '../src/models/PushDevice';
import NotificationDailyCap from '../src/models/NotificationDailyCap';
import NotificationHistory from '../src/models/NotificationHistory';
import {
  notifyWatchlistPriceDrop,
  setPushGatewayForTests,
  setClockForTests,
  PushGateway,
  PriceDropPushPayload,
  PushDeliveryResult,
  resolveFirebaseCredentialConfiguration,
  buildPriceDropNotificationContent,
  PRICE_DROP_NOTIFICATION_TITLE,
  ANDROID_NOTIFICATION_ICON,
  ANDROID_NOTIFICATION_COLOR
} from '../src/services/pushNotification';
import {
  EXPIRED_TOKEN_CLEANUP_GRACE_SECONDS,
  getJwtSecret
} from '../src/middleware/auth';

jest.setTimeout(60000);

async function waitForCondition(
  condition: () => Promise<boolean>,
  description: string
): Promise<void> {
  for (let attempt = 0; attempt < 500; attempt += 1) {
    if (await condition()) return;
    await new Promise<void>((resolve) => setImmediate(resolve));
  }
  throw new Error(`Timed out waiting for ${description}.`);
}

describe('Watchlist Price Drop Notification Backend Tests', () => {
  let mongoServer: MongoMemoryServer;
  let sentCalls: Array<{ tokens: string[]; payload: PriceDropPushPayload }> = [];
  let invalidTokensToReturn: string[] = [];
  let simulateProviderFailure = false;

  const mockGateway: PushGateway = {
    async sendPriceDrop(tokens, payload): Promise<PushDeliveryResult> {
      sentCalls.push({ tokens: [...tokens], payload: { ...payload } });
      if (simulateProviderFailure) {
        return {
          invalidTokens: [],
          successCount: 0,
          failureCount: tokens.length
        };
      }
      const invalid = tokens.filter((t) => invalidTokensToReturn.includes(t));
      return {
        invalidTokens: invalid,
        successCount: tokens.length - invalid.length,
        failureCount: invalid.length
      };
    }
  };

  test('builds accessible branded notification copy and Android styling', () => {
    const content = buildPriceDropNotificationContent({
      type: 'watchlist_price_drop',
      itemId: '64f000000000000000000001',
      eventId: 'event-1',
      itemTitle: 'Oak chair',
      oldPriceNzd: '100.00',
      newPriceNzd: '80.00'
    });

    expect(content).toEqual({
      title: 'Price drop on a saved item',
      body: 'Oak chair dropped from $100.00 to $80.00'
    });
    expect(PRICE_DROP_NOTIFICATION_TITLE).toBe(content.title);
    expect(ANDROID_NOTIFICATION_ICON).toBe('ic_stat_kiwishare');
    expect(ANDROID_NOTIFICATION_COLOR).toBe('#064B3A');
  });

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    const uri = mongoServer.getUri();
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
    await mongoose.connect(uri);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  beforeEach(async () => {
    sentCalls = [];
    invalidTokensToReturn = [];
    simulateProviderFailure = false;
    setPushGatewayForTests(mockGateway);
    setClockForTests(null);

    await User.deleteMany({});
    await Item.deleteMany({});
    await Watchlist.deleteMany({});
    await PushDevice.deleteMany({});
    await NotificationDailyCap.deleteMany({});
    await NotificationHistory.deleteMany({});
  });

  function createAuthToken(user: any): string {
    return jwt.sign({ id: user._id.toString(), email: user.email }, getJwtSecret(), {
      expiresIn: '1h'
    });
  }

  describe('JWT configuration', () => {
    it('rejects absent, short, and known public fallback secrets', () => {
      const originalSecret = process.env.JWT_SECRET;
      try {
        delete process.env.JWT_SECRET;
        expect(() => getJwtSecret()).toThrow('JWT_SECRET must be set');
        process.env.JWT_SECRET = 'too-short';
        expect(() => getJwtSecret()).toThrow('JWT_SECRET must be set');
        process.env.JWT_SECRET = 'kiwishare_super_secret_key_123_abc';
        expect(() => getJwtSecret()).toThrow('JWT_SECRET must be set');
      } finally {
        process.env.JWT_SECRET = originalSecret;
      }
    });
  });

  describe('Firebase Admin configuration', () => {
    it('stays disabled without credentials and supports ADC or inline secrets', () => {
      expect(resolveFirebaseCredentialConfiguration({})).toBeNull();
      expect(resolveFirebaseCredentialConfiguration({
        GOOGLE_APPLICATION_CREDENTIALS: '/run/secrets/firebase.json',
        FIREBASE_PROJECT_ID: 'kiwishare-test'
      })).toEqual({ source: 'application-default', projectId: 'kiwishare-test' });
      expect(resolveFirebaseCredentialConfiguration({
        GOOGLE_APPLICATION_CREDENTIALS: '/ignored/when-inline-is-set.json',
        FIREBASE_SERVICE_ACCOUNT_JSON: '{"project_id":"inline"}'
      })).toEqual({
        source: 'inline',
        credentials: '{"project_id":"inline"}'
      });
    });
  });

  describe('Device token endpoints & preferences (Issue #69)', () => {
    it('POST /api/notifications/devices registers and moves a device token to current user', async () => {
      const user1 = await User.create({
        email: 'user1@test.com',
        displayName: 'User 1',
        authProvider: 'email_otp'
      });
      const user2 = await User.create({
        email: 'user2@test.com',
        displayName: 'User 2',
        authProvider: 'email_otp'
      });

      const token1 = createAuthToken(user1);
      const token2 = createAuthToken(user2);

      // User 1 registers token
      const res1 = await request(app.callback())
        .post('/api/notifications/devices')
        .set('Authorization', `Bearer ${token1}`)
        .send({ token: 'test-device-token-1234567890', platform: 'android' });

      expect(res1.status).toBe(200);
      expect(res1.body.status).toBe('success');
      expect(res1.body.device).toEqual({ platform: 'android' });
      expect(res1.body.device.id).toBeUndefined();

      let device = await PushDevice.findOne({
        userId: user1._id
      }).select('+token');
      expect(device).not.toBeNull();
      expect(device?.platform).toBe('android');

      // User 2 logs into same device; token is reassigned to user 2
      const res2 = await request(app.callback())
        .post('/api/notifications/devices')
        .set('Authorization', `Bearer ${token2}`)
        .send({ token: 'test-device-token-1234567890', platform: 'android' });

      expect(res2.status).toBe(200);
      device = await PushDevice.findOne({ token: 'test-device-token-1234567890' });
      expect(device?.userId.toString()).toBe(user2._id.toString());
    });

    it('valid token cleanup removes only the authenticated user device', async () => {
      const owner = await User.create({
        email: 'device-owner@test.com',
        displayName: 'Device Owner',
        authProvider: 'email_otp'
      });
      const other = await User.create({
        email: 'other-user@test.com',
        displayName: 'Other User',
        authProvider: 'email_otp'
      });
      const token = 'private-device-token-1234567890';
      await PushDevice.create({ userId: owner._id, token, platform: 'ios' });

      const unauthenticated = await request(app.callback())
        .post('/api/notifications/devices')
        .send({ token, platform: 'ios' });
      expect(unauthenticated.status).toBe(401);

      const removal = await request(app.callback())
        .delete('/api/notifications/devices')
        .set('Authorization', `Bearer ${createAuthToken(other)}`)
        .send({ token });
      expect(removal.status).toBe(200);
      expect(await PushDevice.countDocuments({ userId: owner._id })).toBe(1);

      const ownerRemoval = await request(app.callback())
        .delete('/api/notifications/devices')
        .set('Authorization', `Bearer ${createAuthToken(owner)}`)
        .send({ token });
      expect(ownerRemoval.status).toBe(200);
      expect(await PushDevice.countDocuments({ userId: owner._id })).toBe(0);
    });

    it('allows expired-token cleanup only inside the five-minute grace period', async () => {
      const user = await User.create({
        email: 'logout@test.com',
        displayName: 'Logout User',
        authProvider: 'email_otp'
      });
      await PushDevice.create({
        userId: user._id,
        token: 'device-to-remove-1234567890',
        platform: 'ios'
      });

      const expiredJwt = jwt.sign(
        { id: user._id.toString(), email: user.email },
        getJwtSecret(),
        { expiresIn: `-${EXPIRED_TOKEN_CLEANUP_GRACE_SECONDS - 30}s` }
      );

      const res = await request(app.callback())
        .delete('/api/notifications/devices')
        .set('Authorization', `Bearer ${expiredJwt}`)
        .send({ token: 'device-to-remove-1234567890' });

      expect(res.status).toBe(200);
      const remaining = await PushDevice.countDocuments({
        token: 'device-to-remove-1234567890'
      });
      expect(remaining).toBe(0);
    });

    it('rejects expired-token cleanup outside the grace period', async () => {
      const user = await User.create({
        email: 'old-logout@test.com',
        displayName: 'Old Logout User',
        authProvider: 'email_otp'
      });
      const deviceToken = 'old-device-token-1234567890';
      await PushDevice.create({
        userId: user._id,
        token: deviceToken,
        platform: 'android'
      });
      const expiredJwt = jwt.sign(
        { id: user._id.toString(), email: user.email },
        getJwtSecret(),
        { expiresIn: `-${EXPIRED_TOKEN_CLEANUP_GRACE_SECONDS + 30}s` }
      );

      const response = await request(app.callback())
        .delete('/api/notifications/devices')
        .set('Authorization', `Bearer ${expiredJwt}`)
        .send({ token: deviceToken });

      expect(response.status).toBe(403);
      expect(await PushDevice.countDocuments({ token: deviceToken })).toBe(1);
    });

    it('rejects a forged cleanup token without revealing device ownership', async () => {
      const user = await User.create({
        email: 'forged-logout@test.com',
        displayName: 'Forged Logout User',
        authProvider: 'email_otp'
      });
      const deviceToken = 'forged-device-token-1234567890';
      await PushDevice.create({
        userId: user._id,
        token: deviceToken,
        platform: 'ios'
      });
      const forgedJwt = jwt.sign(
        { id: user._id.toString(), email: user.email },
        'different-test-only-signing-secret-that-is-long-enough-2026',
        { expiresIn: '1h' }
      );

      const response = await request(app.callback())
        .delete('/api/notifications/devices')
        .set('Authorization', `Bearer ${forgedJwt}`)
        .send({ token: deviceToken });

      expect(response.status).toBe(403);
      expect(await PushDevice.countDocuments({ token: deviceToken })).toBe(1);
    });

    it('GET & PATCH /api/notifications/preferences manages watchlist opt-out', async () => {
      const user = await User.create({
        email: 'prefs@test.com',
        displayName: 'Prefs User',
        authProvider: 'email_otp'
      });
      const token = createAuthToken(user);

      const getRes = await request(app.callback())
        .get('/api/notifications/preferences')
        .set('Authorization', `Bearer ${token}`);
      expect(getRes.status).toBe(200);
      expect(getRes.body.preferences.watchlistPriceDrop).toBe(true);

      const patchRes = await request(app.callback())
        .patch('/api/notifications/preferences')
        .set('Authorization', `Bearer ${token}`)
        .send({ watchlistPriceDrop: false });

      expect(patchRes.status).toBe(200);
      expect(patchRes.body.preferences.watchlistPriceDrop).toBe(false);

      const updatedUser = await User.findById(user._id);
      expect(updatedUser?.notificationPreferences?.watchlistPriceDrop).toBe(false);
    });
  });

  describe('Price drop detection, policy, and quota (Issue #132)', () => {
    it('1. Unchanged price produces no notification and consumes no quota', async () => {
      const seller = await User.create({
        email: 'seller@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher@test.com',
        displayName: 'Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Camp Stove',
        category: 'Camping',
        price: 5000,
        priceNzd: '50.00',
        imageUrl: 'https://example.com/stove.jpg',
        images: [{ url: 'https://example.com/stove.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'device-token-watcher-1234567890',
        platform: 'android'
      });

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '50.00',
        newPriceNzd: '50.00',
        oldPriceCents: 5000,
        newPriceCents: 5000,
        eventId: 'evt-unchanged'
      });

      expect(sentCalls.length).toBe(0);
      expect(await NotificationDailyCap.countDocuments()).toBe(0);
      expect(await NotificationHistory.countDocuments()).toBe(0);
    });

    it('2. Price increase produces no notification and consumes no quota', async () => {
      const seller = await User.create({
        email: 'seller2@test.com',
        displayName: 'Seller 2',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher2@test.com',
        displayName: 'Watcher 2',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Camp Tent',
        category: 'Camping',
        price: 6000,
        priceNzd: '60.00',
        imageUrl: 'https://example.com/tent.jpg',
        images: [{ url: 'https://example.com/tent.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'device-token-watcher2-1234567890',
        platform: 'android'
      });

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '50.00',
        newPriceNzd: '60.00',
        oldPriceCents: 5000,
        newPriceCents: 6000,
        eventId: 'evt-increase'
      });

      expect(sentCalls.length).toBe(0);
      expect(await NotificationDailyCap.countDocuments()).toBe(0);
      expect(await NotificationHistory.countDocuments()).toBe(0);
    });

    it('3. Genuine price decrease selects active watchers and sends payload', async () => {
      const seller = await User.create({
        email: 'seller3@test.com',
        displayName: 'Seller 3',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher3@test.com',
        displayName: 'Watcher 3',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Backpack',
        category: 'Outdoors',
        price: 4000,
        priceNzd: '40.00',
        imageUrl: 'https://example.com/bag.jpg',
        images: [{ url: 'https://example.com/bag.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'token-active-watcher-1234567890',
        platform: 'ios'
      });

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '50.00',
        newPriceNzd: '40.00',
        oldPriceCents: 5000,
        newPriceCents: 4000,
        eventId: 'evt-decrease-1'
      });

      expect(sentCalls.length).toBe(1);
      expect(sentCalls[0].tokens).toEqual(['token-active-watcher-1234567890']);
      expect(sentCalls[0].payload.type).toBe('watchlist_price_drop');
      expect(sentCalls[0].payload.eventId).toBe('evt-decrease-1');
      expect(sentCalls[0].payload.oldPriceNzd).toBe('50.00');
      expect(sentCalls[0].payload.newPriceNzd).toBe('40.00');

      const history = await NotificationHistory.findOne({
        userId: watcher._id,
        eventId: 'evt-decrease-1'
      });
      expect(history).not.toBeNull();
      expect(history?.status).toBe('sent');
    });

    it('4. Excludes seller even if seller watched their own item', async () => {
      const seller = await User.create({
        email: 'seller-self@test.com',
        displayName: 'Self Seller',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Self Item',
        category: 'Outdoors',
        price: 3000,
        priceNzd: '30.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      // Seller accidentally watched own item
      await Watchlist.create({ userId: seller._id, itemId: item._id });
      await PushDevice.create({
        userId: seller._id,
        token: 'seller-device-token-1234567890',
        platform: 'android'
      });

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '50.00',
        newPriceNzd: '30.00',
        oldPriceCents: 5000,
        newPriceCents: 3000,
        eventId: 'evt-seller-exclude'
      });

      expect(sentCalls.length).toBe(0);
      expect(await NotificationHistory.countDocuments()).toBe(0);
    });

    it('5. Excludes non-watchers and removed watchers', async () => {
      const seller = await User.create({
        email: 'seller-unwatched@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const nonWatcher = await User.create({
        email: 'nonwatcher@test.com',
        displayName: 'Non Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Unwatched Item',
        category: 'Outdoors',
        price: 2000,
        priceNzd: '20.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await PushDevice.create({
        userId: nonWatcher._id,
        token: 'nonwatcher-token-1234567890',
        platform: 'android'
      });

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '40.00',
        newPriceNzd: '20.00',
        oldPriceCents: 4000,
        newPriceCents: 2000,
        eventId: 'evt-unwatched'
      });

      expect(sentCalls.length).toBe(0);
    });

    it('6. Excludes opted-out users and logs opted_out history', async () => {
      const seller = await User.create({
        email: 'seller-optout@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const optedOutUser = await User.create({
        email: 'optout@test.com',
        displayName: 'Opt Out User',
        authProvider: 'email_otp',
        notificationPreferences: { watchlistPriceDrop: false }
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Optout Item',
        category: 'Outdoors',
        price: 1500,
        priceNzd: '15.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: optedOutUser._id, itemId: item._id });
      await PushDevice.create({
        userId: optedOutUser._id,
        token: 'optout-token-1234567890',
        platform: 'android'
      });

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '30.00',
        newPriceNzd: '15.00',
        oldPriceCents: 3000,
        newPriceCents: 1500,
        eventId: 'evt-optout-1'
      });

      expect(sentCalls.length).toBe(0);
      const history = await NotificationHistory.findOne({
        userId: optedOutUser._id,
        eventId: 'evt-optout-1'
      });
      expect(history?.status).toBe('opted_out');
    });

    it('7. User with no active devices does not call push gateway and records no_devices', async () => {
      const seller = await User.create({
        email: 'seller-nodevice@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const noDeviceUser = await User.create({
        email: 'nodevice@test.com',
        displayName: 'No Device User',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'No Device Item',
        category: 'Outdoors',
        price: 1000,
        priceNzd: '10.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: noDeviceUser._id, itemId: item._id });

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '20.00',
        newPriceNzd: '10.00',
        oldPriceCents: 2000,
        newPriceCents: 1000,
        eventId: 'evt-nodevice-1'
      });

      expect(sentCalls.length).toBe(0);
      const history = await NotificationHistory.findOne({
        userId: noDeviceUser._id,
        eventId: 'evt-nodevice-1'
      });
      expect(history?.status).toBe('no_devices');
    });

    it('8. Multiple devices for one user consume one user quota event', async () => {
      const seller = await User.create({
        email: 'seller-multi@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const multiDeviceUser = await User.create({
        email: 'multidevice@test.com',
        displayName: 'Multi Device User',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Multi Device Item',
        category: 'Outdoors',
        price: 500,
        priceNzd: '5.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: multiDeviceUser._id, itemId: item._id });
      await PushDevice.create({
        userId: multiDeviceUser._id,
        token: 'multi-device-1-1234567890',
        platform: 'android'
      });
      await PushDevice.create({
        userId: multiDeviceUser._id,
        token: 'multi-device-2-1234567890',
        platform: 'ios'
      });

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '10.00',
        newPriceNzd: '5.00',
        oldPriceCents: 1000,
        newPriceCents: 500,
        eventId: 'evt-multidevice-1'
      });

      expect(sentCalls.length).toBe(1);
      expect(sentCalls[0].tokens.length).toBe(2);
      const capDoc = await NotificationDailyCap.findOne({
        userId: multiDeviceUser._id
      });
      expect(capDoc?.count).toBe(1);
    });

    it('9, 10, 11. Daily limit of 20 per Auckland day: 19 ok, 20th admitted, 21st rate-limited', async () => {
      const seller = await User.create({
        email: 'seller-quota@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-quota@test.com',
        displayName: 'Quota Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Quota Item',
        category: 'Outdoors',
        price: 100,
        priceNzd: '1.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'watcher-quota-device-1234567890',
        platform: 'android'
      });

      // Send 19 events
      for (let i = 1; i <= 19; i++) {
        await notifyWatchlistPriceDrop({
          item,
          oldPriceNzd: `${100 - i + 1}.00`,
          newPriceNzd: `${100 - i}.00`,
          oldPriceCents: (100 - i + 1) * 100,
          newPriceCents: (100 - i) * 100,
          eventId: `evt-quota-${i}`
        });
      }
      expect(sentCalls.length).toBe(19);

      // 20th event is admitted
      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '81.00',
        newPriceNzd: '80.00',
        oldPriceCents: 8100,
        newPriceCents: 8000,
        eventId: 'evt-quota-20'
      });
      expect(sentCalls.length).toBe(20);

      // 21st event is rate limited and does NOT call gateway
      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '80.00',
        newPriceNzd: '79.00',
        oldPriceCents: 8000,
        newPriceCents: 7900,
        eventId: 'evt-quota-21'
      });

      expect(sentCalls.length).toBe(20); // Still 20!

      const history21 = await NotificationHistory.findOne({
        userId: watcher._id,
        eventId: 'evt-quota-21'
      });
      expect(history21?.status).toBe('rate_limited');
    });

    it('12. Concurrency test: 30 simultaneous eligible events never admit more than 20', async () => {
      const seller = await User.create({
        email: 'seller-concurrent@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-concurrent@test.com',
        displayName: 'Concurrent Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Concurrent Item',
        category: 'Outdoors',
        price: 50,
        priceNzd: '0.50',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'concurrent-device-token-1234567890',
        platform: 'android'
      });

      // Fire 30 concurrent price drop notifications
      const promises = Array.from({ length: 30 }, (_, index) =>
        notifyWatchlistPriceDrop({
          item,
          oldPriceNzd: '100.00',
          newPriceNzd: `${50 - index}.00`,
          oldPriceCents: 10000,
          newPriceCents: (50 - index) * 100,
          eventId: `evt-concurrent-${index}`
        })
      );

      await Promise.all(promises);

      expect(sentCalls.length).toBe(20);
      const cap = await NotificationDailyCap.findOne({ userId: watcher._id });
      expect(cap?.count).toBe(20);

      const rateLimitedCount = await NotificationHistory.countDocuments({
        userId: watcher._id,
        status: 'rate_limited'
      });
      expect(rateLimitedCount).toBe(10);
    });

    it('13, 14. Replaying the same price-change event is idempotent and does not consume quota', async () => {
      const seller = await User.create({
        email: 'seller-idempotent@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-idempotent@test.com',
        displayName: 'Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Idempotent Item',
        category: 'Outdoors',
        price: 300,
        priceNzd: '3.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'idempotent-device-1234567890',
        platform: 'android'
      });

      // Initial event
      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '5.00',
        newPriceNzd: '3.00',
        oldPriceCents: 500,
        newPriceCents: 300,
        eventId: 'evt-stable-1'
      });
      expect(sentCalls.length).toBe(1);

      // Replay exact same event
      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '5.00',
        newPriceNzd: '3.00',
        oldPriceCents: 500,
        newPriceCents: 300,
        eventId: 'evt-stable-1'
      });
      expect(sentCalls.length).toBe(1); // Gateway not called again

      const cap = await NotificationDailyCap.findOne({ userId: watcher._id });
      expect(cap?.count).toBe(1);
    });

    it('concurrent replay of one event admits and sends exactly once', async () => {
      const seller = await User.create({
        email: 'seller-replay@test.com',
        displayName: 'Replay Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-replay@test.com',
        displayName: 'Replay Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Replay Item',
        category: 'Outdoors',
        price: 300,
        priceNzd: '3.00',
        imageUrl: 'https://example.com/replay.jpg',
        images: [{ url: 'https://example.com/replay.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'concurrent-replay-token-1234567890',
        platform: 'android'
      });

      await Promise.all(Array.from({ length: 20 }, () =>
        notifyWatchlistPriceDrop({
          item,
          oldPriceNzd: '5.00',
          newPriceNzd: '3.00',
          oldPriceCents: 500,
          newPriceCents: 300,
          eventId: 'evt-concurrent-replay'
        })));

      expect(sentCalls).toHaveLength(1);
      expect((await NotificationDailyCap.findOne({ userId: watcher._id }))?.count).toBe(1);
      expect(await NotificationHistory.countDocuments({
        userId: watcher._id,
        eventId: 'evt-concurrent-replay'
      })).toBe(1);
    });

    it('concurrent PATCH requests notify only actual persisted price drops', async () => {
      const seller = await User.create({
        email: 'seller-route-race@test.com',
        displayName: 'Route Race Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-route-race@test.com',
        displayName: 'Route Race Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Concurrent Route Item',
        description: 'Original description',
        category: 'Outdoors',
        price: 10000,
        priceNzd: '100.00',
        imageUrl: 'https://example.com/concurrent-route.jpg',
        images: [{ url: 'https://example.com/concurrent-route.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'route-race-device-token-1234567890',
        platform: 'android'
      });
      const sellerToken = createAuthToken(seller);

      const [dropResponse, competingResponse] = await Promise.all([
        request(app.callback())
          .patch(`/api/usedItems/${item._id}`)
          .set('Authorization', `Bearer ${sellerToken}`)
          .send({ priceNzd: '80.00', title: 'Updated concurrently' }),
        request(app.callback())
          .patch(`/api/usedItems/${item._id}`)
          .set('Authorization', `Bearer ${sellerToken}`)
          .send({ priceNzd: '90.00', description: 'Also updated concurrently' })
      ]);

      expect(dropResponse.status).toBe(200);
      expect(competingResponse.status).toBe(200);
      const persisted = await Item.findById(item._id);
      expect(persisted?.title).toBe('Updated concurrently');
      expect(persisted?.description).toBe('Also updated concurrently');

      const expectedEvents = persisted?.price === 9000 ? 1 : 2;
      await waitForCondition(
        async () => NotificationHistory.countDocuments({
          itemId: item._id,
          status: { $ne: 'processing' }
        })
          .then((count) => count === expectedEvents),
        'concurrent PATCH notification history'
      );

      const transitions = sentCalls.map((call) => [
        call.payload.oldPriceNzd,
        call.payload.newPriceNzd
      ]);
      if (persisted?.price === 9000) {
        expect(transitions).toEqual([['100.00', '80.00']]);
        expect(transitions).not.toContainEqual(['100.00', '90.00']);
      } else {
        expect(transitions).toEqual(expect.arrayContaining([
          ['100.00', '90.00'],
          ['90.00', '80.00']
        ]));
        expect(transitions).toHaveLength(2);
      }
    });

    it('15. A later price drop returning to a previously seen price is a new valid event', async () => {
      const seller = await User.create({
        email: 'seller-rep@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-rep@test.com',
        displayName: 'Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Price Cycle Item',
        category: 'Outdoors',
        price: 200,
        priceNzd: '2.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'repeat-price-token-1234567890',
        platform: 'android'
      });

      // Event 1: Drop from $5 to $2
      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '5.00',
        newPriceNzd: '2.00',
        oldPriceCents: 500,
        newPriceCents: 200,
        eventId: 'evt-cycle-1'
      });
      expect(sentCalls.length).toBe(1);

      // Event 2: Later, seller had raised price to $4 and now drops back to $2 with a new eventId
      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '4.00',
        newPriceNzd: '2.00',
        oldPriceCents: 400,
        newPriceCents: 200,
        eventId: 'evt-cycle-2'
      });
      expect(sentCalls.length).toBe(2);
    });

    it('16. Invalid tokens are cleaned up from PushDevice', async () => {
      const seller = await User.create({
        email: 'seller-invalid@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-invalid@test.com',
        displayName: 'Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Invalid Token Item',
        category: 'Outdoors',
        price: 100,
        priceNzd: '1.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });

      await PushDevice.create({
        userId: watcher._id,
        token: 'valid-token-1234567890',
        platform: 'android'
      });
      await PushDevice.create({
        userId: watcher._id,
        token: 'expired-invalid-token-1234567890',
        platform: 'android'
      });

      invalidTokensToReturn = ['expired-invalid-token-1234567890'];

      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '2.00',
        newPriceNzd: '1.00',
        oldPriceCents: 200,
        newPriceCents: 100,
        eventId: 'evt-invalid-cleanup'
      });

      const remaining = await PushDevice.find({ userId: watcher._id }).select('+token');
      expect(remaining.length).toBe(1);
      expect(remaining[0].token).toBe('valid-token-1234567890');

      const history = await NotificationHistory.findOne({
        userId: watcher._id,
        eventId: 'evt-invalid-cleanup'
      });
      expect(history?.status).toBe('sent');
      expect(history?.successfulDeviceCount).toBe(1);
      expect(history?.failedDeviceCount).toBe(1);
    });

    it('17, 18, 19. Provider failure records failure safely and does not roll back item price update', async () => {
      const seller = await User.create({
        email: 'seller-fail@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-fail@test.com',
        displayName: 'Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Fail Item',
        category: 'Outdoors',
        price: 1000,
        priceNzd: '10.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'fail-device-token-1234567890',
        platform: 'android'
      });

      simulateProviderFailure = true;

      const sellerToken = createAuthToken(seller);

      // Make request through PATCH /api/usedItems/:id
      const res = await request(app.callback())
        .patch(`/api/usedItems/${item._id}`)
        .set('Authorization', `Bearer ${sellerToken}`)
        .send({ priceNzd: '8.00' });

      await waitForCondition(
        async () => NotificationHistory.exists({
          userId: watcher._id,
          status: 'failed'
        })
          .then(Boolean),
        'provider failure notification history'
      );

      // Item update succeeded with 200!
      expect(res.status).toBe(200);
      expect(res.body.item.priceNzd).toBe('8.00');

      const updatedItem = await Item.findById(item._id);
      expect(updatedItem?.priceNzd).toBe('8.00');
      expect(updatedItem?.price).toBe(800);

      // Quota slot was consumed because event was admitted
      const cap = await NotificationDailyCap.findOne({ userId: watcher._id });
      expect(cap?.count).toBe(1);
      const history = await NotificationHistory.findOne({
        userId: watcher._id
      });
      expect(history?.status).toBe('failed');
      expect(history?.successfulDeviceCount).toBe(0);
      expect(history?.failedDeviceCount).toBe(1);
      expect(history?.failureReason).toBe('provider_rejected');
    });

    it('22. Pacific/Auckland day boundary resets quota at midnight Auckland time', async () => {
      const seller = await User.create({
        email: 'seller-auckland@test.com',
        displayName: 'Seller',
        authProvider: 'email_otp'
      });
      const watcher = await User.create({
        email: 'watcher-auckland@test.com',
        displayName: 'Watcher',
        authProvider: 'email_otp'
      });
      const item = await Item.create({
        sellerId: seller._id,
        title: 'Auckland Item',
        category: 'Outdoors',
        price: 100,
        priceNzd: '1.00',
        imageUrl: 'https://example.com/item.jpg',
        images: [{ url: 'https://example.com/item.jpg', sortOrder: 0 }],
        ownerId: seller._id.toString()
      });
      await Watchlist.create({ userId: watcher._id, itemId: item._id });
      await PushDevice.create({
        userId: watcher._id,
        token: 'auckland-device-1234567890',
        platform: 'android'
      });

      // Inject Day 1 (2026-08-30 23:30:00 NZST)
      const day1 = new Date('2026-08-30T11:30:00.000Z'); // 23:30 in NZ (+12)
      setClockForTests({ now: () => day1 });

      // Fill 20 quota slots on Day 1
      for (let i = 1; i <= 20; i++) {
        await notifyWatchlistPriceDrop({
          item,
          oldPriceNzd: '50.00',
          newPriceNzd: '40.00',
          oldPriceCents: 5000,
          newPriceCents: 4000,
          eventId: `evt-day1-${i}`
        });
      }
      expect(sentCalls.length).toBe(20);

      // 21st event on Day 1 is rate limited
      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '50.00',
        newPriceNzd: '40.00',
        oldPriceCents: 5000,
        newPriceCents: 4000,
        eventId: 'evt-day1-21'
      });
      expect(sentCalls.length).toBe(20);

      // Advance clock past midnight to Day 2 (2026-08-31 00:30:00 NZST)
      const day2 = new Date('2026-08-30T12:30:00.000Z'); // 00:30 on Aug 31 in NZ (+12)
      setClockForTests({ now: () => day2 });

      // Now event on Day 2 is admitted!
      await notifyWatchlistPriceDrop({
        item,
        oldPriceNzd: '50.00',
        newPriceNzd: '40.00',
        oldPriceCents: 5000,
        newPriceCents: 4000,
        eventId: 'evt-day2-1'
      });
      expect(sentCalls.length).toBe(21);
    });
  });
});
