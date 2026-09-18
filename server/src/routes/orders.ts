import Router from 'koa-router';
import { Context } from 'koa';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Order from '../models/Order';
import Item from '../models/Item';
import Conversation from '../models/Conversation';
import { getPlatformFeeSettings } from '../models/PlatformSetting';
import { resolveOrderEffectivePriceCents } from './payments';

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

  const originalPriceCents = order.itemId?.price ?? order.itemAmount;
  const itemPriceNzd = ((order.itemAmount ?? 0) / 100).toFixed(2);
  const origPriceNzd = ((originalPriceCents ?? 0) / 100).toFixed(2);

  return {
    id: objectId(order),
    orderNumber: order.orderNumber,
    status: order.status,
    role: isBuyer ? 'buying' : 'selling',
    itemId: objectId(order.itemId),
    item: {
      id: objectId(order.itemId),
      title: order.itemSnapshot?.title || order.itemId?.title || 'KiwiShare Item',
      priceNzd: itemPriceNzd,
      originalPriceNzd: origPriceNzd !== itemPriceNzd ? origPriceNzd : null,
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
    paidAt: order.paidAt ? new Date(order.paidAt).toISOString() : null,
    itemAmountNzd: itemPriceNzd,
    buyerTotalAmountNzd: ((order.buyerTotalAmount ?? order.itemAmount ?? 0) / 100).toFixed(2),
    buyerFeeAmountNzd: ((order.buyerFeeAmount ?? 0) / 100).toFixed(2),
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
    completedAt: order.completedAt || null
  };
}

// 0. POST / - Create or retrieve existing order for item
router.post('/', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Authentication required.' };
    return;
  }

  const { itemId } = ctx.request.body as { itemId?: string };
  if (!itemId || !mongoose.Types.ObjectId.isValid(itemId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Valid itemId is required.' };
    return;
  }

  const item = await Item.findById(itemId);
  if (!item || item.status === 'deleted') {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Item not found.' };
    return;
  }

  if (item.sellerId.toString() === userId.toString()) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Cannot purchase your own listing.' };
    return;
  }

  // Find existing order for this item and buyer if pending or active
  let order = await Order.findOne({
    itemId: item._id,
    buyerId: userId,
    status: {
      $in: [
        'pending_payment',
        'paid',
        'meeting_scheduled',
        'meeting_in_progress',
        'transfer_pending'
      ]
    }
  })
    .populate('buyerId', 'displayName avatarUrl email')
    .populate('sellerId', 'displayName avatarUrl email')
    .populate('itemId', 'title price images status category condition');

  if (order) {
    // If unpaid, sync price
    if (!order.paidAt) {
      const effectiveCents = await resolveOrderEffectivePriceCents(order);
      const feeSettings = await getPlatformFeeSettings();
      const buyerFeeCents = effectiveCents > 0
        ? Math.max(feeSettings.minFeeCents, Math.round(effectiveCents * (feeSettings.buyerFeePercent / 100)))
        : 0;
      order.itemAmount = effectiveCents;
      order.buyerFeeAmount = buyerFeeCents;
      order.buyerTotalAmount = effectiveCents + buyerFeeCents;
      order.sellerReceiveAmount = effectiveCents;
      await order.save();
    }
    ctx.status = 200;
    ctx.body = {
      status: 'success',
      order: formatOrder(order, userId.toString())
    };
    return;
  }

  // Create new Order
  const randomSuffix = Math.random().toString(36).substring(2, 7).toUpperCase();
  const orderNumber = `ORD_${Date.now()}_${randomSuffix}`;

  // Check if there is an active conversation with specialPrice
  const conversation = await Conversation.findOne({
    itemId: item._id,
    $or: [
      { buyerId: userId, sellerId: item.sellerId },
      { buyerId: item.sellerId, sellerId: userId }
    ]
  });

  let effectivePriceCents = Math.round(item.price ?? 0);
  if (conversation && conversation.specialPrice !== undefined && conversation.specialPrice !== null) {
    effectivePriceCents = Math.round(Number(conversation.specialPrice) * 100);
  }

  const feeSettings = await getPlatformFeeSettings();
  const buyerFeeCents = effectivePriceCents > 0
    ? Math.max(feeSettings.minFeeCents, Math.round(effectivePriceCents * (feeSettings.buyerFeePercent / 100)))
    : 0;
  const buyerTotalAmount = effectivePriceCents + buyerFeeCents;

  const newOrder = await Order.create({
    orderNumber,
    itemId: item._id,
    buyerId: userId,
    sellerId: item.sellerId,
    status: 'pending_payment',
    itemAmount: effectivePriceCents,
    buyerFeeAmount: buyerFeeCents,
    buyerTotalAmount,
    sellerReceiveAmount: effectivePriceCents,
    itemSnapshot: {
      title: item.title,
      description: item.description,
      condition: item.condition,
      imageUrl: item.imageUrl ?? (item.images?.[0]?.url ?? '')
    }
  });

  const populatedOrder = await Order.findById(newOrder._id)
    .populate('buyerId', 'displayName avatarUrl email')
    .populate('sellerId', 'displayName avatarUrl email')
    .populate('itemId', 'title price images status category condition');

  ctx.status = 201;
  ctx.body = {
    status: 'success',
    order: formatOrder(populatedOrder, userId.toString())
  };
});

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
