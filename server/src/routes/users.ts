import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import User from '../models/User';
import Item from '../models/Item';
import { formatItem } from './usedItems';

const router = new Router();

// GET /users/me - Retrieve authenticated user profile
router.get('/users/me', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;

  const user = mongoose.Types.ObjectId.isValid(userId)
    ? await User.findById(userId)
    : await User.findOne({ id: userId });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      trustScore: user.trustScore,
      isVerified: user.isVerified,
      authProvider: user.authProvider
    }
  };
});

// PATCH /users/me - Update authenticated user profile
router.patch('/users/me', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;
  const { displayName, avatarUrl } = ctx.request.body as any;

  const user = mongoose.Types.ObjectId.isValid(userId)
    ? await User.findById(userId)
    : await User.findOne({ id: userId });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  if (displayName !== undefined) user.displayName = displayName;
  if (avatarUrl !== undefined) user.avatarUrl = avatarUrl;

  await user.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      trustScore: user.trustScore,
      isVerified: user.isVerified
    }
  };
});

// GET /users/me/usedItems - Retrieve items owned by authenticated user
async function getMyItemsHandler(ctx: any) {
  const userId = ctx.state.user.id;
  const { status } = ctx.query;

  const filter: any = {};
  if (mongoose.Types.ObjectId.isValid(userId)) {
    filter.$or = [
      { sellerId: new mongoose.Types.ObjectId(userId) },
      { ownerId: userId }
    ];
  } else {
    filter.ownerId = userId;
  }

  if (status) {
    if (status.includes(',')) {
      filter.status = { $in: status.split(',').map((s: string) => s.trim()) };
    } else {
      filter.status = status;
    }
  } else {
    filter.status = { $ne: 'deleted' };
  }

  const items = await Item.find(filter).sort({ createdAt: -1 });
  ctx.status = 200;
  ctx.body = items.map(formatItem);
}

router.get('/users/me/usedItems', authenticateToken, getMyItemsHandler);

export default router;
