import { Context } from 'koa';
import Router from 'koa-router';
import mongoose from 'mongoose';
import {
  authenticateToken,
  authenticateTokenAllowExpired
} from '../middleware/auth';
import PushDevice, { PushPlatform } from '../models/PushDevice';
import User from '../models/User';

const router = new Router({ prefix: '/notifications' });
const MIN_TOKEN_LENGTH = 20;
const MAX_TOKEN_LENGTH = 4096;

function currentUserId(ctx: Context): mongoose.Types.ObjectId | null {
  const value = ctx.state.user?.id;
  return mongoose.Types.ObjectId.isValid(value)
    ? new mongoose.Types.ObjectId(value)
    : null;
}

function validToken(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const token = value.trim();
  return token.length >= MIN_TOKEN_LENGTH && token.length <= MAX_TOKEN_LENGTH
    ? token
    : null;
}

function validPlatform(value: unknown): value is PushPlatform {
  return value === 'android' || value === 'ios';
}

router.post('/devices', authenticateToken, async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const body = ctx.request.body as { token?: unknown; platform?: unknown };
  const token = validToken(body.token);
  if (!token || !validPlatform(body.platform)) {
    ctx.status = 400;
    ctx.body = {
      status: 'error',
      message: 'A valid device token and mobile platform are required.'
    };
    return;
  }

  // Token might belong to another user previously; safely reassign to this user
  await PushDevice.findOneAndUpdate(
    { token },
    {
      $set: {
        userId,
        platform: body.platform,
        active: true,
        lastSeenAt: new Date()
      }
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    device: { platform: body.platform }
  };
});

router.delete('/devices', authenticateTokenAllowExpired, async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const token = validToken((ctx.request.body as { token?: unknown }).token);
  if (!token) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'A valid device token is required.' };
    return;
  }

  await PushDevice.deleteOne({ userId, token });
  ctx.status = 200;
  ctx.body = { status: 'success' };
});

router.get('/preferences', authenticateToken, async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const user = (await User.findById(userId)
    .select('notificationPreferences')
    .lean()) as any;
  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Authenticated user not found.' };
    return;
  }
  ctx.status = 200;
  ctx.body = {
    status: 'success',
    preferences: {
      watchlistPriceDrop:
        user?.notificationPreferences?.watchlistPriceDrop ?? true
    }
  };
});

router.patch('/preferences', authenticateToken, async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const body = ctx.request.body as { watchlistPriceDrop?: unknown };
  if (typeof body.watchlistPriceDrop !== 'boolean') {
    ctx.status = 400;
    ctx.body = {
      status: 'error',
      message: 'watchlistPriceDrop must be a boolean value.'
    };
    return;
  }

  const updatedUser = await User.findByIdAndUpdate(
    userId,
    {
      $set: {
        'notificationPreferences.watchlistPriceDrop': body.watchlistPriceDrop
      }
    },
    { new: true }
  ).select('notificationPreferences');

  if (!updatedUser) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Authenticated user not found.' };
    return;
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    preferences: {
      watchlistPriceDrop:
        updatedUser?.notificationPreferences?.watchlistPriceDrop ?? true
    }
  };
});

export default router;
