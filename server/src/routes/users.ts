import Router from 'koa-router';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { Resend } from 'resend';
import { authenticateToken } from '../middleware/auth';
import User from '../models/User';
import Item from '../models/Item';
import Otp from '../models/Otp';
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
      isStudentVerified: Boolean(user.isStudentVerified),
      studentInstitution: user.studentInstitution || null,
      studentEmail: user.studentEmail || null,
      kiwiGold: user.kiwiGold ?? 10,
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
  user.trustScore = Math.min(100, Math.max(80, (user.trustScore || 80) + 15));
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
      kiwiGold: user.kiwiGold ?? 10,
      authProvider: user.authProvider
    }
  };
});

export default router;
