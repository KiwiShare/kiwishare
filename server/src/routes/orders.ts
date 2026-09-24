import Router from 'koa-router';
import { Context } from 'koa';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Order from '../models/Order';
import Item from '../models/Item';
import Conversation from '../models/Conversation';
import Message from '../models/Message';
import Payment from '../models/Payment';
import Refund from '../models/Refund';
import { getPlatformFeeSettings } from '../models/PlatformSetting';
import { resolveOrderEffectivePriceCents } from './payments';
import { createStripeRefund } from '../services/stripeService';

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
    completedAt: order.completedAt || null,
    refundedAt: order.refundedAt ? new Date(order.refundedAt).toISOString() : null
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
  const order = await Order.findOne({
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

  // If item is already sold and user has no existing order, block concurrent purchase
  if (item.status === 'sold') {
    ctx.status = 409;
    ctx.body = { status: 'error', message: 'This item has already been sold and is no longer available.' };
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

// 1.5 Get latest order by itemId for current user
router.get('/by-item/:itemId', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Authentication required.' };
    return;
  }
  const { itemId } = ctx.params;
  if (!mongoose.Types.ObjectId.isValid(itemId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid item ID.' };
    return;
  }
  const order = await Order.findOne({
    itemId,
    $or: [{ buyerId: userId }, { sellerId: userId }]
  })
    .sort({ createdAt: -1 })
    .populate('buyerId', 'displayName avatarUrl email')
    .populate('sellerId', 'displayName avatarUrl email')
    .populate('itemId', 'title price images status category condition');

  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Order not found for this item.' };
    return;
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    order: formatOrder(order, userId.toString())
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

// 3. POST /:orderId/refund - Process order refund and relist item
router.post('/:orderId/refund', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Authentication required.' };
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
  const isSeller = sellerId === currentIdStr;
  const isBuyer = buyerId === currentIdStr;

  if (!isSeller && !isBuyer) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Forbidden: You are not a party to this order.' };
    return;
  }

  if (order.status === 'refunded') {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'This order has already been refunded.' };
    return;
  }

  if (order.status === 'completed') {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Completed orders cannot be refunded.' };
    return;
  }

  if (!order.paidAt) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Cannot refund an unpaid order.' };
    return;
  }

  // If buyer is requesting, verify >= 48 hours have elapsed without a confirmed meetup
  if (isBuyer) {
    const paidTime = order.paidAt ? new Date(order.paidAt).getTime() : new Date(order.createdAt).getTime();
    const hoursSincePaid = (Date.now() - paidTime) / (1000 * 60 * 60);
    const isMeetupConfirmed =
      order.meeting?.proposalStatus === 'confirmed' ||
      order.meeting?.proposalStatus === 'accepted';

    if (hoursSincePaid < 48 && !isMeetupConfirmed) {
      ctx.status = 400;
      ctx.body = {
        status: 'error',
        message: 'Auto-refund is available 2 days (48 hours) after payment if no meetup is scheduled. You may message the seller to request an immediate refund.'
      };
      return;
    }
  }

  const { reason } = (ctx.request.body as any) || {};

  // Attempt Stripe refund if payment exists
  const payment = await Payment.findOne({ orderId: order._id });
  let stripeRefundId: string | undefined;

  if (payment && payment.stripePaymentIntentId) {
    try {
      const refundResult = await createStripeRefund({
        paymentIntentId: payment.stripePaymentIntentId,
        amountCents: order.buyerTotalAmount || order.itemAmount || undefined,
        reason: 'requested_by_customer'
      });
      stripeRefundId = refundResult.id;
      payment.status = 'refunded';
      payment.refundedAmount = order.buyerTotalAmount || order.itemAmount || 0;
      await payment.save();
    } catch (err: any) {
      ctx.status = 502;
      ctx.body = {
        status: 'error',
        message: err.message || 'Stripe refund failed. The order remains paid and the listing remains sold.'
      };
      return;
    }
  }

  // Create Refund record
  try {
    await Refund.create({
      orderId: order._id,
      paymentId: payment?._id || new mongoose.Types.ObjectId(),
      requestedByUserId: userId,
      reason: isSeller ? 'seller_cancelled' : 'buyer_cancelled',
      amount: order.buyerTotalAmount || order.itemAmount || 0,
      currency: 'NZD',
      status: 'succeeded',
      stripeRefundId,
      idempotencyKey: `ref_${order._id}_${Date.now()}`,
      processedAt: new Date()
    });
  } catch (err: any) {
    console.warn('[Orders] Refund record creation notice:', err.message);
  }

  // Update order status
  order.status = 'refunded';
  order.refundedAt = new Date();
  order.cancellation = {
    cancelledBy: userId,
    reason: reason || (isSeller ? 'Seller initiated refund' : 'Buyer refund (no meetup scheduled in 2 days)'),
    cancelledAt: new Date()
  };
  await order.save();

  // Immediately relist the item back to active
  await Item.findByIdAndUpdate(order.itemId, { status: 'active' });

  // Post system notice in conversation
  try {
    const conversation = await Conversation.findOne({
      itemId: order.itemId,
      $or: [
        { buyerId: order.buyerId, sellerId: order.sellerId },
        { buyerId: order.sellerId, sellerId: order.buyerId }
      ]
    });
    if (conversation) {
      const counterpartyId = isSeller ? order.buyerId : order.sellerId;
      const amountNzd = ((order.buyerTotalAmount || order.itemAmount || 0) / 100).toFixed(2);
      await new Message({
        conversationId: conversation._id,
        senderId: userId,
        receiverId: counterpartyId,
        type: 'text',
        text: `🔄 [Refund Processed] Order #${order.orderNumber} has been refunded ($${amountNzd} NZD). The item has been relisted and is now active.`,
        status: 'sent'
      }).save();

      await Conversation.findByIdAndUpdate(conversation._id, {
        $set: {
          lastMessageText: `🔄 Order refunded ($${amountNzd} NZD). Item relisted.`,
          lastMessageAt: new Date(),
          lastMessageSenderId: userId
        }
      });
    }
  } catch (err: any) {
    console.warn('[Orders] Refund message notice:', err.message);
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Order refunded and item relisted successfully.',
    order: formatOrder(order, currentIdStr)
  };
});

export default router;
