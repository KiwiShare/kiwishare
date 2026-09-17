import Router from 'koa-router';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
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
      role: user.role || 'user',
      trustScore: user.trustScore,
      isVerified: user.isVerified,
      authProvider: user.authProvider,
      registrationPlatform: user.registrationPlatform,
      lastUsedPlatform: user.lastUsedPlatform,
      lastActiveAt: user.lastActiveAt
    }
  };
});

// PATCH /users/me - Update authenticated user profile
router.patch('/users/me', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;
  const { displayName, avatarUrl } = ctx.request.body as any;

  if (displayName !== undefined && (typeof displayName !== 'string' ||
    displayName.trim().length < 2 || displayName.trim().length > 30)) {
    ctx.status = 400;
    ctx.body = { message: 'Display name must be between 2 and 30 characters.' };
    return;
  }
  if (avatarUrl !== undefined && avatarUrl !== null && avatarUrl !== '') {
    let valid = false;
    if (typeof avatarUrl === 'string' && avatarUrl.length <= 2048) {
      try {
        const url = new URL(avatarUrl);
        valid = ['https:', 'http:'].includes(url.protocol) && !url.username && !url.password;
      } catch { /* Reject malformed URLs. */ }
    }
    if (!valid) {
      ctx.status = 400;
      ctx.body = { message: 'Avatar must be an HTTP image URL or null.' };
      return;
    }
  }

  const user = mongoose.Types.ObjectId.isValid(userId)
    ? await User.findById(userId)
    : await User.findOne({ id: userId });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  if (displayName !== undefined) user.displayName = displayName.trim();
  if (avatarUrl !== undefined) user.avatarUrl = avatarUrl || null;

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

// PATCH /users/me/password - Change password for local email/password users
router.patch('/users/me/password', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;
  const { currentPassword, newPassword } = ctx.request.body as any;

  if (typeof currentPassword !== 'string' || typeof newPassword !== 'string') {
    ctx.status = 400;
    ctx.body = { message: 'Current password and new password are required.' };
    return;
  }
  if (newPassword.length < 8 || newPassword.length > 128) {
    ctx.status = 400;
    ctx.body = { message: 'New password must be between 8 and 128 characters.' };
    return;
  }

  const user = mongoose.Types.ObjectId.isValid(userId)
    ? await User.findById(userId).select('+passwordHash')
    : await User.findOne({ id: userId }).select('+passwordHash');

  if (!user || user.authProvider !== 'email_password' || !user.passwordHash) {
    ctx.status = 400;
    ctx.body = { message: 'Password changes are unavailable for this account.' };
    return;
  }
  if (!(await bcrypt.compare(currentPassword, user.passwordHash))) {
    ctx.status = 401;
    ctx.body = { message: 'Current password is incorrect.' };
    return;
  }
  if (currentPassword === newPassword) {
    ctx.status = 400;
    ctx.body = { message: 'New password must be different from your current password.' };
    return;
  }

  user.passwordHash = await bcrypt.hash(newPassword, 12);
  await user.save();
  ctx.status = 204;
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
