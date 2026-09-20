import Router from 'koa-router';
import { Context } from 'koa';
import mongoose from 'mongoose';
import crypto from 'crypto';
import { authenticateToken } from '../middleware/auth';
import Order from '../models/Order';
import Item from '../models/Item';
import User from '../models/User';
import Conversation from '../models/Conversation';
import Message from '../models/Message';
import QrCode from '../models/QrCode';
import { notifyMeetupConfirmed, notifyMeetupPendingPayment } from '../services/pushNotification';
import { runMongoTransaction } from '../services/mongoTransaction';
import { getPlatformFeeSettings } from '../models/PlatformSetting';

const router = new Router({ prefix: '/meetups' });
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

export async function ensureOrderMeetupQr(order: any): Promise<string> {
  const existing = await QrCode.findOne({ orderId: order._id, status: 'active' });
  if (existing) {
    return existing.tokenHash;
  }
  const tokenRandom = crypto.randomBytes(8).toString('hex').toUpperCase();
  const claimCode = `QR_HANDOVER_TOKEN_${order._id.toString()}_${tokenRandom}`;
  await QrCode.findOneAndUpdate(
    { orderId: order._id },
    {
      orderId: order._id,
      sellerId: order.sellerId,
      buyerId: order.buyerId,
      tokenHash: claimCode,
      status: 'active',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    },
    { upsert: true, new: true }
  );
  return claimCode;
}

export function formatOrderMeetup(order: any, userId: string, qrCodeToken?: string | null) {
  const buyerId = objectId(order.buyerId);
  const sellerId = objectId(order.sellerId);
  const isBuyer = buyerId === userId;
  const buyerUser = order.buyerId as any;
  const sellerUser = order.sellerId as any;

  const isPaid = !!order.paidAt || ((order.itemAmount ?? 0) === 0 && (order.buyerTotalAmount ?? 0) === 0);

  return {
    id: objectId(order),
    orderNumber: order.orderNumber,
    itemId: objectId(order.itemId),
    itemTitle: order.itemSnapshot?.title ?? 'KiwiShare Item',
    itemPriceNzd: ((order.itemAmount ?? 0) / 100).toFixed(2),
    buyerFeeNzd: ((order.buyerFeeAmount ?? 0) / 100).toFixed(2),
    buyerTotalAmountNzd: ((order.buyerTotalAmount ?? order.itemAmount ?? 0) / 100).toFixed(2),
    isPaid,
    itemImageUrl: order.itemSnapshot?.imageUrl ?? '',
    status: order.status,
    role: isBuyer ? 'buying' : 'selling',
    buyerId,
    buyerName: buyerUser?.displayName ?? 'Buyer',
    buyerAvatarUrl: buyerUser?.avatarUrl ?? null,
    sellerId,
    sellerName: sellerUser?.displayName ?? 'Seller',
    sellerAvatarUrl: sellerUser?.avatarUrl ?? null,
    scheduledAt: order.meeting?.scheduledAt
      ? new Date(order.meeting.scheduledAt).toISOString()
      : null,
    locationName: order.meeting?.locationName ?? '',
    latitude: order.meeting?.latitude ?? null,
    longitude: order.meeting?.longitude ?? null,
    proposalStatus: order.meeting?.proposalStatus ?? 'proposed',
    proposedBy: objectId(order.meeting?.proposedBy),
    note: order.meeting?.note ?? '',
    qrToken: qrCodeToken ?? null,
    buyerConfirmedAt: order.buyerConfirmedAt ? new Date(order.buyerConfirmedAt).toISOString() : null,
    sellerConfirmedAt: order.sellerConfirmedAt ? new Date(order.sellerConfirmedAt).toISOString() : null,
    buyerConfirmed: Boolean(order.buyerConfirmedAt),
    sellerConfirmed: Boolean(order.sellerConfirmedAt),
    bothConfirmed: Boolean(order.status === 'completed' || (order.buyerConfirmedAt && order.sellerConfirmedAt)),
    createdAt: order.createdAt,
    updatedAt: order.updatedAt
  };
}

// 1. Propose or reschedule a meetup
router.post('/propose', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized user.' };
    return;
  }

  const { itemId, conversationId, scheduledAt, locationName, latitude, longitude, note } =
    ctx.request.body as {
      itemId?: string;
      conversationId?: string;
      scheduledAt?: string;
      locationName?: string;
      latitude?: number;
      longitude?: number;
      note?: string;
    };

  if (!itemId || !scheduledAt || !locationName || locationName.trim().length === 0) {
    ctx.status = 400;
    ctx.body = {
      status: 'error',
      message: 'Item ID, scheduled date/time, and location name are required.'
    };
    return;
  }

  const parsedDate = new Date(scheduledAt);
  if (Number.isNaN(parsedDate.getTime())) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid scheduled date and time.' };
    return;
  }

  const item = await Item.findById(itemId);
  if (!item) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Item listing not found.' };
    return;
  }

  const sellerId = item.sellerId
    ? new mongoose.Types.ObjectId(item.sellerId)
    : mongoose.Types.ObjectId.isValid(item.ownerId)
      ? new mongoose.Types.ObjectId(item.ownerId)
      : null;

  if (!sellerId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Item seller cannot be resolved.' };
    return;
  }

  const isSeller = sellerId.equals(userId);
  let buyerId: mongoose.Types.ObjectId;

  if (isSeller) {
    if (conversationId && mongoose.Types.ObjectId.isValid(conversationId)) {
      const conv = await Conversation.findById(conversationId);
      if (conv) {
        buyerId = conv.buyerId;
      } else {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'Could not resolve buyer conversation.' };
        return;
      }
    } else {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'Conversation ID is required when proposing as seller.' };
      return;
    }
  } else {
    buyerId = userId;
  }

  if (buyerId.equals(sellerId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Cannot schedule a meetup with yourself.' };
    return;
  }

  // Find or create Conversation
  let conversation = conversationId && mongoose.Types.ObjectId.isValid(conversationId)
    ? await Conversation.findById(conversationId)
    : null;

  if (!conversation) {
    conversation = await Conversation.findOne({
      itemId: item._id,
      buyerId,
      sellerId
    });
  }

  if (!conversation) {
    conversation = await Conversation.create({
      itemId: item._id,
      buyerId,
      sellerId,
      status: 'active',
      itemTitle: item.title,
      itemImageUrl: item.imageUrl ?? (item.images?.[0]?.url ?? '')
    });
  }

  // Find existing order for this item and buyer, or create new Order
  let order = await Order.findOne({
    itemId: item._id,
    buyerId,
    sellerId,
    status: { $in: ['pending_payment', 'meeting_scheduled', 'meeting_in_progress'] }
  });

  // Check if conversation has specialPrice or item price was modified
  let effectivePriceCents = Math.round(Number(item.price ?? 0));
  if (conversation && conversation.specialPrice !== undefined && conversation.specialPrice !== null) {
    effectivePriceCents = Math.round(Number(conversation.specialPrice) * 100);
  }

  const feeSettings = await getPlatformFeeSettings();
  const buyerFeeAmount = effectivePriceCents > 0
    ? Math.max(feeSettings.minFeeCents, Math.round(effectivePriceCents * (feeSettings.buyerFeePercent / 100)))
    : 0;

  if (order) {
    order.meeting = {
      scheduledAt: parsedDate,
      locationName: locationName.trim(),
      latitude: typeof latitude === 'number' ? latitude : undefined,
      longitude: typeof longitude === 'number' ? longitude : undefined,
      proposedBy: userId,
      proposalStatus: 'proposed',
      note: typeof note === 'string' ? note.trim() : undefined
    };
    order.status = 'meeting_scheduled';
    if (!order.paidAt) {
      order.itemAmount = effectivePriceCents;
      order.buyerFeeAmount = buyerFeeAmount;
      order.buyerTotalAmount = effectivePriceCents + buyerFeeAmount;
      order.sellerReceiveAmount = effectivePriceCents;
    }
    await order.save();
  } else {
    const randomSuffix = Math.random().toString(36).substring(2, 7).toUpperCase();
    const orderNumber = `ORD_${Date.now()}_${randomSuffix}`;
    order = await Order.create({
      orderNumber,
      itemId: item._id,
      buyerId,
      sellerId,
      status: 'meeting_scheduled',
      itemSnapshot: {
        title: item.title,
        description: item.description,
        condition: item.condition,
        imageUrl: item.imageUrl ?? (item.images?.[0]?.url ?? '')
      },
      currency: 'NZD',
      itemAmount: effectivePriceCents,
      buyerFeeAmount,
      sellerFeeAmount: 0,
      buyerTotalAmount: effectivePriceCents + buyerFeeAmount,
      sellerReceiveAmount: effectivePriceCents,
      meeting: {
        scheduledAt: parsedDate,
        locationName: locationName.trim(),
        latitude: typeof latitude === 'number' ? latitude : undefined,
        longitude: typeof longitude === 'number' ? longitude : undefined,
        proposedBy: userId,
        proposalStatus: 'proposed',
        note: typeof note === 'string' ? note.trim() : undefined
      }
    });
  }

  // Post meetup proposal message to the conversation
  const receiverId = isSeller ? buyerId : sellerId;
  const formattedDate = parsedDate.toLocaleDateString('en-NZ', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

  await runMongoTransaction(async (session) => {
    const meetupMessage = await new Message({
        conversationId: conversation._id,
        senderId: userId,
        receiverId,
        type: 'meetup',
        text: `📅 Proposed meetup: ${formattedDate} at ${locationName.trim()}`,
        meetup: {
          orderId: order._id,
          scheduledAt: parsedDate,
          locationName: locationName.trim(),
          latitude: typeof latitude === 'number' ? latitude : undefined,
          longitude: typeof longitude === 'number' ? longitude : undefined,
          proposalStatus: 'proposed',
          proposedBy: userId,
          note: typeof note === 'string' ? note.trim() : undefined
        },
        status: 'sent'
    }).save(session ? { session } : {});

    await Conversation.findByIdAndUpdate(
      conversation._id,
      {
        $set: {
            lastMessageText: `📅 Meetup proposed: ${formattedDate}`,
            lastMessageAt: meetupMessage.createdAt,
            lastMessageId: meetupMessage._id,
            lastMessageSenderId: userId
        },
        $inc: isSeller ? { buyerUnreadCount: 1 } : { sellerUnreadCount: 1 },
        $pull: { hiddenForUserIds: { $in: [userId, receiverId] } }
      },
      session ? { session } : {}
    );
  });

  const isOrderPaid = !!order.paidAt || ((order.itemAmount ?? 0) === 0 && (order.buyerTotalAmount ?? 0) === 0);
  if (!isOrderPaid) {
    void notifyMeetupPendingPayment({
      receiverId: new mongoose.Types.ObjectId(order.buyerId),
      orderId: order._id.toString(),
      itemId: objectId(order.itemId),
      itemTitle: order.itemSnapshot?.title ?? 'KiwiShare Item',
      locationName: locationName.trim()
    });
  }

  const populatedOrder = await Order.findById(order._id)
    .populate('buyerId', 'displayName avatarUrl')
    .populate('sellerId', 'displayName avatarUrl');

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    meetup: formatOrderMeetup(populatedOrder ?? order, userId.toString()),
    conversationId: conversation._id.toString()
  };
});

// 2. Accept a proposed meetup & generate transaction QR code
router.post('/:orderId/accept', async (ctx: Context) => {
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
    .populate('buyerId', 'displayName avatarUrl')
    .populate('sellerId', 'displayName avatarUrl');

  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Order not found.' };
    return;
  }

  const buyerId = objectId(order.buyerId);
  const sellerId = objectId(order.sellerId);
  const userStr = userId.toString();

  if (buyerId !== userStr && sellerId !== userStr) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Not authorized for this meetup.' };
    return;
  }

  const reqBody = (ctx.request.body as Record<string, any>) ?? {};
  const { messageId, scheduledAt, locationName, latitude, longitude, note } = reqBody;

  if (scheduledAt) {
    order.meeting = order.meeting ?? {};
    order.meeting.scheduledAt = new Date(scheduledAt);
  }
  if (locationName) {
    order.meeting = order.meeting ?? {};
    order.meeting.locationName = locationName;
  }
  if (latitude !== undefined) order.meeting.latitude = latitude;
  if (longitude !== undefined) order.meeting.longitude = longitude;
  if (note !== undefined) order.meeting.note = note;

  // Update order meeting status
  order.meeting = order.meeting ?? {};
  order.meeting.proposalStatus = 'confirmed';
  order.status = 'meeting_scheduled';
  await order.save();

  // Generate cryptographically unique QR handover token
  const tokenRandom = crypto.randomBytes(8).toString('hex').toUpperCase();
  const claimCode = `QR_HANDOVER_TOKEN_${order._id.toString()}_${tokenRandom}`;

  // Upsert QrCode
  await QrCode.findOneAndUpdate(
    { orderId: order._id },
    {
      orderId: order._id,
      sellerId: order.sellerId,
      buyerId: order.buyerId,
      tokenHash: claimCode,
      status: 'active',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    },
    { upsert: true, new: true }
  );

  // Post confirmation message to conversation
  const counterpartyId = buyerId === userStr ? sellerId : buyerId;
  const conversation = await Conversation.findOne({
    itemId: order.itemId,
    buyerId: order.buyerId,
    sellerId: order.sellerId
  });

  const scheduledDate = order.meeting.scheduledAt ? new Date(order.meeting.scheduledAt) : new Date();
  const formattedDate = scheduledDate.toLocaleDateString('en-NZ', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });

  if (conversation) {
    // 1. Update the accepted proposal message, or all proposal messages for this order
    if (messageId && mongoose.Types.ObjectId.isValid(messageId)) {
      await Message.findByIdAndUpdate(messageId, {
        $set: { 'meetup.proposalStatus': 'confirmed' }
      });
      // Cancel other proposals in the conversation so only one active proposal is accepted
      await Message.updateMany(
        {
          conversationId: conversation._id,
          _id: { $ne: new mongoose.Types.ObjectId(messageId) },
          type: 'meetup',
          'meetup.proposalStatus': { $in: ['proposed', 'confirmed'] }
        },
        {
          $set: { 'meetup.proposalStatus': 'cancelled' }
        }
      );
    } else {
      await Message.updateMany(
        { 'meetup.orderId': order._id, type: 'meetup' },
        { $set: { 'meetup.proposalStatus': 'confirmed' } }
      );
    }

    await runMongoTransaction(async (session) => {
      const confirmationMessage = await new Message({
        conversationId: conversation._id,
        senderId: userId,
        receiverId: new mongoose.Types.ObjectId(counterpartyId),
        type: 'meetup',
        text: `✅ Meetup confirmed: ${formattedDate} at ${order.meeting.locationName}`,
        meetup: {
          orderId: order._id,
          scheduledAt: order.meeting.scheduledAt,
          locationName: order.meeting.locationName,
          latitude: order.meeting.latitude,
          longitude: order.meeting.longitude,
          proposalStatus: 'confirmed',
          proposedBy: order.meeting.proposedBy
        },
        status: 'sent'
      }).save(session ? { session } : {});

      await Conversation.findByIdAndUpdate(
        conversation._id,
        {
          $set: {
            lastMessageText: `✅ Meetup confirmed: ${formattedDate}`,
            lastMessageAt: confirmationMessage.createdAt,
            lastMessageId: confirmationMessage._id,
            lastMessageSenderId: userId
          }
        },
        session ? { session } : {}
      );
    });

    const isPaid = !!order.paidAt || ((order.itemAmount ?? 0) === 0 && (order.buyerTotalAmount ?? 0) === 0);
    if (!isPaid) {
      const priceNzd = ((order.buyerTotalAmount ?? order.itemAmount ?? 0) / 100).toFixed(2);
      const paymentReqMsg = await new Message({
        conversationId: conversation._id,
        senderId: order.sellerId,
        receiverId: order.buyerId,
        type: 'text',
        text: `💳 [Payment Request] Meetup location confirmed! Seller requested payment of $${priceNzd} NZD to prepare for meetup handover.`,
        status: 'sent'
      }).save();

      await Conversation.findByIdAndUpdate(conversation._id, {
        $set: {
          lastMessageText: `💳 Payment request: $${priceNzd} NZD`,
          lastMessageAt: paymentReqMsg.createdAt,
          lastMessageId: paymentReqMsg._id,
          lastMessageSenderId: order.sellerId
        }
      });
    }
  }

  // Dispatch push notifications to both parties
  const pushRequest = {
    orderId: order._id.toString(),
    itemId: objectId(order.itemId),
    itemTitle: order.itemSnapshot?.title ?? 'KiwiShare Item',
    scheduledAt: scheduledDate.toISOString(),
    locationName: order.meeting.locationName ?? 'Agreed meetup spot'
  };

  void notifyMeetupConfirmed({ ...pushRequest, receiverId: new mongoose.Types.ObjectId(buyerId) });
  void notifyMeetupConfirmed({ ...pushRequest, receiverId: new mongoose.Types.ObjectId(sellerId) });

  const isConfirmedPaid = !!order.paidAt || ((order.itemAmount ?? 0) === 0 && (order.buyerTotalAmount ?? 0) === 0);
  if (!isConfirmedPaid) {
    void notifyMeetupPendingPayment({
      receiverId: new mongoose.Types.ObjectId(buyerId),
      orderId: order._id.toString(),
      itemId: objectId(order.itemId),
      itemTitle: order.itemSnapshot?.title ?? 'KiwiShare Item',
      locationName: order.meeting?.locationName
    });
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    meetup: formatOrderMeetup(order, userStr, claimCode)
  };
});

// 3. Decline or cancel a meetup proposal
router.post('/:orderId/decline', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized user.' };
    return;
  }

  const { orderId } = ctx.params;
  const order = await Order.findById(orderId);
  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Order not found.' };
    return;
  }

  const buyerId = objectId(order.buyerId);
  const sellerId = objectId(order.sellerId);
  const userStr = userId.toString();

  if (buyerId !== userStr && sellerId !== userStr) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Not authorized for this meetup.' };
    return;
  }

  order.meeting = order.meeting ?? {};
  order.meeting.proposalStatus = 'declined';
  await order.save();

  // Cancel any active QR codes for this order
  await QrCode.updateMany(
    { orderId: order._id, status: 'active' },
    { $set: { status: 'cancelled' } }
  );

  // Update messages matching this order proposal
  await Message.updateMany(
    { 'meetup.orderId': order._id, type: 'meetup', 'meetup.proposalStatus': 'proposed' },
    { $set: { 'meetup.proposalStatus': 'declined' } }
  );

  ctx.status = 200;
  ctx.body = { status: 'success', message: 'Meetup proposal declined.' };
});

// 4. Get all user meetups (Buying & Selling)
router.get('/my', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized user.' };
    return;
  }

  const orders = await Order.find({
    $or: [{ buyerId: userId }, { sellerId: userId }],
    'meeting.scheduledAt': { $exists: true, $ne: null }
  })
    .populate('buyerId', 'displayName avatarUrl')
    .populate('sellerId', 'displayName avatarUrl')
    .sort({ 'meeting.scheduledAt': -1 })
    .limit(50);

  // Fetch active QR codes for these orders
  const orderIds = orders.map((o) => o._id);
  const qrCodes = await QrCode.find({
    orderId: { $in: orderIds },
    status: 'active'
  }).lean();

  const qrMap = new Map<string, string>();
  for (const qr of qrCodes) {
    qrMap.set(qr.orderId.toString(), qr.tokenHash);
  }

  const meetups = orders.map((order) =>
    formatOrderMeetup(order, userId.toString(), qrMap.get(order._id.toString()))
  );

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    meetups
  };
});

// 5. Get meetup details by Order ID
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
    .populate('buyerId', 'displayName avatarUrl')
    .populate('sellerId', 'displayName avatarUrl');

  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Meetup not found.' };
    return;
  }

  const buyerId = objectId(order.buyerId);
  const sellerId = objectId(order.sellerId);
  const userStr = userId.toString();

  if (buyerId !== userStr && sellerId !== userStr) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Not authorized for this meetup.' };
    return;
  }

  const qrCode = (await QrCode.findOne({
    orderId: order._id,
    status: 'active'
  }).lean()) as any;

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    meetup: formatOrderMeetup(order, userStr, qrCode?.tokenHash)
  };
});

// 6. Direct confirmation of handover (by buyer as "Confirm Receipt" or seller as "Confirm Handover")
router.post('/:orderId/confirm-handover', async (ctx: Context) => {
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
    .populate('buyerId', 'displayName avatarUrl')
    .populate('sellerId', 'displayName avatarUrl');

  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Order not found.' };
    return;
  }

  const buyerId = objectId(order.buyerId);
  const sellerId = objectId(order.sellerId);
  const userStr = userId.toString();
  const isBuyer = buyerId === userStr;
  const isSeller = sellerId === userStr;

  if (!isBuyer && !isSeller) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Not authorized for this order.' };
    return;
  }

  if (order.status === 'completed') {
    ctx.status = 200;
    ctx.body = {
      status: 'success',
      message: 'This handover was already completed.',
      meetup: formatOrderMeetup(order, userStr)
    };
    return;
  }

  // Check state machine: Order must be paid and location confirmed
  const isPaid = !!order.paidAt || ((order.itemAmount ?? 0) === 0 && (order.buyerTotalAmount ?? 0) === 0);
  if (!isPaid && order.status === 'pending_payment') {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Order must be paid before completing handover.' };
    return;
  }

  const proposalStatus = order.meeting?.proposalStatus;
  if (proposalStatus !== 'confirmed' && proposalStatus !== 'accepted') {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Meetup location must be confirmed before completing handover.' };
    return;
  }

  const now = new Date();
  if (isBuyer) {
    order.buyerConfirmedAt = now;
  }
  if (isSeller) {
    order.sellerConfirmedAt = now;
  }

  const bothConfirmed = Boolean(order.buyerConfirmedAt && order.sellerConfirmedAt);
  const counterpartyId = isBuyer ? sellerId : buyerId;

  const conversation = await Conversation.findOne({
    itemId: order.itemId,
    buyerId: order.buyerId,
    sellerId: order.sellerId
  });

  if (bothConfirmed) {
    order.status = 'completed';
    order.completedAt = now;
    order.qrScannedAt = now;
    order.sellerPaidAt = now; // Money released to seller!
    if (!order.completionCredit?.awardedAt) {
      order.completionCredit = {
        pointsPerParticipant: 5,
        awardedAt: now
      };
    }
    await order.save();

    // Mark active QR as consumed
    await QrCode.updateMany(
      { orderId: order._id, status: 'active' },
      { $set: { status: 'consumed', scannedAt: now, consumedAt: now, scannedByUserId: userId } }
    );

    // Update item status and transfer ownership
    await Item.findByIdAndUpdate(order.itemId, {
      $set: { status: 'sold', sellerId: order.buyerId, ownerId: buyerId }
    });

    // Award trust score (+5 to each participant)
    await User.updateMany(
      { _id: { $in: [order.buyerId, order.sellerId] } },
      { $inc: { trustScore: 5 } }
    );

    // Post in-chat notification message to conversation
    if (conversation) {
      await new Message({
        conversationId: conversation._id,
        senderId: userId,
        receiverId: new mongoose.Types.ObjectId(counterpartyId),
        type: 'text',
        text: `🤝 [Transaction Completed] Both parties confirmed handover & receipt! Funds have been released to the seller. Please leave a review for each other!`,
        status: 'sent'
      }).save();

      await Conversation.findByIdAndUpdate(conversation._id, {
        $set: {
          lastMessageText: `🤝 Transaction completed! Funds released.`,
          lastMessageAt: now,
          lastMessageSenderId: userId
        }
      });
    }

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      message: 'Both parties confirmed! Transaction complete and funds have been released to the seller.',
      bothConfirmed: true,
      meetup: formatOrderMeetup(order, userStr)
    };
  } else {
    // Only one party has confirmed so far. Keep order active, funds held in escrow.
    await order.save();

    if (conversation) {
      const notice = isBuyer
        ? '📦 [Receipt Confirmed] Buyer confirmed receipt! Waiting for seller handover confirmation to release funds.'
        : '📦 [Handover Confirmed] Seller confirmed handover! Waiting for buyer receipt confirmation to release funds.';

      await new Message({
        conversationId: conversation._id,
        senderId: userId,
        receiverId: new mongoose.Types.ObjectId(counterpartyId),
        type: 'text',
        text: notice,
        status: 'sent'
      }).save();

      await Conversation.findByIdAndUpdate(conversation._id, {
        $set: {
          lastMessageText: isBuyer ? '📦 Buyer confirmed receipt' : '📦 Seller confirmed handover',
          lastMessageAt: now,
          lastMessageSenderId: userId
        }
      });
    }

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      message: isBuyer
        ? 'Receipt confirmed! Waiting for seller confirmation to release funds.'
        : 'Handover confirmed! Waiting for buyer confirmation to release funds.',
      bothConfirmed: false,
      meetup: formatOrderMeetup(order, userStr)
    };
  }
});

export default router;
