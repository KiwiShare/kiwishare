import Router from 'koa-router';
import mongoose from 'mongoose';
import { Context } from 'koa';
import Watchlist from '../models/Watchlist';
import Item from '../models/Item';
import { authenticateToken } from '../middleware/auth';

const router = new Router({ prefix: '/watchlist' });

// Apply JWT authentication middleware to all watchlist routes
router.use(authenticateToken);

/**
 * GET /api/watchlist
 * Retrieve full list of watched items for the current authenticated user.
 */
router.get('/', async (ctx: Context) => {
  const userId = ctx.state.user.id;

  try {
    const watchlistEntries = await Watchlist.find({ userId: new mongoose.Types.ObjectId(userId) })
      .populate('itemId')
      .sort({ createdAt: -1 });

    // Filter out any items that were deleted or are missing
    const items = watchlistEntries
      .filter((entry) => entry.itemId != null)
      .map((entry) => {
        const itemObj = (entry.itemId as any).toJSON ? (entry.itemId as any).toJSON() : entry.itemId;
        return {
          ...itemObj,
          watchedAt: entry.createdAt,
        };
      });

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      count: items.length,
      data: items,
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
    const entries = await Watchlist.find(
      { userId: new mongoose.Types.ObjectId(userId) },
      { itemId: 1, _id: 0 }
    );

    const itemIds = entries.map((e) => e.itemId.toString());

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

  if (!mongoose.Types.ObjectId.isValid(itemId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid item ID.' };
    return;
  }

  try {
    const exists = await Watchlist.exists({
      userId: new mongoose.Types.ObjectId(userId),
      itemId: new mongoose.Types.ObjectId(itemId),
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

  if (!mongoose.Types.ObjectId.isValid(itemId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid item ID.' };
    return;
  }

  try {
    const item = await Item.findById(itemId);
    if (!item) {
      ctx.status = 404;
      ctx.body = { status: 'error', message: 'Item not found.' };
      return;
    }

    const existing = await Watchlist.findOne({
      userId: new mongoose.Types.ObjectId(userId),
      itemId: new mongoose.Types.ObjectId(itemId),
    });

    if (!existing) {
      await Watchlist.create({
        userId: new mongoose.Types.ObjectId(userId),
        itemId: new mongoose.Types.ObjectId(itemId),
      });

      // Increment favouriteCount on Item
      await Item.findByIdAndUpdate(itemId, { $inc: { favouriteCount: 1 } });
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

  if (!mongoose.Types.ObjectId.isValid(itemId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid item ID.' };
    return;
  }

  try {
    const deleted = await Watchlist.findOneAndDelete({
      userId: new mongoose.Types.ObjectId(userId),
      itemId: new mongoose.Types.ObjectId(itemId),
    });

    if (deleted) {
      // Decrement favouriteCount on Item (ensuring not below 0)
      await Item.findByIdAndUpdate(itemId, [
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
