import Router from 'koa-router';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { authenticateToken } from '../middleware/auth';
import nodemailer from 'nodemailer';
import { Resend } from 'resend';

// Mongoose Models
import User from '../models/User';
import Otp from '../models/Otp';
import Item from '../models/Item';

// Initialize router prefix
const router = new Router({ prefix: '/api' });
const JWT_SECRET = process.env.JWT_SECRET || 'kiwishare_super_secret_key_123_abc';

// --- 1. Authentication Endpoints ---

router.post('/auth/register', async (ctx) => {
  const { email, password, displayName } = ctx.request.body as any;

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

  const hashedPassword = await bcrypt.hash(password, 12);
  const userId = `uid_${Date.now()}`;

  const newUser = await User.create({
    id: userId,
    email,
    displayName,
    trustScore: 100,
    isVerified: false,
    authProvider: 'email_password',
    hashedPassword
  });

  const token = jwt.sign({ id: newUser.id, email: newUser.email }, JWT_SECRET, { expiresIn: '2h' });

  ctx.status = 201;
  ctx.body = {
    status: 'success',
    token,
    user: {
      id: newUser.id,
      displayName: newUser.displayName,
      trustScore: newUser.trustScore,
      isVerified: newUser.isVerified
    }
  };
});

router.post('/auth/login', async (ctx) => {
  const { email, password } = ctx.request.body as any;

  if (!email || !password) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing login parameters.' };
    return;
  }

  // Find user and explicitly select hashedPassword
  const user = await User.findOne({ email }).select('+hashedPassword');
  if (!user || !user.hashedPassword || !(await bcrypt.compare(password, user.hashedPassword))) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Invalid credentials provided.' };
    return;
  }

  const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '2h' });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    token,
    user: {
      id: user.id,
      displayName: user.displayName,
      trustScore: user.trustScore,
      isVerified: user.isVerified
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

  const code = Math.floor(100000 + Math.random() * 900000).toString();
  const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes validity

  // Save OTP in MongoDB
  await Otp.create({
    email,
    code,
    expiresAt,
    used: false
  });

  // Developer logging for local testing without SMTP server
  console.log(`\n📬 [OTP Sent] Email: ${email} | Code: ${code} (Expires in 10 minutes)\n`);

  // Attempt to send email via Resend API if configured
  const resendApiKey = process.env.RESEND_API_KEY;
  const resendFrom = process.env.RESEND_FROM || 'onboarding@resend.dev';

  let mailSent = false;

  if (resendApiKey) {
    try {
      const resend = new Resend(resendApiKey);
      await resend.emails.send({
        from: resendFrom,
        to: email,
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
      console.log(`✉️ [Resend Email Sent] Real OTP sent via Resend API to: ${email}`);
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
          to: email,
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
        console.log(`✉️ [SMTP Email Sent] Real OTP sent via SMTP to: ${email}`);
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

  // Find the OTP document in MongoDB
  const otp = await Otp.findOne({
    email,
    code,
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
  let user = await User.findOne({ email });
  if (!user) {
    const userId = `uid_${Math.random().toString(36).substring(2, 11)}`;
    user = await User.create({
      id: userId,
      email,
      displayName: displayName || email.split('@')[0],
      avatarUrl: null,
      trustScore: 100,
      isVerified: false,
      authProvider: 'email_otp'
    });
  }

  const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    token,
    user: {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      trustScore: user.trustScore,
      isVerified: user.isVerified
    }
  };
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

  // Handle Mock verification for local testing
  if (idToken.startsWith('mock_google_token')) {
    const suffix = idToken.split('_')[3] || 'sam';
    googleUid = `google_uid_${suffix}`;
    googleEmail = `${suffix}@kiwishare.co.nz`;
    googleName = suffix.charAt(0).toUpperCase() + suffix.slice(1);
    googlePicture = `https://images.unsplash.com/photo-1535713875002-d1d0cf377fde`;
  } else {
    // Perform standard HTTP request to Google Tokeninfo endpoint to verify token
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
      googleEmail = data.email || '';
      googleName = data.name || '';
      googlePicture = data.picture || '';
    } catch (e: any) {
      ctx.status = 401;
      ctx.body = { status: 'error', message: `Google authentication failed: ${e.message}` };
      return;
    }
  }

  let user = await User.findOne({ $or: [{ id: googleUid }, { email: googleEmail }] });

  if (user) {
    // Update user details if Google provides new info
    user.avatarUrl = user.avatarUrl || googlePicture || null;
    user.displayName = user.displayName || googleName || googleEmail.split('@')[0];
    user.authProvider = 'google';
    await user.save();
  } else {
    // Create new user profile matching schema using Google UID as user ID
    user = await User.create({
      id: googleUid,
      email: googleEmail,
      displayName: googleName || googleEmail.split('@')[0],
      avatarUrl: googlePicture || null,
      trustScore: 100,
      isVerified: true, // Pre-verified via Google
      authProvider: 'google'
    });
  }

  const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    token,
    user: {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      trustScore: user.trustScore,
      isVerified: user.isVerified
    }
  };
});

// --- 2. Listing Endpoints ---

router.get('/listings', async (ctx) => {
  const { category, query } = ctx.query;
  const filter: any = {};

  if (category && category !== 'All NZ' && category !== 'All') {
    filter.category = category;
  }

  if (query && typeof query === 'string' && query.trim() !== '') {
    const searchRegex = new RegExp(query.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    filter.$or = [
      { title: searchRegex },
      { category: searchRegex },
      { location: searchRegex }
    ];
  }

  const listings = await Item.find(filter).sort({ createdAt: -1 });
  ctx.status = 200;
  ctx.body = listings;
});

router.post('/listings', authenticateToken, async (ctx) => {
  const { title, priceNzd, location, imageUrl, isSustainable, category } = ctx.request.body as any;
  const ownerId = ctx.state.user.id;

  if (!title || !priceNzd || !location || !imageUrl || isSustainable === undefined || !category) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing product listing fields.' };
    return;
  }

  const newItem = await Item.create({
    id: `item_${Date.now()}`,
    title,
    priceNzd,
    location,
    imageUrl,
    isSustainable,
    category,
    status: 'active',
    ownerId
  });

  ctx.status = 201;
  ctx.body = {
    status: 'created',
    item: newItem
  };
});

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

  const item = await Item.findOne({ id: itemId });
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

  if (item.ownerId === claimerId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Self-claims are unauthorized.' };
    return;
  }

  // Update item status and owner ID
  const originalOwnerId = item.ownerId;
  item.status = 'sold';
  item.ownerId = claimerId;
  await item.save();

  // Atomically increment owner's trust reputation score in User database
  await User.updateOne({ id: originalOwnerId }, { $inc: { trustScore: 5 } });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Ownership transaction verified and committed successfully.',
    newOwnerId: claimerId
  };
});

export default router;
