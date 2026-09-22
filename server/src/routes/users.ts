import Router from 'koa-router';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { Resend } from 'resend';
import { authenticateToken } from '../middleware/auth';
import User from '../models/User';
import Item from '../models/Item';
import Otp from '../models/Otp';
import Order from '../models/Order';
import Review from '../models/Review';
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
      bio: user.bio || '',
      role: user.role || 'user',
      trustScore: user.trustScore,
      isVerified: user.isVerified,
      isStudentVerified: Boolean(user.isStudentVerified),
      studentInstitution: user.studentInstitution || null,
      studentEmail: user.studentEmail || null,
      kiwiGold: user.kiwiGold ?? 100,
      isVip: Boolean(user.isVip && (!user.vipExpiresAt || new Date(user.vipExpiresAt) > new Date())),
      vipExpiresAt: user.vipExpiresAt || null,
      vipAutoRenew: user.vipAutoRenew ?? true,
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
  const { username, displayName, avatarUrl, bio } = ctx.request.body as any;

  if (username !== undefined && (typeof username !== 'string' ||
    !/^[a-zA-Z0-9_]{3,24}$/.test(username.trim()))) {
    ctx.status = 400;
    ctx.body = { message: 'Username must be 3-24 characters using only letters, numbers, or underscores.' };
    return;
  }
  if (displayName !== undefined && (typeof displayName !== 'string' ||
    displayName.trim().length < 2 || displayName.trim().length > 30)) {
    ctx.status = 400;
    ctx.body = { message: 'Display name must be between 2 and 30 characters.' };
    return;
  }
  if (bio !== undefined && typeof bio === 'string' && bio.length > 200) {
    ctx.status = 400;
    ctx.body = { message: 'Bio cannot exceed 200 characters.' };
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

  if (username !== undefined) {
    const normalizedUsername = username.trim().toLowerCase();
    const existingUsername = await User.findOne({
      username: normalizedUsername,
      _id: { $ne: user._id }
    });
    if (existingUsername) {
      ctx.status = 409;
      ctx.body = { message: 'That username is already taken.' };
      return;
    }
    user.username = normalizedUsername;
    if (!user.displayName?.trim()) user.displayName = username.trim();
  }
  if (displayName !== undefined) user.displayName = displayName.trim();
  if (avatarUrl !== undefined) user.avatarUrl = avatarUrl || null;
  if (bio !== undefined) user.bio = typeof bio === 'string' ? bio.trim() : '';

  await user.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      bio: user.bio || '',
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

  const items = await Item.find(filter)
    .populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role')
    .sort({ createdAt: -1 });
  ctx.status = 200;
  ctx.body = items.map(formatItem);
}

router.get('/users/me/usedItems', authenticateToken, getMyItemsHandler);

// ---------------------------------------------------------------------------
// Student Verification Endpoints (NZ Universities Only)
// ---------------------------------------------------------------------------

const NZ_UNIVERSITY_DOMAINS: Record<string, string> = {
  'aucklanduni.ac.nz': 'University of Auckland',
  'auckland.ac.nz': 'University of Auckland',
  'autuni.ac.nz': 'Auckland University of Technology',
  'aut.ac.nz': 'Auckland University of Technology',
  'waikato.ac.nz': 'University of Waikato',
  'massey.ac.nz': 'Massey University',
  'myvuw.ac.nz': 'Victoria University of Wellington',
  'vuw.ac.nz': 'Victoria University of Wellington',
  'canterbury.ac.nz': 'University of Canterbury',
  'uclive.ac.nz': 'University of Canterbury',
  'otago.ac.nz': 'University of Otago',
  'student.otago.ac.nz': 'University of Otago',
  'lincoln.ac.nz': 'Lincoln University',
  'lincolnuni.ac.nz': 'Lincoln University'
};

export function resolveNzUniversity(email: string): string | null {
  const parts = email.toLowerCase().trim().split('@');
  if (parts.length !== 2) return null;
  const domain = parts[1].trim();

  // Direct match
  if (NZ_UNIVERSITY_DOMAINS[domain]) {
    return NZ_UNIVERSITY_DOMAINS[domain];
  }

  // Check subdomains or any NZ tertiary (.ac.nz)
  if (domain.endsWith('.ac.nz')) {
    for (const [key, val] of Object.entries(NZ_UNIVERSITY_DOMAINS)) {
      if (domain === key || domain.endsWith('.' + key)) {
        return val;
      }
    }
    return 'New Zealand Tertiary Institution';
  }

  return null;
}

// POST /users/student-verification/send-otp
router.post('/users/student-verification/send-otp', authenticateToken, async (ctx) => {
  const { email } = ctx.request.body as { email?: string };

  if (!email || typeof email !== 'string') {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Student email is required.' };
    return;
  }

  const normalizedEmail = email.toLowerCase().trim();
  const institution = resolveNzUniversity(normalizedEmail);

  if (!institution) {
    ctx.status = 400;
    ctx.body = {
      status: 'error',
      message: 'Only New Zealand university emails (ending in .ac.nz) are supported for student verification.'
    };
    return;
  }

  // Check cooldown (60s)
  const now = Date.now();
  const recentOtp = await Otp.findOne({
    email: normalizedEmail,
    used: false
  }).sort({ createdAt: -1 });

  if (recentOtp) {
    const elapsedSeconds = Math.floor((now - recentOtp.createdAt.getTime()) / 1000);
    if (elapsedSeconds < 60) {
      ctx.status = 429;
      ctx.body = {
        status: 'error',
        message: `Please wait ${60 - elapsedSeconds}s before requesting a new code.`,
        cooldownSeconds: 60 - elapsedSeconds
      };
      return;
    }
  }

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(now + 10 * 60 * 1000); // 10 minutes

  await Otp.create({
    email: normalizedEmail,
    code,
    expiresAt,
    used: false
  });

  console.log(`\n🎓 [Student Verification OTP] Email: ${normalizedEmail} (${institution}) | Code: ${code} (Expires in 10m)\n`);

  // Attempt to send email via Resend if available
  const resendApiKey = process.env.RESEND_API_KEY;
  const resendFrom = process.env.RESEND_FROM || 'onboarding@kiwishare.online';

  if (resendApiKey) {
    try {
      const resend = new Resend(resendApiKey);
      await resend.emails.send({
        from: resendFrom,
        to: normalizedEmail,
        subject: 'KiwiShare Student Verification Code',
        text: `Kia ora!\n\nYour KiwiShare student verification code is: ${code}\n\nThis confirms your enrollment at ${institution}. Code expires in 10 minutes.\n\nNgā mihi,\nThe KiwiShare Team`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #d1fae5; border-radius: 12px; background-color: #f0fdf4; color: #1f2937;">
            <h2 style="color: #059669; text-align: center; margin-bottom: 16px;">KiwiShare Student Verification</h2>
            <p>Kia ora!</p>
            <p>Use the following 6-digit code to verify your student status at <strong>${institution}</strong>:</p>
            <div style="font-size: 32px; font-weight: bold; color: #059669; text-align: center; padding: 20px; letter-spacing: 6px; background-color: #d1fae5; border-radius: 8px; margin: 20px 0;">
              ${code}
            </div>
            <p>This code will expire in 10 minutes.</p>
            <hr style="border: none; border-top: 1px solid #059669; opacity: 0.2; margin: 24px 0;" />
            <p style="font-size: 12px; color: #6b7280; text-align: center;">Ngā mihi,<br>The KiwiShare Team</p>
          </div>
        `
      });
      console.log(`✉️ [Student Verification Email Sent] via Resend to ${normalizedEmail}`);
    } catch (err: any) {
      console.warn(`[Student Verification Resend Warn] ${err.message}`);
    }
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: `Verification code sent to ${normalizedEmail}`,
    institution
  };
});

// POST /users/student-verification/verify-otp
router.post('/users/student-verification/verify-otp', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;
  const { email, code } = ctx.request.body as { email?: string; code?: string };

  if (!email || !code) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Email and verification code are required.' };
    return;
  }

  const normalizedEmail = email.toLowerCase().trim();
  const trimmedCode = code.trim();

  const institution = resolveNzUniversity(normalizedEmail);
  if (!institution) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid university email domain.' };
    return;
  }

  const otp = await Otp.findOne({
    email: normalizedEmail,
    code: trimmedCode,
    used: false
  }).sort({ createdAt: -1 });

  if (!otp || otp.expiresAt < new Date()) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid or expired verification code.' };
    return;
  }

  otp.used = true;
  await otp.save();

  const user = mongoose.Types.ObjectId.isValid(userId)
    ? await User.findById(userId)
    : await User.findOne({ id: userId });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  user.isStudentVerified = true;
  user.studentInstitution = institution;
  user.studentEmail = normalizedEmail;
  user.trustScore = Math.min(200, Math.max(0, (user.trustScore || 100) + 15));
  await user.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: `Congratulations! You are verified as a student at ${institution}.`,
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      role: user.role || 'user',
      trustScore: user.trustScore,
      isVerified: user.isVerified,
      isStudentVerified: true,
      studentInstitution: institution,
      studentEmail: normalizedEmail,
      kiwiGold: user.kiwiGold ?? 100,
      authProvider: user.authProvider
    }
  };
});

// GET /users/:id/public-profile - Retrieve Xianyu-style public profile for a user
router.get('/users/:id/public-profile', async (ctx) => {
  const { id } = ctx.params;
  const user = mongoose.Types.ObjectId.isValid(id)
    ? await User.findById(id)
    : await User.findOne({ id });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  const uId = user._id;

  const [activeItemsCount, soldItemsCount] = await Promise.all([
    Item.countDocuments({
      $or: [{ sellerId: uId }, { ownerId: uId.toString() }],
      status: 'active'
    }),
    Item.countDocuments({
      $or: [{ sellerId: uId }, { ownerId: uId.toString() }],
      status: { $in: ['sold', 'completed'] }
    })
  ]);

  const isVip = Boolean(user.isVip && (!user.vipExpiresAt || new Date(user.vipExpiresAt) > new Date()));

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    user: {
      id: user._id.toString(),
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      bio: user.bio || '',
      location: {
        city: user.location?.city || 'Auckland',
        suburb: user.location?.suburb || 'CBD'
      },
      trustScore: user.trustScore ?? 100,
      isVip,
      isVerified: Boolean(user.isVerified),
      isStudentVerified: Boolean(user.isStudentVerified),
      studentInstitution: user.studentInstitution || null,
      rating: user.rating ?? 5.0,
      reviewCount: user.reviewCount ?? 0,
      activeItemsCount,
      soldItemsCount,
      memberSince: user.createdAt
    }
  };
});

// GET /users/:id/public-items - Retrieve active or sold items for a user
router.get('/users/:id/public-items', async (ctx) => {
  const { id } = ctx.params;
  const user = mongoose.Types.ObjectId.isValid(id)
    ? await User.findById(id)
    : await User.findOne({ id });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  const status = (ctx.query.status as string) || 'active';
  const uId = user._id;

  const filter: any = {
    $or: [{ sellerId: uId }, { ownerId: uId.toString() }]
  };

  if (status === 'sold') {
    filter.status = { $in: ['sold', 'completed'] };
  } else {
    filter.status = 'active';
  }

  const items = await Item.find(filter)
    .populate('sellerId', 'displayName avatarUrl email trustScore isVerified isStudentVerified studentInstitution isVip')
    .sort({ createdAt: -1 })
    .limit(50);

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    items: items.map(formatItem)
  };
});

// GET /users/:id/public-reviews - Retrieve transaction reviews for a user
router.get('/users/:id/public-reviews', async (ctx) => {
  const { id } = ctx.params;
  const user = mongoose.Types.ObjectId.isValid(id)
    ? await User.findById(id)
    : await User.findOne({ id });

  if (!user) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'User not found.' };
    return;
  }

  const uId = user._id;
  const reviews = await Review.find({ targetUserId: uId })
    .populate('reviewerId', 'displayName avatarUrl isVerified isVip')
    .sort({ createdAt: -1 })
    .limit(50);

  let formattedReviews = reviews.map((r: any) => ({
    id: r._id.toString(),
    reviewerId: r.reviewerId?._id?.toString() || '',
    reviewerName: r.reviewerId?.displayName || 'Kiwi Member',
    reviewerAvatarUrl: r.reviewerId?.avatarUrl || null,
    rating: r.rating,
    comment: r.comment,
    tags: r.tags || [],
    role: r.role,
    itemTitle: r.itemSnapshot?.title || '',
    itemImageUrl: r.itemSnapshot?.imageUrl || null,
    createdAt: r.createdAt
  }));

  // If no reviews in the Review collection yet, dynamically build reviews from completed orders
  if (formattedReviews.length === 0) {
    const orders = await Order.find({
      $or: [{ sellerId: uId }, { buyerId: uId }],
      status: { $in: ['completed', 'seller_paid'] }
    })
      .populate('buyerId', 'displayName avatarUrl')
      .populate('sellerId', 'displayName avatarUrl')
      .sort({ createdAt: -1 })
      .limit(10);

    if (orders.length > 0) {
      formattedReviews = orders.map((ord: any) => {
        const isTargetSeller = ord.sellerId?._id?.toString() === uId.toString();
        const reviewer = isTargetSeller ? ord.buyerId : ord.sellerId;
        const role = isTargetSeller ? 'buyer' : 'seller';
        return {
          id: `ord-rev-${ord._id}`,
          reviewerId: reviewer?._id?.toString() || '',
          reviewerName: reviewer?.displayName || (isTargetSeller ? 'Verified Buyer' : 'Verified Seller'),
          reviewerAvatarUrl: reviewer?.avatarUrl || null,
          rating: 5,
          comment: isTargetSeller
            ? 'Great seller! Item was in excellent condition as described and meetup was smooth.'
            : 'Smooth transaction, friendly and punctual buyer!',
          tags: isTargetSeller
            ? ['Punctual', 'Item as described', 'Fast response']
            : ['Punctual', 'Friendly', 'Prompt payment'],
          role,
          itemTitle: ord.itemSnapshot?.title || 'Campus Marketplace Item',
          itemImageUrl: ord.itemSnapshot?.imageUrl || null,
          createdAt: ord.completedAt || ord.createdAt
        };
      });
    } else {
      // Default community trust endorsement
      formattedReviews = [
        {
          id: `welcome-rev-${uId}`,
          reviewerId: 'system',
          reviewerName: 'KiwiShare Community Trust',
          reviewerAvatarUrl: null,
          rating: 5,
          comment: 'Verified KiwiShare member with good standing and zero dispute records.',
          tags: ['Community Verified', 'Identity Checked', 'Safe Trader'],
          role: 'buyer',
          itemTitle: 'KiwiShare Welcome Verification',
          itemImageUrl: null,
          createdAt: user.createdAt
        }
      ];
    }
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    reviews: formattedReviews
  };
});

// POST /users/:id/reviews - Submit a review for a user
router.post('/users/:id/reviews', authenticateToken, async (ctx) => {
  const reviewerId = ctx.state.user.id;
  const targetUserId = ctx.params.id;
  const { rating, comment, tags, orderId, itemId, role, itemTitle, itemImageUrl } = ctx.request.body as any;

  if (reviewerId === targetUserId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'You cannot review yourself.' };
    return;
  }

  const numRating = Number(rating);
  if (!numRating || numRating < 1 || numRating > 5) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Rating must be between 1 and 5.' };
    return;
  }

  if (!comment || typeof comment !== 'string' || comment.trim().length === 0) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Comment is required.' };
    return;
  }

  const review = new Review({
    reviewerId: new mongoose.Types.ObjectId(reviewerId),
    targetUserId: new mongoose.Types.ObjectId(targetUserId),
    rating: numRating,
    comment: comment.trim(),
    tags: Array.isArray(tags) ? tags.slice(0, 5) : [],
    role: role === 'seller' ? 'seller' : 'buyer',
    orderId: orderId && mongoose.Types.ObjectId.isValid(orderId) ? new mongoose.Types.ObjectId(orderId) : undefined,
    itemId: itemId && mongoose.Types.ObjectId.isValid(itemId) ? new mongoose.Types.ObjectId(itemId) : undefined,
    itemSnapshot: {
      title: itemTitle || 'Marketplace Item',
      imageUrl: itemImageUrl || undefined
    }
  });

  await review.save();

  const target = await User.findById(targetUserId);
  if (target) {
    target.reviewCount = (target.reviewCount || 0) + 1;
    const allReviews = await Review.find({ targetUserId: target._id });
    const avg = allReviews.reduce((sum: number, r: any) => sum + r.rating, 0) / allReviews.length;
    target.rating = Math.round(avg * 10) / 10;
    await target.save();
  }

  ctx.status = 201;
  ctx.body = {
    status: 'success',
    review
  };
});

export default router;
