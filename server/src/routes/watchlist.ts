import Router from 'koa-router';
import mongoose from 'mongoose';
import { Context } from 'koa';
import Watchlist from '../models/Watchlist';
import Item from '../models/Item';
import { authenticateToken } from '../middleware/auth';
import { formatItem } from './usedItems';

const router = new Router({ prefix: '/watchlist' });
const DEFAULT_PAGE_LIMIT = 25;
const MAX_PAGE_LIMIT = 50;

function safeError(operation: string, error: unknown): void {
  console.error(`[Watchlist] ${operation} failed.`, error);
}

function parseLimit(value: unknown): number {
  const parsed = typeof value === 'string' ? Number(value) : NaN;
  if (!Number.isInteger(parsed) || parsed <= 0) return DEFAULT_PAGE_LIMIT;
  return Math.min(parsed, MAX_PAGE_LIMIT);
}

function encodeCursor(createdAt: Date, id: mongoose.Types.ObjectId): string {
  return Buffer.from(`${createdAt.toISOString()}|${id.toString()}`).toString('base64url');
}

function decodeCursor(value: unknown): { createdAt: Date; id: mongoose.Types.ObjectId } | null {
  if (typeof value !== 'string' || value.length === 0) return null;
  try {
    const [dateValue, idValue] = Buffer.from(value, 'base64url').toString('utf8').split('|');
    const createdAt = new Date(dateValue);
    if (Number.isNaN(createdAt.getTime()) || !mongoose.Types.ObjectId.isValid(idValue)) return null;
    return { createdAt, id: new mongoose.Types.ObjectId(idValue) };
  } catch {
    return null;
  }
}

/**
 * GET /api/watchlist/count/:itemId
 * Retrieve total watchlist/favourite count for an item (Public).
 */
router.get('/count/:itemId', async (ctx: Context) => {
  const { itemId } = ctx.params;
  if (!itemId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Item ID is required.' };
    return;
  }

  try {
    const itemQuery = mongoose.Types.ObjectId.isValid(itemId)
      ? { $in: [new mongoose.Types.ObjectId(itemId), itemId] }
      : itemId;

    const count = await Watchlist.countDocuments({ itemId: itemQuery });

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      itemId,
      count
    };
  } catch (err: unknown) {
    safeError('count lookup', err);
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to retrieve watchlist count.',
    };
  }
});

// Apply JWT authentication middleware to authenticated watchlist routes
router.use(authenticateToken);

/**
 * GET /api/watchlist
 * Retrieve full list of watched items for the current authenticated user.
 */
router.get('/', async (ctx: Context) => {
  const userId = ctx.state.user.id;
  const limit = parseLimit(ctx.query.limit);
  const rawCursor = ctx.query.cursor;
  const cursor = decodeCursor(rawCursor);
  if (rawCursor != null && !cursor) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid Watchlist cursor.' };
    return;
  }

  try {
    const userQuery = mongoose.Types.ObjectId.isValid(userId)
      ? { $in: [new mongoose.Types.ObjectId(userId), userId] }
      : userId;

    const cursorFilter = cursor
      ? {
          $or: [
            { createdAt: { $lt: cursor.createdAt } },
            { createdAt: cursor.createdAt, _id: { $lt: cursor.id } }
          ]
        }
      : {};
    const watchlistFilter = { userId: userQuery, ...cursorFilter };
    const [watchlistEntries, totalCount] = await Promise.all([
      Watchlist.find(watchlistFilter)
      .populate({
        path: 'itemId',
        populate: {
          path: 'sellerId',
          select: 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role',
        },
      })
      .sort({ createdAt: -1, _id: -1 })
      .limit(limit + 1),
      Watchlist.countDocuments({ userId: userQuery })
    ]);

    const hasMore = watchlistEntries.length > limit;
    const pageEntries = hasMore ? watchlistEntries.slice(0, limit) : watchlistEntries;

    // Filter out any items that were deleted or are missing
    const items = pageEntries
      .filter((entry) => entry.itemId != null && (entry.itemId as any).status !== 'deleted')
      .map((entry) => {
        const formatted = formatItem(entry.itemId);
        return {
          ...formatted,
          watchedAt: entry.createdAt,
        };
      });

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      count: totalCount,
      data: items,
      items: items, // Return both keys for 100% compatibility across mobile and web
      pagination: {
        limit,
        hasMore,
        nextCursor: hasMore && pageEntries.length > 0
          ? encodeCursor(pageEntries[pageEntries.length - 1].createdAt, pageEntries[pageEntries.length - 1]._id)
          : null
      }
    };
  } catch (err: unknown) {
    safeError('list lookup', err);
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to retrieve Watchlist.'
    };
  }
});

/**
 * GET /api/watchlist/ids
 * Retrieve lightweight array of item IDs in user's watchlist.
 */
router.get('/ids', async (ctx: Context) => {
  const userId = ctx.state.user.id;

  try {
    const userQuery = mongoose.Types.ObjectId.isValid(userId)
      ? { $in: [new mongoose.Types.ObjectId(userId), userId] }
      : userId;

    const entries = await Watchlist.find(
      { userId: userQuery },
      { itemId: 1, _id: 0 }
    );

    const itemIds = entries
      .filter((e) => e.itemId != null)
      .map((e) => e.itemId.toString());

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      itemIds,
    };
  } catch (err: unknown) {
    safeError('ID lookup', err);
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to retrieve Watchlist IDs.'
    };
  }
});

/**
 * GET /api/watchlist/check/:itemId
 * Check if a specific item is in user's watchlist.
 */
router.get('/check/:itemId', async (ctx: Context) => {
  const userId = ctx.state.user.id;
  const { itemId } = ctx.params;

  if (!itemId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Item ID is required.' };
    return;
  }

  try {
    const userQuery = mongoose.Types.ObjectId.isValid(userId)
      ? { $in: [new mongoose.Types.ObjectId(userId), userId] }
      : userId;
    const itemQuery = mongoose.Types.ObjectId.isValid(itemId)
      ? { $in: [new mongoose.Types.ObjectId(itemId), itemId] }
      : itemId;

    const exists = await Watchlist.exists({
      userId: userQuery,
      itemId: itemQuery,
    });

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      isWatched: !!exists,
    };
  } catch (err: unknown) {
    safeError('status lookup', err);
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to check Watchlist status.'
    };
  }
});

/**
 * POST /api/watchlist/:itemId
 * Add item to user's watchlist.
 */
router.post('/:itemId', async (ctx: Context) => {
  const userId = ctx.state.user.id;
  const { itemId } = ctx.params;

  if (!itemId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Item ID is required.' };
    return;
  }

  try {
    const item = mongoose.Types.ObjectId.isValid(itemId)
      ? await Item.findById(itemId)
      : await Item.findOne({ id: itemId });

    if (!item || item.status === 'deleted') {
      ctx.status = 404;
      ctx.body = { status: 'error', message: 'Item not found.' };
      return;
    }

    if (item.status !== 'active') {
      ctx.status = 409;
      ctx.body = { status: 'error', message: 'This item is not available to Watchlist.' };
      return;
    }

    const itemOwnerId = item.sellerId?.toString() || item.ownerId;
    if (itemOwnerId === userId) {
      ctx.status = 403;
      ctx.body = { status: 'error', message: 'You cannot Watchlist your own item.' };
      return;
    }

    const resolvedItemId = item._id;
    const userQuery = mongoose.Types.ObjectId.isValid(userId)
      ? { $in: [new mongoose.Types.ObjectId(userId), userId] }
      : userId;
    const itemQuery = { $in: [resolvedItemId, resolvedItemId.toString(), itemId] };

    const existing = await Watchlist.findOne({
      userId: userQuery,
      itemId: itemQuery,
    });

    let inserted = false;
    if (!existing) {
      try {
        await Watchlist.create({
          userId: mongoose.Types.ObjectId.isValid(userId) ? new mongoose.Types.ObjectId(userId) : userId,
          itemId: resolvedItemId,
        });
        inserted = true;
      } catch (error: any) {
        if (error?.code !== 11000) throw error;
      }
    }

    if (inserted) {
      await Item.findByIdAndUpdate(resolvedItemId, { $inc: { favouriteCount: 1 } });
    }

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      isWatched: true,
      message: 'Item added to watchlist.',
    };
  } catch (err: unknown) {
    safeError('add', err);
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to add item to Watchlist.'
    };
  }
});

/**
 * DELETE /api/watchlist/:itemId
 * Remove item from user's watchlist.
 */
router.delete('/:itemId', async (ctx: Context) => {
  const userId = ctx.state.user.id;
  const { itemId } = ctx.params;

  if (!itemId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Item ID is required.' };
    return;
  }

  try {
    const item = mongoose.Types.ObjectId.isValid(itemId)
      ? await Item.findById(itemId)
      : await Item.findOne({ id: itemId });

    const targetId = item ? item._id : (mongoose.Types.ObjectId.isValid(itemId) ? new mongoose.Types.ObjectId(itemId) : itemId);
    const userQuery = mongoose.Types.ObjectId.isValid(userId)
      ? { $in: [new mongoose.Types.ObjectId(userId), userId] }
      : userId;
    const itemQuery = { $in: [targetId, targetId.toString(), itemId] };

    const deleted = await Watchlist.findOneAndDelete({
      userId: userQuery,
      itemId: itemQuery,
    });

    if (deleted) {
      // Decrement favouriteCount on Item (ensuring not below 0)
      await Item.findByIdAndUpdate(targetId, [
        {
          $set: {
            favouriteCount: {
              $max: [0, { $subtract: ['$favouriteCount', 1] }],
            },
          },
        },
      ]);
    }

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      isWatched: false,
      message: 'Item removed from watchlist.',
    };
  } catch (err: unknown) {
    safeError('remove', err);
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to remove item from Watchlist.'
    };
  }
});

export default router;
