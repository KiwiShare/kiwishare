import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';
import User from '../models/User';
import QrCode from '../models/QrCode';
import Order from '../models/Order';

const router = new Router();

// --- 3. QR Code Handover Endpoints ---

router.post('/transactions/handover/claim', authenticateToken, async (ctx) => {
  const { itemId, claimCode } = ctx.request.body as any;
  const claimerId = ctx.state.user.id; // User scanning the QR code to claim item

  if (!claimCode) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing transaction claiming parameters.' };
    return;
  }

  // Security Verification (OWASP Validation checks)
  if (!claimCode.startsWith('QR_HANDOVER_TOKEN_')) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Forbidden: Invalid QR handover claim code token.' };
    return;
  }

  // If itemId is not provided, look up by claimCode in QrCode collection
  let resolvedItemId = itemId;
  let qrRecord: any = null;
  let orderRecord: any = null;

  qrRecord = await QrCode.findOne({ tokenHash: claimCode });
  if (qrRecord) {
    if (qrRecord.status === 'consumed') {
      ctx.status = 409;
      ctx.body = { status: 'error', message: 'This handover QR code has already been claimed.' };
      return;
    }
    if (qrRecord.status === 'cancelled') {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'This meetup proposal was cancelled.' };
      return;
    }
    if (qrRecord.orderId) {
      orderRecord = await Order.findById(qrRecord.orderId);
      if (orderRecord && !resolvedItemId) {
        resolvedItemId = orderRecord.itemId;
      }
    }
  }

  if (!resolvedItemId) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Could not find transaction matching this QR code.' };
    return;
  }

  const item = mongoose.Types.ObjectId.isValid(resolvedItemId)
    ? await Item.findById(resolvedItemId)
    : await Item.findOne({ id: resolvedItemId });

  if (!item) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing item not found.' };
    return;
  }

  if (item.status === 'sold') {
    ctx.status = 409;
    ctx.body = { status: 'error', message: 'Conflict: Item is already transferred.' };
    return;
  }

  const currentOwnerId = item.sellerId ? item.sellerId.toString() : item.ownerId;
  if (currentOwnerId === claimerId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Self-claims are unauthorized.' };
    return;
  }

  // Update item status and owner ID
  const originalOwnerId = currentOwnerId;
  item.status = 'sold';
  item.sellerId = new mongoose.Types.ObjectId(claimerId);
  item.ownerId = claimerId;
  await item.save();

  // Atomically increment owner's trust reputation score in User database
  if (mongoose.Types.ObjectId.isValid(originalOwnerId)) {
    await User.updateOne({ _id: new mongoose.Types.ObjectId(originalOwnerId) }, { $inc: { trustScore: 5 } });
  } else {
    await User.updateOne({ id: originalOwnerId }, { $inc: { trustScore: 5 } });
  }

  // Update QR Code and Order status if found
  if (qrRecord) {
    qrRecord.status = 'consumed';
    qrRecord.scannedAt = new Date();
    qrRecord.consumedAt = new Date();
    qrRecord.scannedByUserId = new mongoose.Types.ObjectId(claimerId);
    await qrRecord.save();
  }

  if (orderRecord) {
    orderRecord.status = 'completed';
    orderRecord.completedAt = new Date();
    orderRecord.qrScannedAt = new Date();
    await orderRecord.save();
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Ownership transaction verified and committed successfully.',
    newOwnerId: claimerId,
    item: {
      id: item._id.toString(),
      title: item.title,
      priceNzd: item.priceNzd ?? (item.price != null ? item.price.toString() : '0'),
      imageUrl: item.imageUrl ?? (item.images?.[0]?.url ?? '')
    }
  };
});

export default router;
