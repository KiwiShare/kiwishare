import Router from 'koa-router';
import mongoose from 'mongoose';
import Item from '../models/Item';
import User from '../models/User';
import Watchlist from '../models/Watchlist';
import Order from '../models/Order';
import Report, { REPORT_STATUSES } from '../models/Report';
import { authenticateToken } from '../middleware/auth';
import { formatItem } from './usedItems';
import { sendAdminItemNotification } from '../services/adminNotification';
import { getPlatformFeeSettings, updatePlatformFeeSettings } from '../models/PlatformSetting';

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
    recentItems,
    totalOrders,
    orderDistribution,
    recentOrders
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
    Item.find().sort({ createdAt: -1 }).limit(5).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role'),
    // Order statistics
    Order.countDocuments(),
    Order.aggregate([
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          totalItemAmount: { $sum: '$itemAmount' },
          totalBuyerAmount: { $sum: '$buyerTotalAmount' },
          totalBuyerFee: { $sum: '$buyerFeeAmount' },
          totalSellerFee: { $sum: '$sellerFeeAmount' },
          totalSellerReceive: { $sum: '$sellerReceiveAmount' }
        }
      }
    ]),
    Order.find()
      .sort({ createdAt: -1 })
      .limit(6)
      .populate('buyerId', 'displayName email avatarUrl')
      .populate('sellerId', 'displayName email avatarUrl')
      .populate('itemId', 'title imageUrl price priceNzd category')
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

  const orderStatusCounts: Record<string, number> = {
    pending_payment: 0,
    paid: 0,
    meeting_scheduled: 0,
    meeting_in_progress: 0,
    qr_scanned: 0,
    completed: 0,
    cancelled: 0,
    refund_pending: 0,
    refunded: 0,
    transfer_pending: 0,
    seller_paid: 0,
    disputed: 0
  };

  let totalGmvCents = 0;
  let totalPlatformFeesCents = 0;
  let totalSellerPayoutsCents = 0;
  let completedOrders = 0;
  let activeOrders = 0;
  let cancelledOrders = 0;

  orderDistribution.forEach((od: any) => {
    const st = od._id;
    if (st && orderStatusCounts[st] !== undefined) {
      orderStatusCounts[st] = od.count;
    }
    // Only non-cancelled/non-refunded orders count towards GMV and platform fees
    if (st !== 'cancelled' && st !== 'refunded' && st !== 'refund_pending' && st !== 'pending_payment') {
      totalGmvCents += (od.totalBuyerAmount || 0);
      totalPlatformFeesCents += ((od.totalBuyerFee || 0) + (od.totalSellerFee || 0));
      totalSellerPayoutsCents += (od.totalSellerReceive || 0);
    }
    if (st === 'completed' || st === 'seller_paid') {
      completedOrders += od.count;
    } else if (st === 'cancelled' || st === 'refunded') {
      cancelledOrders += od.count;
    } else if (st !== 'pending_payment') {
      activeOrders += od.count;
    }
  });

  const formattedRecentOrders = recentOrders.map((ord: any) => ({
    id: ord._id.toString(),
    orderNumber: ord.orderNumber,
    status: ord.status,
    itemTitle: ord.itemSnapshot?.title || (ord.itemId as any)?.title || 'Used Item',
    itemImageUrl: ord.itemSnapshot?.imageUrl || (ord.itemId as any)?.imageUrl || '',
    buyerName: (ord.buyerId as any)?.displayName || 'Kiwi Buyer',
    buyerEmail: (ord.buyerId as any)?.email,
    sellerName: (ord.sellerId as any)?.displayName || 'Kiwi Seller',
    sellerEmail: (ord.sellerId as any)?.email,
    itemAmountNzd: (ord.itemAmount / 100).toFixed(2),
    buyerFeeNzd: (ord.buyerFeeAmount / 100).toFixed(2),
    sellerFeeNzd: (ord.sellerFeeAmount / 100).toFixed(2),
    platformFeeNzd: ((ord.buyerFeeAmount + ord.sellerFeeAmount) / 100).toFixed(2),
    buyerTotalNzd: (ord.buyerTotalAmount / 100).toFixed(2),
    sellerReceiveNzd: (ord.sellerReceiveAmount / 100).toFixed(2),
    createdAt: ord.createdAt
  }));

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
      recentItems: recentItems.map((it: any) => formatItem(it)),
      orderStats: {
        totalOrders,
        completedOrders,
        activeOrders,
        cancelledOrders,
        totalGmvNzd: (totalGmvCents / 100).toFixed(2),
        totalPlatformFeesNzd: (totalPlatformFeesCents / 100).toFixed(2),
        totalSellerPayoutsNzd: (totalSellerPayoutsCents / 100).toFixed(2),
        statusBreakdown: orderStatusCounts,
        recentOrders: formattedRecentOrders
      }
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
    kiwiGold: u.kiwiGold ?? 100,
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

// 3. PATCH /api/admin/users/:id/trust-score - Update user trust score & profile admin fields
router.patch('/admin/users/:id/trust-score', authenticateToken, requireAdmin, async (ctx) => {
  const { id } = ctx.params;
  const {
    trustScore,
    kiwiGold,
    role,
    isVerified,
    displayName,
    isStudentVerified,
    studentInstitution
  } = ctx.request.body as any;

  const user = mongoose.Types.ObjectId.isValid(id)
    ? await User.findById(id)
    : await User.findOne({ email: id });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  if (trustScore !== undefined) {
    if (
      typeof trustScore !== 'number' ||
      !Number.isFinite(trustScore) ||
      !Number.isSafeInteger(trustScore) ||
      trustScore < 0
    ) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'Trust score must be a non-negative safe integer.' };
      return;
    }
    user.trustScore = trustScore;
  }
  if (kiwiGold !== undefined) {
    if (
      typeof kiwiGold !== 'number' ||
      !Number.isFinite(kiwiGold) ||
      !Number.isSafeInteger(kiwiGold)
    ) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'KiwiGold must be a safe integer.' };
      return;
    }
    user.kiwiGold = kiwiGold;
  }
  if (role !== undefined) {
    if (role !== 'user' && role !== 'admin') {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'Role must be user or admin.' };
      return;
    }
    user.role = role;
  }
  if (isVerified !== undefined) {
    user.isVerified = Boolean(isVerified);
  }
  if (displayName !== undefined && typeof displayName === 'string') {
    user.displayName = displayName.trim();
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
    message: 'User profile updated successfully.',
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      kiwiGold: user.kiwiGold ?? 100,
      trustScore: user.trustScore,
      isVerified: Boolean(user.isVerified),
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

  const previousStatus = item.status;
  item.status = status;
  if (status === 'deleted') {
    item.deletedAt = new Date();
  }
  await item.save();

  // Send email and push notification to the seller/owner when status is changed by admin
  if (item.sellerId && previousStatus !== status) {
    const seller: any = item.sellerId;
    const sellerId = seller._id || seller;
    const sellerEmail = seller.email;
    const sellerName = seller.displayName;

    let eventType: 'item_revoked' | 'item_reactivated' | 'item_deleted' | null = null;
    if (status === 'revoked') {
      eventType = 'item_revoked';
    } else if (status === 'active' && previousStatus === 'revoked') {
      eventType = 'item_reactivated';
    } else if (status === 'deleted') {
      eventType = 'item_deleted';
    }

    if (eventType) {
      sendAdminItemNotification({
        userId: sellerId,
        userEmail: sellerEmail,
        userName: sellerName,
        eventType,
        itemTitle: item.title,
        itemId: item._id.toString(),
        itemPriceNzd: item.price ? (item.price / 100).toFixed(2) : undefined
      }).catch((err) => {
        console.warn('[Admin Item Status Notification] Non-blocking dispatch failure:', err?.message || err);
      });
    }
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: `Item status updated to ${status}.`,
    item: formatItem(item)
  };
});

// 7. PATCH /api/admin/items/:id/assign - Reassign / Transfer item to another user account
router.patch('/admin/items/:id/assign', authenticateToken, requireAdmin, async (ctx) => {
  const { id } = ctx.params;
  const { targetUserEmail, targetUserId } = ctx.request.body as any;

  const rawTargetEmail = typeof targetUserEmail === 'string' ? targetUserEmail.trim() : '';
  const rawTargetId = typeof targetUserId === 'string' ? targetUserId.trim() : '';

  if (!rawTargetEmail && !rawTargetId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Either targetUserEmail or targetUserId is required.' };
    return;
  }

  let targetUser = null;
  if (rawTargetEmail) {
    targetUser = await User.findOne({ email: rawTargetEmail.toLowerCase() });
    if (!targetUser) {
      ctx.status = 404;
      ctx.body = { status: 'error', message: `Target user with email "${rawTargetEmail}" not found.` };
      return;
    }
  } else if (rawTargetId) {
    if (!mongoose.Types.ObjectId.isValid(rawTargetId)) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: `Invalid target user ID "${rawTargetId}".` };
      return;
    }
    targetUser = await User.findById(rawTargetId);
    if (!targetUser) {
      ctx.status = 404;
      ctx.body = { status: 'error', message: `Target user with ID "${rawTargetId}" not found.` };
      return;
    }
  }

  if (targetUser!.status === 'banned' || targetUser!.status === 'deleted' || targetUser!.isBanned) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Target user account is suspended or banned.' };
    return;
  }

  const item = mongoose.Types.ObjectId.isValid(id)
    ? await Item.findById(id)
    : await Item.findOne({ id });

  if (!item || item.status === 'deleted') {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Used item not found.' };
    return;
  }

  const previousSellerId = item.sellerId ? item.sellerId.toString() : null;

  item.sellerId = targetUser!._id;
  item.ownerId = targetUser!._id.toString();
  await item.save();

  await item.populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');

  // Notify the newly assigned recipient user via Email & Push Notification
  sendAdminItemNotification({
    userId: targetUser!._id,
    userEmail: targetUser!.email,
    userName: targetUser!.displayName,
    eventType: 'transferred_to_user',
    itemTitle: item.title,
    itemId: item._id.toString(),
    itemPriceNzd: item.price ? (item.price / 100).toFixed(2) : undefined
  }).catch((err) => {
    console.warn('[Admin Transfer Notification Recipient] Dispatch failure:', err?.message || err);
  });

  // If there was a previous owner different from target user, notify previous owner as well
  if (previousSellerId && previousSellerId !== targetUser!._id.toString()) {
    sendAdminItemNotification({
      userId: previousSellerId,
      eventType: 'transferred_from_user',
      itemTitle: item.title,
      itemId: item._id.toString(),
      itemPriceNzd: item.price ? (item.price / 100).toFixed(2) : undefined
    }).catch((err) => {
      console.warn('[Admin Transfer Notification Previous Owner] Dispatch failure:', err?.message || err);
    });
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: `Item successfully reassigned to ${targetUser!.displayName} (${targetUser!.email}).`,
    item: formatItem(item)
  };
});

// 12. GET /api/admin/settings/fees - Get platform fee settings
router.get('/admin/settings/fees', authenticateToken, requireAdmin, async (ctx) => {
  const fees = await getPlatformFeeSettings();
  ctx.body = {
    status: 'success',
    data: fees
  };
});

// 13. PUT /api/admin/settings/fees - Update platform fee settings
router.put('/admin/settings/fees', authenticateToken, requireAdmin, async (ctx) => {
  const { buyerFeePercent, minFeeCents } = ctx.request.body as any;
  const updated = await updatePlatformFeeSettings(buyerFeePercent, minFeeCents);
  ctx.body = {
    status: 'success',
    message: 'Platform fee settings updated successfully.',
    data: updated
  };
});


router.get('/admin/reports', authenticateToken, requireAdmin, async (ctx) => {
  const { status, targetType } = ctx.query;
  const filter: any = {};
  if (status && status !== 'all') filter.status = status;
  if (targetType && targetType !== 'all') filter.targetType = targetType;

  const reports = await Report.find(filter).sort({ createdAt: -1 }).limit(500);
  ctx.body = {
    status: 'success',
    count: reports.length,
    reports: reports.map((report: any) => ({
      id: report._id.toString(),
      reporterId: report.reporterId?.toString() || null,
      targetType: report.targetType,
      targetId: report.targetId?.toString() || null,
      contextType: report.contextType,
      contextId: report.contextId?.toString() || null,
      reason: report.reason,
      details: report.details,
      status: report.status,
      createdAt: report.createdAt
    }))
  };
});

router.patch('/admin/reports/:id/status', authenticateToken, requireAdmin, async (ctx) => {
  const { id } = ctx.params;
  const { status } = ctx.request.body as { status?: string };
  if (!status || !REPORT_STATUSES.includes(status as any)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid report status.' };
    return;
  }
  if (!mongoose.Types.ObjectId.isValid(id)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid report ID.' };
    return;
  }
  const report = await Report.findByIdAndUpdate(id, { status }, { new: true });
  if (!report) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Report not found.' };
    return;
  }
  ctx.body = {
    status: 'success',
    message: status === 'reviewed' ? 'Report approved.' : 'Report status updated.',
    report: { id: report._id.toString(), status: report.status }
  };
});

export default router;
