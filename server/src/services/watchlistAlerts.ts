import mongoose from 'mongoose';
import PushDevice from '../models/PushDevice';
import User from '../models/User';
import Watchlist from '../models/Watchlist';
import Item from '../models/Item';
import {
  ANDROID_NOTIFICATION_COLOR,
  ANDROID_NOTIFICATION_ICON,
  configuredFirebaseApp
} from './pushNotification';

type MarketplaceItem = {
  _id: mongoose.Types.ObjectId | string;
  title: string;
  category?: string;
  priceNzd?: string;
  sellerId?: mongoose.Types.ObjectId | string;
  ownerId?: string;
  location?: {
    city?: string;
    suburb?: string;
    coordinates?: {
      type?: string;
      coordinates?: number[];
    };
  };
};

function sellerIdOf(item: MarketplaceItem): string {
  const seller = item.sellerId as any;
  if (seller?._id) return seller._id.toString();
  return seller?.toString() ?? item.ownerId ?? '';
}

function priceChangeEnabled(user: any): boolean {
  const current = user?.notificationPreferences?.watchlistPriceChange;
  const legacy = user?.notificationPreferences?.watchlistPriceDrop;
  return current !== false && legacy !== false;
}

async function activeTokens(userId: mongoose.Types.ObjectId | string) {
  const devices = await PushDevice.find({ userId, active: true })
    .select('+token')
    .sort({ lastSeenAt: -1 })
    .limit(20)
    .lean();
  return devices
    .map((device: any) => device.token)
    .filter(
      (token: unknown): token is string =>
        typeof token === 'string' && token.trim().length > 0
    );
}

async function sendWatchlistAlert(
  userId: mongoose.Types.ObjectId | string,
  notification: { title: string; body: string },
  data: Record<string, string>
) {
  const tokens = await activeTokens(userId);
  if (tokens.length === 0) return;

  const app = await configuredFirebaseApp();
  if (!app) return;

  const { getMessaging } = await import('firebase-admin/messaging');
  const response = await getMessaging(app).sendEachForMulticast({
    tokens,
    notification,
    data,
    android: {
      priority: 'high',
      notification: {
        sound: 'default',
        icon: ANDROID_NOTIFICATION_ICON,
        color: ANDROID_NOTIFICATION_COLOR
      }
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
  if (invalidTokens.length > 0) {
    await PushDevice.deleteMany({ token: { $in: invalidTokens } });
  }
}

export async function notifyWatchlistPriceIncrease(request: {
  item: MarketplaceItem;
  oldPriceNzd: string;
  newPriceNzd: string;
  oldPriceCents: number;
  newPriceCents: number;
}): Promise<void> {
  if (request.newPriceCents <= request.oldPriceCents) return;

  try {
    const itemId =
      typeof request.item._id === 'string'
        ? new mongoose.Types.ObjectId(request.item._id)
        : request.item._id;
    const sellerId = sellerIdOf(request.item);
    const watchers = await Watchlist.find({ itemId }).select('userId').lean();
    const watcherIds = watchers
      .map((entry: any) => entry.userId as mongoose.Types.ObjectId)
      .filter((userId) => userId.toString() !== sellerId);

    for (const userId of watcherIds) {
      try {
        const user = await User.findById(userId)
          .select('notificationPreferences status isBanned')
          .lean() as any;
        if (
          !user ||
          user.status === 'deleted' ||
          user.status === 'banned' ||
          user.isBanned ||
          !priceChangeEnabled(user)
        ) {
          continue;
        }

        await sendWatchlistAlert(
          userId,
          {
            title: 'Price changed on a saved item',
            body:
              request.item.title +
              ' changed from $' +
              request.oldPriceNzd +
              ' to $' +
              request.newPriceNzd
          },
          {
            type: 'watchlist_price_change',
            direction: 'up',
            itemId: itemId.toString(),
            itemTitle: request.item.title,
            oldPrice: request.oldPriceNzd,
            newPrice: request.newPriceNzd
          }
        );
      } catch (error) {
        console.warn(
          '[Watchlist Alert] Price increase delivery failed for one user.',
          error instanceof Error ? error.message : error
        );
      }
    }
  } catch (error) {
    console.warn(
      '[Watchlist Alert] Price increase dispatch failed.',
      error instanceof Error ? error.message : error
    );
  }
}

function distanceKm(
  aLat: number,
  aLng: number,
  bLat: number,
  bLng: number
): number {
  const rad = Math.PI / 180;
  const dLat = (bLat - aLat) * rad;
  const dLng = (bLng - aLng) * rad;
  const lat1 = aLat * rad;
  const lat2 = bLat * rad;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

function isNearby(user: any, item: MarketplaceItem): boolean {
  const userCoords = user?.location?.coordinates?.coordinates;
  const itemCoords = item.location?.coordinates?.coordinates;
  if (
    Array.isArray(userCoords) &&
    userCoords.length >= 2 &&
    Array.isArray(itemCoords) &&
    itemCoords.length >= 2
  ) {
    const [userLng, userLat] = userCoords.map(Number);
    const [itemLng, itemLat] = itemCoords.map(Number);
    if (
      [userLng, userLat, itemLng, itemLat].every((value) =>
        Number.isFinite(value)
      )
    ) {
      return distanceKm(userLat, userLng, itemLat, itemLng) <= 50;
    }
  }

  const userCity = String(user?.location?.city ?? '').trim().toLowerCase();
  const itemCity = String(item.location?.city ?? '').trim().toLowerCase();
  return userCity.length > 0 && itemCity.length > 0 && userCity === itemCity;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^$()|[\]\\]/g, '\\$&');
}

export async function notifyNearbyCategoryWatchers(
  item: MarketplaceItem
): Promise<void> {
  const category = item.category?.trim();
  if (!category) return;

  try {
    const sellerId = sellerIdOf(item);
    const sameCategoryItemIds = await Item.find({
      category: new RegExp('^' + escapeRegExp(category) + '$', 'i'),
      _id: { $ne: item._id }
    }).distinct('_id');

    if (sameCategoryItemIds.length === 0) return;

    const watcherIds = await Watchlist.distinct('userId', {
      itemId: { $in: sameCategoryItemIds }
    });

    for (const userId of watcherIds) {
      if (userId.toString() === sellerId) continue;
      try {
        const user = await User.findById(userId)
          .select('notificationPreferences status isBanned location')
          .lean() as any;
        if (
          !user ||
          user.status === 'deleted' ||
          user.status === 'banned' ||
          user.isBanned ||
          user.notificationPreferences?.watchlistNearbyCategory !== true ||
          !isNearby(user, item)
        ) {
          continue;
        }

        const locationLabel =
          item.location?.suburb || item.location?.city || 'your area';
        await sendWatchlistAlert(
          userId,
          {
            title: 'New ' + category + ' listing near you',
            body: item.title + ' was just listed in ' + locationLabel + '.'
          },
          {
            type: 'watchlist_nearby_category',
            itemId: item._id.toString(),
            itemTitle: item.title,
            category
          }
        );
      } catch (error) {
        console.warn(
          '[Watchlist Alert] Nearby-category delivery failed for one user.',
          error instanceof Error ? error.message : error
        );
      }
    }
  } catch (error) {
    console.warn(
      '[Watchlist Alert] Nearby-category dispatch failed.',
      error instanceof Error ? error.message : error
    );
  }
}
