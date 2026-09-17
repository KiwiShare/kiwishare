import Router from 'koa-router';
import { Context } from 'koa';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Order from '../models/Order';

const router = new Router({ prefix: '/orders' });
router.use(authenticateToken);

function currentUserId(ctx: Context): mongoose.Types.ObjectId | null {
  const value = ctx.state.user?.id;
  return mongoose.Types.ObjectId.isValid(value)
    ? new mongoose.Types.ObjectId(value)
    : null;
}

function objectId(value: any): string {
  return (value?._id ?? value)?.toString() ?? '';
}

function formatOrder(order: any, userId: string) {
  const buyerId = objectId(order.buyerId);
  const isBuyer = buyerId === userId;
  const counterparty = isBuyer ? order.sellerId : order.buyerId;

  return {
    id: objectId(order),
    orderNumber: order.orderNumber,
    status: order.status,
    role: isBuyer ? 'buying' : 'selling',
    itemId: objectId(order.itemId),
    item: {
      id: objectId(order.itemId),
      title: order.itemSnapshot?.title || order.itemId?.title || 'KiwiShare Item',
      priceNzd: ((order.itemAmount ?? 0) / 100).toFixed(2),
      imageUrl: order.itemSnapshot?.imageUrl || order.itemId?.images?.[0]?.url || '',
      condition: order.itemSnapshot?.condition || order.itemId?.condition,
      category: order.itemId?.category || 'General'
    },
    counterparty: {
      id: objectId(counterparty),
      displayName: counterparty?.displayName || (isBuyer ? 'Seller' : 'Buyer'),
      avatarUrl: counterparty?.avatarUrl || null,
      role: isBuyer ? 'seller' : 'buyer'
    },
    meeting: order.meeting?.scheduledAt ? {
      scheduledAt: new Date(order.meeting.scheduledAt).toISOString(),
      locationName: order.meeting.locationName || '',
      latitude: order.meeting.latitude ?? null,
      longitude: order.meeting.longitude ?? null,
      proposalStatus: order.meeting.proposalStatus || 'proposed',
      note: order.meeting.note || ''
    } : null,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
    completedAt: order.completedAt || null
  };
}

// 1. Get user orders (buying, selling, or all; in_progress, completed, or all)
router.get('/my', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized user.' };
    return;
  }

  const { type = 'all', status = 'all' } = ctx.query as {
    type?: string;
    status?: string;
  };

  const filter: any = {};

  if (type === 'buying') {
    filter.buyerId = userId;
  } else if (type === 'selling') {
    filter.sellerId = userId;
  } else {
    filter.$or = [{ buyerId: userId }, { sellerId: userId }];
  }

  if (status === 'in_progress') {
    filter.status = {
      $in: [
        'pending_payment',
        'paid',
        'meeting_scheduled',
        'meeting_in_progress',
        'transfer_pending'
      ]
    };
  } else if (status === 'completed') {
    filter.status = {
      $in: ['completed', 'qr_scanned', 'seller_paid']
    };
  } else if (status === 'cancelled') {
    filter.status = {
      $in: ['cancelled', 'refunded', 'disputed']
    };
  }

  const orders = await Order.find(filter)
    .populate('buyerId', 'displayName avatarUrl email')
    .populate('sellerId', 'displayName avatarUrl email')
    .populate('itemId', 'title price images status category condition')
    .sort({ createdAt: -1 })
    .limit(100);

  const formattedOrders = orders.map((order) =>
    formatOrder(order, userId.toString())
  );

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    orders: formattedOrders
  };
});

// 2. Get order details by ID
router.get('/:orderId', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized user.' };
    return;
  }

  const { orderId } = ctx.params;
  if (!mongoose.Types.ObjectId.isValid(orderId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid order ID.' };
    return;
  }

  const order = await Order.findById(orderId)
    .populate('buyerId', 'displayName avatarUrl email')
    .populate('sellerId', 'displayName avatarUrl email')
    .populate('itemId', 'title price images status category condition');

  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Order not found.' };
    return;
  }

  const buyerId = objectId(order.buyerId);
  const sellerId = objectId(order.sellerId);
  const currentIdStr = userId.toString();

  if (buyerId !== currentIdStr && sellerId !== currentIdStr) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Forbidden: You are not a party to this order.' };
    return;
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    order: formatOrder(order, currentIdStr)
  };
});

export default router;
