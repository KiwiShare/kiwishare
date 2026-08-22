import Router from 'koa-router';
import mongoose from 'mongoose';
import Item from '../models/Item';
import User from '../models/User';
import Watchlist from '../models/Watchlist';
import { authenticateToken } from '../middleware/auth';
import { formatItem } from './usedItems';

const router = new Router();

// Middleware to ensure user is admin
export async function requireAdmin(ctx: any, next: any) {
  const userId = ctx.state.user?.id || ctx.state.user?._id;
  const userEmail = ctx.state.user?.email;
  if (!userId && !userEmail) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Authentication required.' };
    return;
  }

  let user = null;
  if (userId && mongoose.Types.ObjectId.isValid(userId)) {
    user = await User.findById(userId);
  }
  if (!user && userEmail) {
    user = await User.findOne({ email: userEmail });
  }

  if (!user || user.role !== 'admin') {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Admin privileges required.' };
    return;
  }

  ctx.state.adminUser = user;
  await next();
}

// 1. GET /api/admin/stats - Global Overview Dashboard Stats
router.get('/admin/stats', authenticateToken, requireAdmin, async (ctx) => {
  const [
    totalUsers,
    totalItems,
    activeItems,
    revokedItems,
    soldItems,
    totalWatchlistEntries,
    platformDistribution,
    categoryDistribution,
    recentUsers,
    recentItems
  ] = await Promise.all([
    User.countDocuments({ status: { $ne: 'deleted' } }),
    Item.countDocuments(),
    Item.countDocuments({ status: 'active' }),
    Item.countDocuments({ status: 'revoked' }),
    Item.countDocuments({ status: 'sold' }),
    Watchlist.countDocuments(),
    // Platform aggregation
    User.aggregate([
      { $group: { _id: { $ifNull: ['$registrationPlatform', 'unknown'] }, count: { $sum: 1 } } }
    ]),
    // Category aggregation
    Item.aggregate([
      { $match: { status: 'active' } },
      { $group: { _id: '$category', count: { $sum: 1 } } },
      { $sort: { count: -1 } }
    ]),
    // Recent 5 users
    User.find().sort({ createdAt: -1 }).limit(5).select('displayName email role registrationPlatform lastUsedPlatform createdAt'),
    // Recent 5 items
    Item.find().sort({ createdAt: -1 }).limit(5)
  ]);

  const platformStats: Record<string, number> = {
    web: 0,
    mobile_ios: 0,
    mobile_android: 0,
    mobile: 0,
    unknown: 0
  };

  platformDistribution.forEach((p: any) => {
    if (p._id) {
      platformStats[p._id] = p.count;
    }
  });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    stats: {
      totalUsers,
      totalItems,
      activeItems,
      revokedItems,
      soldItems,
      totalWatchlistEntries,
      platformStats,
      categoryDistribution: categoryDistribution.map((c: any) => ({
        category: c._id || 'Uncategorized',
        count: c.count
      })),
      recentUsers,
      recentItems: recentItems.map((it: any) => formatItem(it))
    }
  };
});

// 2. GET /api/admin/items - List all items for moderation
router.get('/admin/items', authenticateToken, requireAdmin, async (ctx) => {
  const { status, search, limit = 50 } = ctx.query;
  const filter: any = {};

  if (status && status !== 'all') {
    filter.status = status;
  }
  if (search) {
    filter.$or = [
      { title: { $regex: search, $options: 'i' } },
      { category: { $regex: search, $options: 'i' } },
      { 'location.city': { $regex: search, $options: 'i' } }
    ];
  }

  const items = await Item.find(filter).sort({ createdAt: -1 }).limit(Number(limit) || 50);

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    count: items.length,
    items: items.map((it) => formatItem(it))
  };
});

// 3. PATCH /api/admin/items/:id/status - Moderate / Takedown / Revoke item
router.patch('/admin/items/:id/status', authenticateToken, requireAdmin, async (ctx) => {
  const { id } = ctx.params;
  const { status } = ctx.request.body as any;

  if (!status || !['active', 'revoked', 'sold', 'deleted'].includes(status)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: "Invalid status. Must be 'active', 'revoked', 'sold', or 'deleted'." };
    return;
  }

  const item = mongoose.Types.ObjectId.isValid(id)
    ? await Item.findById(id)
    : await Item.findOne({ id });

  if (!item) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Item not found.' };
    return;
  }

  item.status = status;
  if (status === 'deleted') {
    item.deletedAt = new Date();
  }
  await item.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: `Item status updated to ${status}.`,
    item: formatItem(item)
  };
});

export default router;
