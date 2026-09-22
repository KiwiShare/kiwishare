import Router from 'koa-router';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import nodemailer from 'nodemailer';
import { Resend } from 'resend';
import User from '../models/User';
import Otp from '../models/Otp';
import { resolveClientPlatform } from '../middleware/logger';
import { getJwtSecret } from '../middleware/auth';
import { configuredFirebaseApp } from '../services/pushNotification';

const router = new Router();

async function sendVerificationEmail(options: {
  to: string;
  subject: string;
  text: string;
  html: string;
}) {
  const resendApiKey = process.env.RESEND_API_KEY;
  const resendFrom = process.env.RESEND_FROM || 'onboarding@resend.dev';

  if (resendApiKey) {
    try {
      const resend = new Resend(resendApiKey);
      const result = await resend.emails.send({
        from: resendFrom,
        to: options.to,
        subject: options.subject,
        text: options.text,
        html: options.html
      });
      if (result.error) {
        console.error('[Resend Email Error] Failed to send email via Resend:', result.error);
      } else {
        return true;
      }
    } catch (error: any) {
      console.error(`❌ [Resend Email Error] Failed to send email via Resend: ${error.message || error}`);
    }
  }

  const smtpHost = process.env.SMTP_HOST;
  const smtpPort = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT) : 465;
  const smtpSecure = process.env.SMTP_SECURE === 'true' || smtpPort === 465;
  const smtpUser = process.env.SMTP_USER;
  const smtpPass = process.env.SMTP_PASS;
  const smtpFrom = process.env.SMTP_FROM || `"KiwiShare" <${smtpUser}>`;

  if (smtpHost && smtpUser && smtpPass) {
    try {
      const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: smtpPort,
        secure: smtpSecure,
        auth: {
          user: smtpUser,
          pass: smtpPass
        }
      });
      await transporter.sendMail({
        from: smtpFrom,
        to: options.to,
        subject: options.subject,
        text: options.text,
        html: options.html
      });
      return true;
    } catch (error: any) {
      console.error(`❌ [SMTP Email Error] Failed to send email via SMTP: ${error.message || error}`);
    }
  }

  return false;
}

function verificationEmailHtml(code: string, intro: string) {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #f2e8db; border-radius: 12px; background-color: #faf7f2; color: #1f1f1f;">
      <h2 style="color: #2e5e4e; text-align: center; margin-bottom: 24px;">KiwiShare</h2>
      <p>Kia ora!</p>
      <p>${intro}</p>
      <div style="font-size: 32px; font-weight: bold; color: #c96b4a; text-align: center; padding: 20px; letter-spacing: 4px; background-color: #f2e8db; border-radius: 8px; margin: 20px 0;">
        ${code}
      </div>
      <p>This code will expire in 10 minutes. Please do not share this code with anyone.</p>
      <hr style="border: none; border-top: 1px solid #2e5e4e; opacity: 0.1; margin: 30px 0;" />
      <p style="font-size: 12px; color: #1f1f1f; opacity: 0.6; text-align: center;">Ngā mihi,<br>The KiwiShare Team</p>
    </div>
  `;
}

// --- 1. Authentication Endpoints ---

router.post('/auth/register', async (ctx) => {
  const { email, password, displayName, platform: bodyPlatform } = ctx.request.body as any;

  if (!email || !password || !displayName) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing required registration parameters.' };
    return;
  }

  // Check if user already exists
  const existingUser = await User.findOne({ email });
  if (existingUser) {
    ctx.status = 409;
    ctx.body = { status: 'error', message: 'A user with this email address already exists.' };
    return;
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const platform = bodyPlatform || ctx.state.clientPlatform || resolveClientPlatform(ctx);
  const now = new Date();

  const role = email.toLowerCase() === 'admin@kiwishare.online' ? 'admin' : 'user';

  const newUser = await User.create({
    email,
    displayName,
    role,
    trustScore: 100,
    kiwiGold: 100,
    isVerified: false,
    authProvider: 'email_password',
    registrationPlatform: platform,
    lastUsedPlatform: platform,
    lastActiveAt: now,
    lastLoginAt: now,
    passwordHash
  });

  const token = jwt.sign({ id: newUser._id.toString(), email: newUser.email }, getJwtSecret(), { expiresIn: '2h' });

  ctx.status = 201;
  ctx.body = {
    status: 'success',
    token,
    user: {
      id: newUser._id.toString(),
      email: newUser.email,
      displayName: newUser.displayName,
      role: newUser.role,
      trustScore: newUser.trustScore,
      isVerified: newUser.isVerified,
      kiwiGold: newUser.kiwiGold ?? 100,
      registrationPlatform: newUser.registrationPlatform,
      lastUsedPlatform: newUser.lastUsedPlatform
    }
  };
});

router.post('/auth/login', async (ctx) => {
  const { email, password, platform: bodyPlatform } = ctx.request.body as any;

  if (!email || !password) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing login parameters.' };
    return;
  }

  // Find user and explicitly select passwordHash
  const user = await User.findOne({ email }).select('+passwordHash');
  if (!user || !user.passwordHash || !(await bcrypt.compare(password, user.passwordHash))) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Invalid credentials provided.' };
    return;
  }

  if (email.toLowerCase() === 'admin@kiwishare.online' && user.role !== 'admin') {
    user.role = 'admin';
  }

  const platform = bodyPlatform || ctx.state.clientPlatform || resolveClientPlatform(ctx);
  user.lastUsedPlatform = platform;
  user.lastLoginAt = new Date();
  user.lastActiveAt = new Date();
  await user.save();

  const token = jwt.sign({ id: user._id.toString(), email: user.email }, getJwtSecret(), { expiresIn: '2h' });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    token,
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      trustScore: user.trustScore,
      isVerified: user.isVerified,
      kiwiGold: user.kiwiGold ?? 100,
      registrationPlatform: user.registrationPlatform,
      lastUsedPlatform: user.lastUsedPlatform
    }
  };
});

// --- 1.1 Passwordless OTP & Google Authentication Endpoints ---

router.post('/auth/send-otp', async (ctx) => {
  const { email } = ctx.request.body as any;

  if (!email || !email.includes('@')) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Please provide a valid email address.' };
    return;
  }

  const normalizedEmail = email.trim().toLowerCase();
  const now = Date.now();
  const sixtySecondsAgo = new Date(now - 60 * 1000);
  const twentyFourHoursAgo = new Date(now - 24 * 60 * 60 * 1000);

  // 1. Check daily limit (max 10 requests per 24 hours per email)
  const dailyCount = await Otp.countDocuments({
    email: normalizedEmail,
    createdAt: { $gte: twentyFourHoursAgo }
  });

  if (dailyCount >= 10) {
    ctx.status = 429;
    ctx.body = {
      status: 'error',
      message: 'Daily verification code limit reached (max 10 requests per day). Please try again tomorrow.'
    };
    return;
  }

  // 2. Check 60-second cooldown
  const recentOtp = await Otp.findOne({
    email: normalizedEmail,
    createdAt: { $gte: sixtySecondsAgo }
  }).sort({ createdAt: -1 });

  if (recentOtp) {
    const elapsedSeconds = Math.floor((now - recentOtp.createdAt.getTime()) / 1000);
    const waitSeconds = Math.max(1, 60 - elapsedSeconds);
    ctx.status = 429;
    ctx.body = {
      status: 'error',
      message: 'Please wait for the cooldown timer before requesting a new verification code.',
      cooldownSeconds: waitSeconds
    };
    return;
  }

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(now + 10 * 60 * 1000); // 10 minutes validity

  // Save OTP in MongoDB
  await Otp.create({
    email: normalizedEmail,
    code,
    expiresAt,
    used: false
  });

  // Developer logging for local testing without SMTP server
  console.log(`\n📬 [OTP Sent] Email: ${normalizedEmail} | Code: ${code} (Expires in 10 minutes)\n`);

  // Attempt to send email via Resend API if configured
  const resendApiKey = process.env.RESEND_API_KEY;
  const resendFrom = process.env.RESEND_FROM || 'onboarding@resend.dev';

  let mailSent = false;

  if (resendApiKey) {
    try {
      const resend = new Resend(resendApiKey);
      await resend.emails.send({
        from: resendFrom,
        to: normalizedEmail,
        subject: 'KiwiShare Verification Code',
        text: `Kia ora!\n\nYour KiwiShare verification code is: ${code}\n\nThis code will expire in 10 minutes. Please do not share this code with anyone.\n\nNgā mihi,\nThe KiwiShare Team`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #f2e8db; border-radius: 12px; background-color: #faf7f2; color: #1f1f1f;">
            <h2 style="color: #2e5e4e; text-align: center; margin-bottom: 24px;">KiwiShare</h2>
            <p>Kia ora!</p>
            <p>Your KiwiShare verification code is:</p>
            <div style="font-size: 32px; font-weight: bold; color: #c96b4a; text-align: center; padding: 20px; letter-spacing: 4px; background-color: #f2e8db; border-radius: 8px; margin: 20px 0;">
              ${code}
            </div>
            <p>This code will expire in 10 minutes. Please do not share this code with anyone.</p>
            <hr style="border: none; border-top: 1px solid #2e5e4e; opacity: 0.1; margin: 30px 0;" />
            <p style="font-size: 12px; color: #1f1f1f; opacity: 0.6; text-align: center;">Ngā mihi,<br>The KiwiShare Team</p>
          </div>
        `
      });
      console.log(`✉️ [Resend Email Sent] Real OTP sent via Resend API to: ${normalizedEmail}`);
      mailSent = true;
    } catch (error: any) {
      console.error(`❌ [Resend Email Error] Failed to send email via Resend: ${error.message || error}`);
    }
  }

  // Attempt to send email via SMTP if configured and not already sent via Resend
  if (!mailSent) {
    const smtpHost = process.env.SMTP_HOST;
    const smtpPort = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT) : 465;
    const smtpSecure = process.env.SMTP_SECURE === 'true' || smtpPort === 465;
    const smtpUser = process.env.SMTP_USER;
    const smtpPass = process.env.SMTP_PASS;
    const smtpFrom = process.env.SMTP_FROM || `"KiwiShare" <${smtpUser}>`;

    if (smtpHost && smtpUser && smtpPass) {
      try {
        const transporter = nodemailer.createTransport({
          host: smtpHost,
          port: smtpPort,
          secure: smtpSecure,
          auth: {
            user: smtpUser,
            pass: smtpPass
          }
        });

        await transporter.sendMail({
          from: smtpFrom,
          to: normalizedEmail,
          subject: 'KiwiShare Verification Code',
          text: `Kia ora!\n\nYour KiwiShare verification code is: ${code}\n\nThis code will expire in 10 minutes. Please do not share this code with anyone.\n\nNgā mihi,\nThe KiwiShare Team`,
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #f2e8db; border-radius: 12px; background-color: #faf7f2; color: #1f1f1f;">
              <h2 style="color: #2e5e4e; text-align: center; margin-bottom: 24px;">KiwiShare</h2>
              <p>Kia ora!</p>
              <p>Your KiwiShare verification code is:</p>
              <div style="font-size: 32px; font-weight: bold; color: #c96b4a; text-align: center; padding: 20px; letter-spacing: 4px; background-color: #f2e8db; border-radius: 8px; margin: 20px 0;">
                ${code}
              </div>
              <p>This code will expire in 10 minutes. Please do not share this code with anyone.</p>
              <hr style="border: none; border-top: 1px solid #2e5e4e; opacity: 0.1; margin: 30px 0;" />
              <p style="font-size: 12px; color: #1f1f1f; opacity: 0.6; text-align: center;">Ngā mihi,<br>The KiwiShare Team</p>
            </div>
          `
        });
        console.log(`✉️ [SMTP Email Sent] Real OTP sent via SMTP to: ${normalizedEmail}`);
        mailSent = true;
      } catch (error: any) {
        console.error(`❌ [SMTP Email Error] Failed to send email via SMTP: ${error.message || error}`);
      }
    }
  }

  const responseBody: any = { status: 'success', message: 'Verification code sent successfully.' };
  if (process.env.NODE_ENV !== 'production') {
    responseBody.devCode = code; // Return code in non-prod environments for automated tests and easier mobile debugging
  }

  ctx.status = 200;
  ctx.body = responseBody;
});

router.post('/auth/verify-otp', async (ctx) => {
  const { email, code, displayName } = ctx.request.body as any;

  if (!email || !code) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Email and verification code are required.' };
    return;
  }

  const normalizedEmail = email.trim().toLowerCase();

  // Find the OTP document in MongoDB
  const otp = await Otp.findOne({
    email: normalizedEmail,
    code: code.toString().trim(),
    purpose: 'login',
    used: false
  }).sort({ expiresAt: -1 });

  if (!otp || otp.expiresAt < new Date()) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Invalid or expired verification code.' };
    return;
  }

  // Mark code as used
  otp.used = true;
  await otp.save();

  // Find or create user
  let user = await User.findOne({ email: normalizedEmail });
  const trimmedName = displayName?.toString().trim();
  if (!googleUid || !googleEmail || !googleEmail.includes('@')) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Google authentication did not return a verified email address.' };
    return;
  }

  const platform = ctx.state.clientPlatform || resolveClientPlatform(ctx);
  const now = new Date();

  if (!user) {
    user = await User.create({
      email: normalizedEmail,
      displayName: trimmedName || normalizedEmail.split('@')[0],
      avatarUrl: null,
      trustScore: 100,
      kiwiGold: 100,
      isVerified: false,
      authProvider: 'email_otp',
      registrationPlatform: platform,
      lastUsedPlatform: platform,
      lastActiveAt: now,
      lastLoginAt: now
    });
  } else {
    user.lastUsedPlatform = platform;
    user.lastLoginAt = now;
    user.lastActiveAt = now;
    if (trimmedName && trimmedName.length >= 2 && user.displayName !== trimmedName) {
      user.displayName = trimmedName;
    }
    await user.save();
  }

  const token = jwt.sign({ id: user._id.toString(), email: user.email }, getJwtSecret(), { expiresIn: '7d' });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    token,
    user: {
      id: user._id.toString(),
      email: user.email,
      displayName: user.displayName,
      email: user.email,
      username: user.username,
      needsUsername: !user.username || !user.username.trim(),
      avatarUrl: user.avatarUrl,
      trustScore: user.trustScore,
      isVerified: user.isVerified,
      kiwiGold: user.kiwiGold ?? 100,
      registrationPlatform: user.registrationPlatform,
      lastUsedPlatform: user.lastUsedPlatform
    }
  };
});

router.post('/auth/request-password-reset', async (ctx) => {
  const { email } = ctx.request.body as any;

  if (!email || !email.includes('@')) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Please provide a valid email address.' };
    return;
  }

  const normalizedEmail = email.trim().toLowerCase();
  const user = await User.findOne({ email: normalizedEmail }).select('+passwordHash');
  if (!user || user.authProvider !== 'email_password' || !user.passwordHash) {
    ctx.status = 400;
    ctx.body = {
      status: 'error',
      message: 'Password reset is only available for email and password accounts.'
    };
    return;
  }

  const now = Date.now();
  const sixtySecondsAgo = new Date(now - 60 * 1000);
  const twentyFourHoursAgo = new Date(now - 24 * 60 * 60 * 1000);

  const dailyCount = await Otp.countDocuments({
    email: normalizedEmail,
    purpose: 'password_reset',
    createdAt: { $gte: twentyFourHoursAgo }
  });
  if (dailyCount >= 10) {
    ctx.status = 429;
    ctx.body = {
      status: 'error',
      message: 'Daily password reset code limit reached. Please try again tomorrow.'
    };
    return;
  }

  const recentOtp = await Otp.findOne({
    email: normalizedEmail,
    purpose: 'password_reset',
    createdAt: { $gte: sixtySecondsAgo }
  }).sort({ createdAt: -1 });
  if (recentOtp) {
    const elapsedSeconds = Math.floor((now - recentOtp.createdAt.getTime()) / 1000);
    const waitSeconds = Math.max(1, 60 - elapsedSeconds);
    ctx.status = 429;
    ctx.body = {
      status: 'error',
      message: 'Please wait for the cooldown timer before requesting a new reset code.',
      cooldownSeconds: waitSeconds
    };
    return;
  }

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(now + 10 * 60 * 1000);

  await Otp.create({
    email: normalizedEmail,
    code,
    purpose: 'password_reset',
    expiresAt,
    used: false
  });

  console.log(`\n🔐 [Password Reset OTP Sent] Email: ${normalizedEmail} | Code: ${code} (Expires in 10 minutes)\n`);

  const mailSent = await sendVerificationEmail({
    to: normalizedEmail,
    subject: 'KiwiShare Password Reset Code',
    text: `Kia ora!\n\nYour KiwiShare password reset code is: ${code}\n\nThis code will expire in 10 minutes. Please do not share this code with anyone.\n\nNgā mihi,\nThe KiwiShare Team`,
    html: verificationEmailHtml(code, 'Your KiwiShare password reset code is:')
  });
  if (mailSent) {
    console.log(`✉️ [Password Reset Email Sent] Sent to: ${normalizedEmail}`);
  }

  const responseBody: any = { status: 'success', message: 'Password reset code sent successfully.' };
  if (process.env.NODE_ENV !== 'production') {
    responseBody.devCode = code;
  }

  ctx.status = 200;
  ctx.body = responseBody;
});

router.post('/auth/reset-password', async (ctx) => {
  const { email, code, newPassword } = ctx.request.body as any;

  if (!email || !code || typeof newPassword !== 'string') {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Email, verification code, and new password are required.' };
    return;
  }
  if (newPassword.length < 8 || newPassword.length > 128) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'New password must be between 8 and 128 characters.' };
    return;
  }

  const normalizedEmail = email.trim().toLowerCase();
  const otp = await Otp.findOne({
    email: normalizedEmail,
    code: code.toString().trim(),
    purpose: 'password_reset',
    used: false
  }).sort({ expiresAt: -1 });

  if (!otp || otp.expiresAt < new Date()) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Invalid or expired password reset code.' };
    return;
  }

  const user = await User.findOne({ email: normalizedEmail }).select('+passwordHash');
  if (!user || user.authProvider !== 'email_password' || !user.passwordHash) {
    ctx.status = 400;
    ctx.body = {
      status: 'error',
      message: 'Password reset is only available for email and password accounts.'
    };
    return;
  }
  if (await bcrypt.compare(newPassword, user.passwordHash)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'New password must be different from your current password.' };
    return;
  }

  otp.used = true;
  user.passwordHash = await bcrypt.hash(newPassword, 12);
  await Promise.all([otp.save(), user.save()]);

  ctx.status = 200;
  ctx.body = { status: 'success', message: 'Password reset successfully.' };
});

router.post('/auth/google', async (ctx) => {
  const { idToken } = ctx.request.body as any;

  if (!idToken) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'ID token is required.' };
    return;
  }

  let googleUid = '';
  let googleEmail = '';
  let googleName = '';
  let googlePicture = '';

  // Handle Mock verification for local testing and automated tests
  if (idToken.startsWith('mock_google_token')) {
    const suffix = idToken.split('_')[3] || 'sam';
    googleUid = `google_uid_${suffix}`;
    googleEmail = `${suffix}@kiwishare.co.nz`;
    googleName = suffix.charAt(0).toUpperCase() + suffix.slice(1);
    googlePicture = `https://images.unsplash.com/photo-1535713875002-d1d0cf377fde`;
  } else {
    // 1. Attempt verification via Firebase Admin if configured
    try {
      const app = await configuredFirebaseApp();
      if (app) {
        const { getAuth } = await import('firebase-admin/auth');
        const decoded = await getAuth(app).verifyIdToken(idToken);
        googleUid = decoded.uid;
        googleEmail = (decoded.email || '').trim().toLowerCase();
        googleName = decoded.name || '';
        googlePicture = decoded.picture || '';
      }
    } catch {
      // If Firebase verification fails, continue to Google OAuth tokeninfo
    }

    // 2. Fall back to standard Google OAuth Tokeninfo endpoint
    if (!googleUid) {
      try {
        const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
        if (!response.ok) {
          throw new Error('Google token validation endpoint returned an error.');
        }
        const data = await response.json() as any;
        if (data.error_description) {
          throw new Error(data.error_description);
        }
        googleUid = data.sub;
        googleEmail = (data.email || '').trim().toLowerCase();
        googleName = data.name || '';
        googlePicture = data.picture || '';
      } catch (e: any) {
        ctx.status = 401;
        ctx.body = { status: 'error', message: `Google authentication failed: ${e.message}` };
        return;
      }
    }
  }

  if (!googleUid || !googleEmail || !googleEmail.includes('@')) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Google authentication did not return a verified email address.' };
    return;
  }

  const platform = ctx.state.clientPlatform || resolveClientPlatform(ctx);
  const now = new Date();
  let user = await User.findOne({ $or: [{ googleId: googleUid }, { email: googleEmail }] });

  if (user) {
    if (!user.googleId) {
      user.googleId = googleUid;
    }
    user.avatarUrl = user.avatarUrl || googlePicture || null;
    user.displayName = user.displayName || googleName || googleEmail.split('@')[0];
    user.authProvider = user.authProvider || 'google';
    user.isVerified = true;
    if (user.kiwiGold === undefined || user.kiwiGold === null) {
      user.kiwiGold = 100;
    }
    user.lastUsedPlatform = platform;
    user.lastLoginAt = now;
    user.lastActiveAt = now;
    await user.save();
  } else {
    const role = googleEmail.toLowerCase() === 'admin@kiwishare.online' ? 'admin' : 'user';
    const isStudent = googleEmail.toLowerCase().endsWith('.ac.nz') || googleEmail.toLowerCase().endsWith('.edu');

    user = await User.create({
      googleId: googleUid,
      email: googleEmail,
      displayName: googleName || googleEmail.split('@')[0],
      avatarUrl: googlePicture || null,
      role,
      trustScore: 100,
      kiwiGold: 100,
      isVerified: true,
      isStudentVerified: isStudent,
      studentInstitution: 'University of Auckland',
      studentEmail: isStudent ? googleEmail : undefined,
      authProvider: 'google',
      registrationPlatform: platform,
      lastUsedPlatform: platform,
      lastActiveAt: now,
      lastLoginAt: now,
      notificationPreferences: {
        watchlistPriceDrop: true
      }
    });
  }

  const token = jwt.sign({ id: user._id.toString(), email: user.email }, getJwtSecret(), { expiresIn: '7d' });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    token,
    user: {
      id: user._id.toString(),
      email: user.email,
      username: user.username,
      needsUsername: !user.username || !user.username.trim(),
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      role: user.role,
      trustScore: user.trustScore,
      isVerified: user.isVerified,
      isStudentVerified: Boolean(user.isStudentVerified),
      studentInstitution: user.studentInstitution,
      kiwiGold: user.kiwiGold ?? 100,
      isVip: Boolean(user.isVip),
      registrationPlatform: user.registrationPlatform,
      lastUsedPlatform: user.lastUsedPlatform
    }
  };
});

export default router;
