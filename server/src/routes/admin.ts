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
    User.find().sort({ createdAt: -1 }).limit(5).select('displayName email role isStudentVerified studentInstitution trustScore isBanned status registrationPlatform lastUsedPlatform createdAt'),
    // Recent 5 items
    Item.find().sort({ createdAt: -1 }).limit(5).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role')
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

// 2. GET /api/admin/users - List all registered users for administration
router.get('/admin/users', authenticateToken, requireAdmin, async (ctx) => {
  const { search, role, status } = ctx.query;
  const filter: any = {};

  if (role && role !== 'all') {
    filter.role = role;
  }
  if (status && status !== 'all') {
    if (status === 'banned') {
      filter.$or = [{ isBanned: true }, { status: 'banned' }];
    } else {
      filter.status = status;
      filter.isBanned = { $ne: true };
    }
  }
  if (search) {
    const searchRegex = { $regex: search, $options: 'i' };
    filter.$or = [
      { displayName: searchRegex },
      { email: searchRegex },
      { username: searchRegex },
      { studentInstitution: searchRegex }
    ];
  }

  const users = await User.find(filter).sort({ createdAt: -1 });

  // Get item counts per user
  const userItemCounts = await Item.aggregate([
    { $group: { _id: '$sellerId', count: { $sum: 1 } } }
  ]);
  const countMap = new Map<string, number>();
  userItemCounts.forEach((c: any) => {
    if (c._id) countMap.set(c._id.toString(), c.count);
  });

  const formattedUsers = users.map((u: any) => ({
    id: u._id.toString(),
    _id: u._id.toString(),
    email: u.email,
    displayName: u.displayName,
    avatarUrl: u.avatarUrl,
    role: u.role || 'user',
    status: u.isBanned ? 'banned' : (u.status || 'active'),
    isBanned: Boolean(u.isBanned || u.status === 'banned'),
    trustScore: u.trustScore ?? 100,
    isVerified: Boolean(u.isVerified),
    isStudentVerified: Boolean(u.isStudentVerified),
    studentInstitution: u.studentInstitution || 'University of Auckland',
    studentIdNumber: u.studentIdNumber || '',
    registrationPlatform: u.registrationPlatform || 'unknown',
    lastUsedPlatform: u.lastUsedPlatform || 'unknown',
    lastActiveAt: u.lastActiveAt,
    itemsCount: countMap.get(u._id.toString()) || 0,
    createdAt: u.createdAt,
    updatedAt: u.updatedAt
  }));

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    count: formattedUsers.length,
    users: formattedUsers
  };
});

// 3. PATCH /api/admin/users/:id/trust-score - Update user trust score & student status
router.patch('/admin/users/:id/trust-score', authenticateToken, requireAdmin, async (ctx) => {
  const { id } = ctx.params;
  const { trustScore, isStudentVerified, studentInstitution } = ctx.request.body as any;

  const user = mongoose.Types.ObjectId.isValid(id)
    ? await User.findById(id)
    : await User.findOne({ email: id });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  if (trustScore !== undefined) {
    user.trustScore = Math.max(0, Math.min(100, Number(trustScore)));
  }
  if (isStudentVerified !== undefined) {
    user.isStudentVerified = Boolean(isStudentVerified);
  }
  if (studentInstitution !== undefined) {
    user.studentInstitution = studentInstitution;
  }

  await user.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'User trust score updated successfully.',
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      trustScore: user.trustScore,
      isStudentVerified: user.isStudentVerified,
      studentInstitution: user.studentInstitution,
      isBanned: Boolean(user.isBanned || user.status === 'banned')
    }
  };
});

// 4. PATCH /api/admin/users/:id/status - Ban / Unban user
router.patch('/admin/users/:id/status', authenticateToken, requireAdmin, async (ctx) => {
  const { id } = ctx.params;
  const { status, isBanned } = ctx.request.body as any;

  const user = mongoose.Types.ObjectId.isValid(id)
    ? await User.findById(id)
    : await User.findOne({ email: id });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  // Prevent banning self admin
  if (user._id.toString() === ctx.state.adminUser._id.toString()) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Cannot ban your own admin account.' };
    return;
  }

  if (isBanned !== undefined) {
    user.isBanned = Boolean(isBanned);
    user.status = user.isBanned ? 'banned' : 'active';
  } else if (status) {
    user.status = status;
    user.isBanned = status === 'banned';
  }

  await user.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: user.isBanned ? 'User banned successfully.' : 'User restored to active state.',
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      status: user.status,
      isBanned: user.isBanned
    }
  };
});

// 5. GET /api/admin/items - List all items for moderation
router.get('/admin/items', authenticateToken, requireAdmin, async (ctx) => {
  const { status, search, limit = 100 } = ctx.query;
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

  const items = await Item.find(filter)
    .populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role')
    .sort({ createdAt: -1 })
    .limit(Number(limit) || 100);

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    count: items.length,
    items: items.map((it) => formatItem(it))
  };
});

// 6. PATCH /api/admin/items/:id/status - Moderate / Takedown / Revoke item
router.patch('/admin/items/:id/status', authenticateToken, requireAdmin, async (ctx) => {
  const { id } = ctx.params;
  const { status } = ctx.request.body as any;

  if (!status || !['active', 'revoked', 'sold', 'deleted'].includes(status)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: "Invalid status. Must be 'active', 'revoked', 'sold', or 'deleted'." };
    return;
  }

  const item = mongoose.Types.ObjectId.isValid(id)
    ? await Item.findById(id).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role')
    : await Item.findOne({ id }).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');

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
