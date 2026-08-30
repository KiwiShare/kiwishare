import mongoose from 'mongoose';
import type { App } from 'firebase-admin/app';
import PushDevice from '../models/PushDevice';
import NotificationDailyCap from '../models/NotificationDailyCap';
import NotificationHistory, { NotificationStatus } from '../models/NotificationHistory';
import Watchlist from '../models/Watchlist';
import User from '../models/User';
import Item from '../models/Item';

export interface ChatPushRequest {
  receiverId: mongoose.Types.ObjectId;
  conversationId: string;
  itemId: string;
  senderId: string;
  messageType: 'text' | 'image';
}

export interface ChatPushPayload extends ChatPushRequest {
  itemTitle: string;
  senderName: string;
}

interface ChatPushDeliveryResult {
  invalidTokens: string[];
}

export interface ChatPushGateway {
  send(tokens: string[], payload: ChatPushPayload): Promise<ChatPushDeliveryResult>;
}

export interface Clock {
  now(): Date;
}

export const systemClock: Clock = {
  now: () => new Date()
};

let clockOverride: Clock | null = null;

export function getClock(): Clock {
  return clockOverride ?? systemClock;
}

export function setClockForTests(clock: Clock | null) {
  clockOverride = clock;
}

export function getAucklandDateKey(date: Date = getClock().now()): string {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Pacific/Auckland',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  });
  const parts = formatter.formatToParts(date);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((value) => value.type === type)?.value;
  const year = part('year');
  const month = part('month');
  const day = part('day');
  if (!year || !month || !day) {
    throw new Error('Unable to calculate the Pacific/Auckland calendar date.');
  }
  return `${year}-${month}-${day}`;
}

export interface PriceDropPushPayload {
  type: 'watchlist_price_drop';
  itemId: string;
  eventId: string;
  itemTitle: string;
  oldPriceNzd: string;
  newPriceNzd: string;
}

export interface PushDeliveryResult {
  invalidTokens: string[];
  successCount: number;
  failureCount: number;
  failureCategory?: NotificationFailureCategory;
}

export type NotificationFailureCategory =
  | 'firebase_not_configured'
  | 'provider_unavailable'
  | 'provider_rejected'
  | 'partial_delivery'
  | 'gateway_exception'
  | 'processing_error';

export interface PushGateway {
  sendPriceDrop(
    tokens: string[],
    payload: PriceDropPushPayload
  ): Promise<PushDeliveryResult>;
}

let firebaseApp: App | null | undefined;
let gatewayOverride: PushGateway | null = null;
let chatGatewayOverride: ChatPushGateway | null = null;

export type FirebaseCredentialConfiguration =
  | { source: 'inline'; credentials: string }
  | { source: 'application-default'; projectId?: string }
  | null;

export function resolveFirebaseCredentialConfiguration(
  env: NodeJS.ProcessEnv = process.env
): FirebaseCredentialConfiguration {
  const inlineCredentials = env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
  if (inlineCredentials) {
    return { source: 'inline', credentials: inlineCredentials };
  }

  const credentialFile = env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
  const projectId = env.FIREBASE_PROJECT_ID?.trim();
  if (!credentialFile && !projectId) return null;
  return {
    source: 'application-default',
    ...(projectId ? { projectId } : {})
  };
}

async function configuredFirebaseApp(): Promise<App | null> {
  if (firebaseApp !== undefined) return firebaseApp;

  try {
    const { applicationDefault, cert, getApps, initializeApp } = await import(
      'firebase-admin/app'
    );
    if (getApps().length > 0) {
      firebaseApp = getApps()[0];
      return firebaseApp;
    }

    const configuration = resolveFirebaseCredentialConfiguration();
    if (configuration?.source === 'inline') {
      firebaseApp = initializeApp({
        credential: cert(JSON.parse(configuration.credentials))
      });
    } else if (configuration?.source === 'application-default') {
      firebaseApp = initializeApp({
        credential: applicationDefault(),
        ...(configuration.projectId
          ? { projectId: configuration.projectId }
          : {})
      });
    } else {
      firebaseApp = null;
    }
  } catch (error) {
    firebaseApp = null;
    console.warn(
      '[Push Notification] Firebase Admin could not be initialized; push delivery is disabled.',
      error instanceof Error ? error.message : 'Unknown initialization error.'
    );
  }

  return firebaseApp;
}

const firebaseGateway: PushGateway = {
  async sendPriceDrop(tokens, payload) {
    const app = await configuredFirebaseApp();
    if (!app || tokens.length === 0) {
      return {
        invalidTokens: [],
        successCount: 0,
        failureCount: tokens.length,
        failureCategory: 'firebase_not_configured'
      };
    }

    try {
      const { getMessaging } = await import('firebase-admin/messaging');
      const response = await getMessaging(app).sendEachForMulticast({
        tokens,
        notification: {
          title: `Price drop: ${payload.itemTitle}`,
          body: `An item on your watchlist dropped to $${payload.newPriceNzd} NZD (was $${payload.oldPriceNzd} NZD).`
        },
        data: {
          type: payload.type,
          itemId: payload.itemId,
          eventId: payload.eventId,
          oldPrice: payload.oldPriceNzd,
          newPrice: payload.newPriceNzd
        },
        android: {
          priority: 'high',
          notification: { sound: 'default' }
        },
        apns: {
          payload: { aps: { sound: 'default', contentAvailable: true } }
        }
      });

      const invalidTokens = response.responses.flatMap((result, index) => {
        const code = result.error?.code;
        return code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token'
          ? [tokens[index]]
          : [];
      });

      return {
        invalidTokens,
        successCount: response.successCount,
        failureCount: response.failureCount,
        ...(response.failureCount > 0
          ? {
              failureCategory: response.successCount > 0
                ? 'partial_delivery' as const
                : 'provider_rejected' as const
            }
          : {})
      };
    } catch (error) {
      console.warn(
        '[Push Notification] FCM multicast delivery failed:',
        error instanceof Error ? error.message : 'Unknown multicast error.'
      );
      return {
        invalidTokens: [],
        successCount: 0,
        failureCount: tokens.length,
        failureCategory: 'provider_unavailable'
      };
    }
  }
};

const firebaseChatGateway: ChatPushGateway = {
  async send(tokens, payload) {
    const app = await configuredFirebaseApp();
    if (!app || tokens.length === 0) return { invalidTokens: [] };

    const { getMessaging } = await import('firebase-admin/messaging');
    const response = await getMessaging(app).sendEachForMulticast({
      tokens,
      notification: {
        title: 'New KiwiShare message',
        body: `${payload.senderName} sent you ${payload.messageType === 'image' ? 'a photo' : 'a message'} about ${payload.itemTitle}.`
      },
      data: {
        type: 'chat_message',
        recipientId: payload.receiverId.toString(),
        conversationId: payload.conversationId,
        itemId: payload.itemId,
        itemTitle: payload.itemTitle,
        participantId: payload.senderId,
        participantName: payload.senderName
      },
      android: {
        priority: 'high',
        notification: { sound: 'default' }
      },
      apns: {
        payload: { aps: { sound: 'default', contentAvailable: true } }
      }
    });

    const invalidTokens = response.responses.flatMap((result, index) => {
      const code = result.error?.code;
      return code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
        ? [tokens[index]]
        : [];
    });
    return { invalidTokens };
  }
};

export function setPushGatewayForTests(gateway: PushGateway | null) {
  gatewayOverride = gateway;
}

export function setChatPushGatewayForTests(gateway: ChatPushGateway | null) {
  chatGatewayOverride = gateway;
}

export async function notifyChatReceiver(request: ChatPushRequest): Promise<void> {
  try {
    const registrations = await PushDevice.find({
      userId: request.receiverId,
      active: true
    })
      .select('+token')
      .sort({ lastSeenAt: -1 })
      .limit(20)
      .lean();
    const tokens = registrations
      .map((registration: any) => registration.token)
      .filter((token: unknown): token is string => typeof token === 'string');
    if (tokens.length === 0) return;

    const [itemResult, senderResult] = await Promise.all([
      Item.findById(request.itemId).select('title').lean(),
      User.findById(request.senderId).select('displayName').lean()
    ]);
    const item = itemResult as { title?: string } | null;
    const sender = senderResult as { displayName?: string } | null;
    const payload: ChatPushPayload = {
      ...request,
      itemTitle: item?.title ?? 'an item',
      senderName: sender?.displayName ?? 'A KiwiShare member'
    };
    const result = await (chatGatewayOverride ?? firebaseChatGateway).send(
      tokens,
      payload
    );
    if (result.invalidTokens.length > 0) {
      await PushDevice.deleteMany({ token: { $in: result.invalidTokens } });
    }
  } catch (error) {
    // Message persistence is authoritative. Push delivery is best-effort and
    // must never turn a successfully stored chat message into an API failure.
    console.warn(
      '[Push Notification] Chat notification delivery failed.',
      error instanceof Error ? error.message : 'Unknown delivery error.'
    );
  }
}

export interface PriceDropNotificationRequest {
  item: {
    _id: mongoose.Types.ObjectId | string;
    title: string;
    sellerId?: mongoose.Types.ObjectId | string;
    ownerId?: string;
  };
  oldPriceNzd: string;
  newPriceNzd: string;
  oldPriceCents: number;
  newPriceCents: number;
  eventId: string;
}

export async function notifyWatchlistPriceDrop(
  request: PriceDropNotificationRequest
): Promise<void> {
  const { item, oldPriceNzd, newPriceNzd, oldPriceCents, newPriceCents, eventId } =
    request;

  // 1. Strict price drop check: eligible only when newPriceCents < oldPriceCents
  if (newPriceCents >= oldPriceCents) {
    return;
  }

  const itemId = typeof item._id === 'string'
    ? new mongoose.Types.ObjectId(item._id)
    : item._id;

  const sellerIdStr = item.sellerId
    ? item.sellerId.toString()
    : item.ownerId ?? '';

  try {
    // 2. Find active watchers for this item
    const watchlistEntries = await Watchlist.find({ itemId })
      .select('userId')
      .lean();

    if (watchlistEntries.length === 0) return;

    // 3. Filter out the seller
    const eligibleWatcherUserIds = watchlistEntries
      .map((entry: any) => entry.userId as mongoose.Types.ObjectId)
      .filter((uid) => uid.toString() !== sellerIdStr);

    if (eligibleWatcherUserIds.length === 0) return;

    const clock = getClock();
    const dateKey = getAucklandDateKey(clock.now());

    for (const userId of eligibleWatcherUserIds) {
      let reservedHistoryId: mongoose.Types.ObjectId | null = null;
      try {
        // Check user existence and opt-out preference
        const user = (await User.findById(userId)
          .select('notificationPreferences status isBanned')
          .lean()) as any;

        if (
          !user ||
          user.status === 'deleted' ||
          user.status === 'banned' ||
          user.isBanned
        ) {
          continue;
        }

        if (user.notificationPreferences?.watchlistPriceDrop === false) {
          try {
            await NotificationHistory.create({
              userId,
              itemId,
              type: 'watchlist_price_drop',
              eventId,
              oldPriceNzd,
              newPriceNzd,
              oldPriceCents,
              newPriceCents,
              status: 'opted_out',
              deviceCount: 0
            });
          } catch (err: any) {
            // Ignore duplicate key if already logged
            if (err.code !== 11000) throw err;
          }
          continue;
        }

        // Retrieve active device tokens
        const devices = await PushDevice.find({ userId, active: true })
          .select('+token')
          .sort({ lastSeenAt: -1 })
          .limit(20)
          .lean();

        const tokens = devices
          .map((d: any) => d.token)
          .filter((t: unknown): t is string => typeof t === 'string' && t.trim().length > 0);

        if (tokens.length === 0) {
          try {
            await NotificationHistory.create({
              userId,
              itemId,
              type: 'watchlist_price_drop',
              eventId,
              oldPriceNzd,
              newPriceNzd,
              oldPriceCents,
              newPriceCents,
              status: 'no_devices',
              deviceCount: 0
            });
          } catch (err: any) {
            if (err.code !== 11000) throw err;
          }
          continue;
        }

        // Reserve this user/event before quota admission. The unique history
        // index makes concurrent replays lose here, before they can consume a
        // second quota slot or call the provider.
        try {
          const reservation = await NotificationHistory.create({
            userId,
            itemId,
            type: 'watchlist_price_drop',
            eventId,
            oldPriceNzd,
            newPriceNzd,
            oldPriceCents,
            newPriceCents,
            status: 'processing',
            deviceCount: tokens.length
          });
          reservedHistoryId = reservation._id as mongoose.Types.ObjectId;
        } catch (err: any) {
          if (err.code === 11000) continue;
          throw err;
        }

        // Enforce 20 events per Auckland day atomically
        let capDoc = await NotificationDailyCap.findOneAndUpdate(
          { userId, dateKey, count: { $lt: 20 } },
          { $inc: { count: 1 } },
          { new: true }
        );

        if (!capDoc) {
          const existing = await NotificationDailyCap.findOne({
            userId,
            dateKey
          });

          if (!existing) {
            try {
              capDoc = await NotificationDailyCap.create({
                userId,
                dateKey,
                count: 1
              });
            } catch (err: any) {
              if (err.code === 11000) {
                // Upsert race: retry atomic findOneAndUpdate
                capDoc = await NotificationDailyCap.findOneAndUpdate(
                  { userId, dateKey, count: { $lt: 20 } },
                  { $inc: { count: 1 } },
                  { new: true }
                );
              } else {
                throw err;
              }
            }
          }
        }

        const isAdmitted = capDoc !== null && capDoc.count <= 20;

        if (!isAdmitted) {
          // Rate limited (21st and later)
          await NotificationHistory.findByIdAndUpdate(reservedHistoryId, {
            $set: { status: 'rate_limited' }
          });
          continue;
        }

        // Call push gateway
        const gateway = gatewayOverride ?? firebaseGateway;
        let result: PushDeliveryResult;
        let failureReason: NotificationFailureCategory | undefined;
        try {
          result = await gateway.sendPriceDrop(tokens, {
            type: 'watchlist_price_drop',
            itemId: itemId.toString(),
            eventId,
            itemTitle: item.title,
            oldPriceNzd,
            newPriceNzd
          });
        } catch (error) {
          failureReason = 'gateway_exception';
          result = {
            invalidTokens: [],
            successCount: 0,
            failureCount: tokens.length
          };
        }

        // Clean up invalid tokens
        if (result.invalidTokens && result.invalidTokens.length > 0) {
          await PushDevice.deleteMany({ token: { $in: result.invalidTokens } });
        }

        const outcomeStatus: NotificationStatus =
          result.successCount > 0 ? 'sent' : 'failed';
        const recordedFailureCategory = failureReason ??
          result.failureCategory ??
          (result.failureCount > 0
            ? result.successCount > 0
              ? 'partial_delivery'
              : 'provider_rejected'
            : undefined);

        await NotificationHistory.findByIdAndUpdate(reservedHistoryId, {
          $set: {
            status: outcomeStatus,
            successfulDeviceCount: result.successCount,
            failedDeviceCount: result.failureCount,
            ...(recordedFailureCategory
              ? { failureReason: recordedFailureCategory }
              : {})
          }
        });
      } catch (userNotificationError) {
        if (reservedHistoryId) {
          try {
            await NotificationHistory.updateOne(
              { _id: reservedHistoryId, status: 'processing' },
              {
                $set: {
                  status: 'failed',
                  failureReason: 'processing_error'
                }
              }
            );
          } catch (_) {
            // The original processing error remains the useful diagnostic.
          }
        }
        console.warn(
          `[Push Notification] Error processing price drop for user ${userId}:`,
          userNotificationError instanceof Error
            ? userNotificationError.message
            : userNotificationError
        );
      }
    }
  } catch (error) {
    // Non-blocking best-effort execution
    console.warn(
      '[Push Notification] Watchlist price drop dispatch failed:',
      error instanceof Error ? error.message : error
    );
  }
}
