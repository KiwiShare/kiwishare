import Router from 'koa-router';
import mongoose from 'mongoose';
import { Context } from 'koa';
import Watchlist from '../models/Watchlist';
import Item from '../models/Item';
import { authenticateToken } from '../middleware/auth';
import { formatItem } from './usedItems';

const router = new Router({ prefix: '/watchlist' });

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
  } catch (err: any) {
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to retrieve watchlist count.',
      error: err.message
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

  try {
    const userQuery = mongoose.Types.ObjectId.isValid(userId)
      ? { $in: [new mongoose.Types.ObjectId(userId), userId] }
      : userId;

    const watchlistEntries = await Watchlist.find({ userId: userQuery })
      .populate({
        path: 'itemId',
        populate: {
          path: 'sellerId',
          select: 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role',
        },
      })
      .sort({ createdAt: -1 });

    // Filter out any items that were deleted or are missing
    const items = watchlistEntries
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
      count: items.length,
      data: items,
      items: items, // Return both keys for 100% compatibility across mobile and web
    };
  } catch (err: any) {
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to retrieve watchlist.',
      error: err.message,
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
  } catch (err: any) {
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to retrieve watchlist IDs.',
      error: err.message,
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
  } catch (err: any) {
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to check watch status.',
      error: err.message,
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

    if (!item) {
      ctx.status = 404;
      ctx.body = { status: 'error', message: 'Item not found.' };
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

    if (!existing) {
      await Watchlist.create({
        userId: mongoose.Types.ObjectId.isValid(userId) ? new mongoose.Types.ObjectId(userId) : userId,
        itemId: resolvedItemId,
      });

      // Increment favouriteCount on Item
      await Item.findByIdAndUpdate(resolvedItemId, { $inc: { favouriteCount: 1 } });
    }

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      isWatched: true,
      message: 'Item added to watchlist.',
    };
  } catch (err: any) {
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to add item to watchlist.',
      error: err.message,
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
  } catch (err: any) {
    ctx.status = 500;
    ctx.body = {
      status: 'error',
      message: 'Failed to remove item from watchlist.',
      error: err.message,
    };
  }
});

export default router;
