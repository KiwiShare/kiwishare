import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';
import User from '../models/User';

const router = new Router();

// --- 3. QR Code Handover Endpoints ---

router.post('/transactions/handover/claim', authenticateToken, async (ctx) => {
  const { itemId, claimCode } = ctx.request.body as any;
  const claimerId = ctx.state.user.id; // User scanning the QR code to claim item

  if (!itemId || !claimCode) {
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

  const item = mongoose.Types.ObjectId.isValid(itemId)
    ? await Item.findById(itemId)
    : await Item.findOne({ id: itemId });

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

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Ownership transaction verified and committed successfully.',
    newOwnerId: claimerId
  };
});

export default router;
