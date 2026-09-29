import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';
import User from '../models/User';
import QrCode from '../models/QrCode';
import Order from '../models/Order';
import {
  MongoTransactionsRequiredError,
  runRequiredMongoTransaction
} from '../services/mongoTransaction';
import {
  isHandoverReady,
  isMeetupConfirmed,
  isOrderPaid
} from '../services/orderFlowState';

const router = new Router();
const COMPLETION_CREDIT_POINTS = 5;

class HandoverError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = 'HandoverError';
  }
}

class ConcurrentCompletionError extends Error {}

function sameId(left: unknown, right: unknown): boolean {
  return String(left ?? '') === String(right ?? '');
}

router.post('/transactions/handover/claim', authenticateToken, async (ctx) => {
  const { itemId, claimCode } = ctx.request.body as { itemId?: unknown; claimCode?: unknown };
  const claimerId = ctx.state.user.id;

  if (typeof claimCode !== 'string' || !claimCode.startsWith('QR_HANDOVER_TOKEN_')) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Forbidden: Invalid QR handover claim code token.' };
    return;
  }
  if (!mongoose.Types.ObjectId.isValid(claimerId)) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized user.' };
    return;
  }

  try {
    const result = await runRequiredMongoTransaction(async (session) => {
      const qr = await QrCode.findOne({ tokenHash: claimCode }).session(session);
      if (!qr) throw new HandoverError(404, 'Could not find transaction matching this QR code.');

      const order = await Order.findById(qr.orderId).session(session);
      if (!order) throw new HandoverError(404, 'The transaction for this QR code no longer exists.');

      const buyerId = order.buyerId.toString();
      const sellerId = order.sellerId.toString();
      const trustedItemId = order.itemId.toString();

      if (!sameId(qr.buyerId, buyerId) || !sameId(qr.sellerId, sellerId) ||
          (itemId != null && String(itemId) !== trustedItemId)) {
        throw new HandoverError(409, 'QR code transaction details do not match.');
      }
      if (buyerId === sellerId) throw new HandoverError(400, 'Self-transactions cannot be completed.');
      if (claimerId !== buyerId) {
        throw new HandoverError(403, 'Only the transaction buyer can confirm this handover.');
      }

      const item = await Item.findById(order.itemId).session(session);
      if (!item) throw new HandoverError(404, 'Listing item not found.');

      // Completed records are read-only. This covers safe retries and never
      // backfills rewards onto historical completions.
      if (order.status === 'completed') {
        return { alreadyCompleted: true, creditAwarded: false, item };
      }

      const itemSellerId = item.sellerId?.toString() ?? item.ownerId;
      if (!sameId(itemSellerId, sellerId)) {
        throw new HandoverError(409, 'The listing owner does not match this transaction.');
      }

      if (qr.status === 'cancelled') throw new HandoverError(400, 'This meetup proposal was cancelled.');
      if (qr.status !== 'active' || qr.expiresAt.getTime() <= Date.now()) {
        throw new HandoverError(400, 'This handover QR code is expired or unavailable.');
      }
      if (!isOrderPaid(order)) {
        throw new HandoverError(409, 'Order must be paid before handover.');
      }
      if (!isMeetupConfirmed(order)) {
        throw new HandoverError(409, 'Meetup must be confirmed before handover.');
      }
      if (!isHandoverReady(order) || order.status !== 'meeting_scheduled') {
        throw new HandoverError(409, 'This transaction is not eligible for completion.');
      }
      if (item.status === 'deleted') {
        throw new HandoverError(409, 'Conflict: Item is not available for handover.');
      }

      const participants = await User.countDocuments({
        _id: { $in: [order.buyerId, order.sellerId] }
      }).session(session);
      if (participants !== 2) throw new HandoverError(409, 'Both transaction participants must exist.');

      const now = new Date();
      const reservedOrder = await Order.updateOne(
        {
          _id: order._id,
          status: 'meeting_scheduled',
          'meeting.proposalStatus': 'confirmed',
          $or: [
            { paidAt: { $exists: true, $ne: null } },
            { itemAmount: 0, buyerTotalAmount: 0 }
          ],
          'completionCredit.awardedAt': { $exists: false }
        },
        { $set: { status: 'completed', completedAt: now, qrScannedAt: now,
          completionCredit: { pointsPerParticipant: COMPLETION_CREDIT_POINTS, awardedAt: now } } },
        { session }
      );
      if (reservedOrder.modifiedCount !== 1) {
        throw new ConcurrentCompletionError();
      }

      const consumedQr = await QrCode.updateOne(
        { _id: qr._id, status: 'active', expiresAt: { $gt: now } },
        { $set: { status: 'consumed', scannedAt: now, consumedAt: now,
          scannedByUserId: new mongoose.Types.ObjectId(claimerId) } },
        { session }
      );
      if (consumedQr.modifiedCount !== 1) {
        throw new HandoverError(409, 'This handover QR code is no longer available.');
      }

      const transferredItem = await Item.updateOne(
        { _id: item._id, sellerId: order.sellerId, status: { $ne: 'deleted' } },
        { $set: { status: 'sold', sellerId: order.buyerId, ownerId: buyerId } },
        { session }
      );
      if (transferredItem.modifiedCount !== 1) {
        throw new HandoverError(409, 'The listing changed before handover completed.');
      }

      const rewardedUsers = await User.updateMany(
        { _id: { $in: [order.buyerId, order.sellerId] } },
        { $inc: { trustScore: COMPLETION_CREDIT_POINTS } },
        { session }
      );
      if (rewardedUsers.matchedCount !== 2 || rewardedUsers.modifiedCount !== 2) {
        throw new HandoverError(409, 'Both transaction participants must receive credit together.');
      }
      return { alreadyCompleted: false, creditAwarded: true, item };
    });

    ctx.status = 200;
    ctx.body = {
      status: 'success',
      message: result.alreadyCompleted
        ? 'This handover was already completed.'
        : 'Ownership transaction verified and committed successfully.',
      newOwnerId: claimerId,
      completion: { alreadyCompleted: result.alreadyCompleted, creditAwarded: result.creditAwarded,
        pointsPerParticipant: result.creditAwarded ? COMPLETION_CREDIT_POINTS : 0 },
      item: { id: result.item._id.toString(), title: result.item.title,
        priceNzd: result.item.priceNzd ?? (result.item.price != null ? result.item.price.toString() : '0'),
        imageUrl: result.item.imageUrl ?? (result.item.images?.[0]?.url ?? '') }
    };
  } catch (error) {
    if (error instanceof ConcurrentCompletionError) {
      const qr = await QrCode.findOne({ tokenHash: claimCode });
      const order = qr ? await Order.findById(qr.orderId) : null;
      if (qr && order && order.status === 'completed' &&
          sameId(order.buyerId, claimerId) && sameId(qr.buyerId, claimerId)) {
        const item = await Item.findById(order.itemId);
        ctx.status = 200;
        ctx.body = {
          status: 'success',
          message: 'This handover was already completed.',
          newOwnerId: claimerId,
          completion: { alreadyCompleted: true, creditAwarded: false, pointsPerParticipant: 0 },
          item: item ? { id: item._id.toString(), title: item.title,
            priceNzd: item.priceNzd ?? (item.price != null ? item.price.toString() : '0'),
            imageUrl: item.imageUrl ?? (item.images?.[0]?.url ?? '') } : null
        };
        return;
      }
      ctx.status = 409;
      ctx.body = { status: 'error', message: 'Transaction completion is already in progress.' };
      return;
    }
    if (error instanceof HandoverError) {
      ctx.status = error.status;
      ctx.body = { status: 'error', message: error.message };
      return;
    }
    if (error instanceof MongoTransactionsRequiredError) {
      ctx.status = 503;
      ctx.body = { status: 'error', message: error.message };
      return;
    }
    throw error;
  }
});

export default router;
