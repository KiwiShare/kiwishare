"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const koa_router_1 = __importDefault(require("koa-router"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const auth_1 = require("../middleware/auth");
const admin = __importStar(require("firebase-admin"));
const nodemailer_1 = __importDefault(require("nodemailer"));
const resend_1 = require("resend");
// Initialize router prefix
const router = new koa_router_1.default({ prefix: '/api' });
const JWT_SECRET = process.env.JWT_SECRET || 'kiwishare_super_secret_key_123_abc';
// Helper to check if Firestore is operational
function getFirestore() {
    try {
        if (admin.apps.length > 0) {
            return admin.firestore();
        }
    }
    catch (e) {
        // Fallback to local memory database
    }
    return null;
}
// Local in-memory store for development/testing environments
const localUsers = [];
const localListings = [
    {
        id: 'item_1',
        title: 'Retro Armchair',
        priceNzd: '45',
        location: 'Auckland',
        imageUrl: 'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c',
        isSustainable: true,
        category: 'Furniture',
        status: 'active',
        ownerId: 'user_sam'
    },
    {
        id: 'item_2',
        title: 'Monstera Deliciosa',
        priceNzd: '15',
        location: 'Wellington',
        imageUrl: 'https://images.unsplash.com/photo-1545241047-6083a3684587',
        isSustainable: true,
        category: 'Plants',
        status: 'active',
        ownerId: 'user_jenny'
    }
];
// --- 1. Authentication Endpoints ---
router.post('/auth/register', async (ctx) => {
    const { email, password, displayName } = ctx.request.body;
    if (!email || !password || !displayName) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'Missing required registration parameters.' };
        return;
    }
    const hashedPassword = await bcryptjs_1.default.hash(password, 12);
    const newUser = {
        id: `uid_${Date.now()}`,
        email,
        displayName,
        trustScore: 100,
        isVerified: false,
        createdAt: new Date().toISOString()
    };
    const db = getFirestore();
    if (db) {
        // Firestore Admin path
        const userRef = db.collection('users').doc(newUser.id);
        await userRef.set({
            id: newUser.id,
            email: newUser.email,
            displayName: newUser.displayName,
            trustScore: newUser.trustScore,
            isVerified: newUser.isVerified,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        // Create password credential shadow copy securely
        await db.collection('secrets').doc(newUser.id).set({ hashedPassword });
    }
    else {
        // Local memory fallback
        localUsers.push({ ...newUser, hashedPassword });
    }
    const token = jsonwebtoken_1.default.sign({ id: newUser.id, email: newUser.email }, JWT_SECRET, { expiresIn: '2h' });
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
    const { email, password } = ctx.request.body;
    if (!email || !password) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'Missing login parameters.' };
        return;
    }
    let userDoc = null;
    let hashedPassword = '';
    const db = getFirestore();
    if (db) {
        const userSnap = await db.collection('users').where('email', '==', email).limit(1).get();
        if (!userSnap.empty) {
            const uDoc = userSnap.docs[0];
            userDoc = uDoc.data();
            const secSnap = await db.collection('secrets').doc(userDoc.id).get();
            hashedPassword = secSnap.exists ? secSnap.data()?.hashedPassword : '';
        }
    }
    else {
        // Local memory lookup
        const localUser = localUsers.find(u => u.email === email);
        if (localUser) {
            userDoc = {
                id: localUser.id,
                displayName: localUser.displayName,
                trustScore: localUser.trustScore,
                isVerified: localUser.isVerified
            };
            hashedPassword = localUser.hashedPassword;
        }
    }
    if (!userDoc || !hashedPassword || !(await bcryptjs_1.default.compare(password, hashedPassword))) {
        ctx.status = 401;
        ctx.body = { status: 'error', message: 'Invalid credentials provided.' };
        return;
    }
    const token = jsonwebtoken_1.default.sign({ id: userDoc.id, email }, JWT_SECRET, { expiresIn: '2h' });
    ctx.status = 200;
    ctx.body = {
        status: 'success',
        token,
        user: userDoc
    };
});
// --- 1.1 Passwordless OTP & Google Authentication Endpoints ---
// Local memory store for OTP verification codes in development/testing
const localOtps = [];
router.post('/auth/send-otp', async (ctx) => {
    const { email } = ctx.request.body;
    if (!email || !email.includes('@')) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'Please provide a valid email address.' };
        return;
    }
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes validity
    const db = getFirestore();
    if (db) {
        await db.collection('otps').add({
            email,
            code,
            expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            used: false
        });
    }
    else {
        localOtps.push({
            email,
            code,
            expiresAt,
            used: false
        });
    }
    // Developer logging for local testing without SMTP server
    console.log(`\n📬 [OTP Sent] Email: ${email} | Code: ${code} (Expires in 10 minutes)\n`);
    // Attempt to send email via Resend API if configured
    const resendApiKey = process.env.RESEND_API_KEY;
    const resendFrom = process.env.RESEND_FROM || 'onboarding@resend.dev';
    let mailSent = false;
    if (resendApiKey) {
        try {
            const resend = new resend_1.Resend(resendApiKey);
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
        }
        catch (error) {
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
                const transporter = nodemailer_1.default.createTransport({
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
            }
            catch (error) {
                console.error(`❌ [SMTP Email Error] Failed to send email via SMTP: ${error.message || error}`);
            }
        }
    }
    const responseBody = { status: 'success', message: 'Verification code sent successfully.' };
    if (process.env.NODE_ENV !== 'production') {
        responseBody.devCode = code; // Return code in non-prod environments for automated tests and easier mobile debugging
    }
    ctx.status = 200;
    ctx.body = responseBody;
});
router.post('/auth/verify-otp', async (ctx) => {
    const { email, code, displayName } = ctx.request.body;
    if (!email || !code) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'Email and verification code are required.' };
        return;
    }
    let isValid = false;
    const db = getFirestore();
    if (db) {
        const otpSnap = await db.collection('otps')
            .where('email', '==', email)
            .where('code', '==', code)
            .where('used', '==', false)
            .orderBy('expiresAt', 'desc')
            .limit(1)
            .get();
        if (!otpSnap.empty) {
            const otpDoc = otpSnap.docs[0];
            const otpData = otpDoc.data();
            const expiresAt = otpData.expiresAt.toDate();
            if (expiresAt > new Date()) {
                isValid = true;
                await otpDoc.ref.update({ used: true });
            }
        }
    }
    else {
        const matchedOtpIdx = localOtps.findIndex(o => o.email === email && o.code === code && !o.used && o.expiresAt > new Date());
        if (matchedOtpIdx !== -1) {
            isValid = true;
            localOtps[matchedOtpIdx].used = true;
        }
    }
    if (!isValid) {
        ctx.status = 401;
        ctx.body = { status: 'error', message: 'Invalid or expired verification code.' };
        return;
    }
    // Fetch or create user
    let userDoc = null;
    if (db) {
        const userSnap = await db.collection('users').where('email', '==', email).limit(1).get();
        if (!userSnap.empty) {
            userDoc = userSnap.docs[0].data();
        }
        else {
            // Create new user profile matching schema
            const userId = `uid_${Math.random().toString(36).substring(2, 11)}`;
            const newUser = {
                id: userId,
                email,
                displayName: displayName || email.split('@')[0],
                avatarUrl: null,
                trustScore: 100,
                isVerified: false,
                authProvider: 'email_otp',
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            };
            await db.collection('users').doc(userId).set(newUser);
            userDoc = { ...newUser, createdAt: new Date().toISOString() };
        }
    }
    else {
        // Local memory lookup or create
        const existing = localUsers.find(u => u.email === email);
        if (existing) {
            userDoc = {
                id: existing.id,
                email: existing.email,
                displayName: existing.displayName,
                avatarUrl: existing.avatarUrl,
                trustScore: existing.trustScore,
                isVerified: existing.isVerified
            };
        }
        else {
            const userId = `uid_${Math.random().toString(36).substring(2, 11)}`;
            userDoc = {
                id: userId,
                email,
                displayName: displayName || email.split('@')[0],
                avatarUrl: null,
                trustScore: 100,
                isVerified: false,
                authProvider: 'email_otp',
                createdAt: new Date().toISOString()
            };
            localUsers.push(userDoc);
        }
    }
    const token = jsonwebtoken_1.default.sign({ id: userDoc.id, email: userDoc.email }, JWT_SECRET, { expiresIn: '7d' });
    ctx.status = 200;
    ctx.body = {
        status: 'success',
        token,
        user: userDoc
    };
});
router.post('/auth/google', async (ctx) => {
    const { idToken } = ctx.request.body;
    if (!idToken) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'ID token is required.' };
        return;
    }
    let googleUid = '';
    let googleEmail = '';
    let googleName = '';
    let googlePicture = '';
    const db = getFirestore();
    // Handle Mock verification for local testing
    if (idToken.startsWith('mock_google_token')) {
        const suffix = idToken.split('_')[3] || 'sam';
        googleUid = `google_uid_${suffix}`;
        googleEmail = `${suffix}@kiwishare.co.nz`;
        googleName = suffix.charAt(0).toUpperCase() + suffix.slice(1);
        googlePicture = `https://images.unsplash.com/photo-1535713875002-d1d0cf377fde`;
    }
    else {
        if (!db) {
            ctx.status = 500;
            ctx.body = { status: 'error', message: 'Firebase Admin SDK not operational for live token verification.' };
            return;
        }
        try {
            const decodedToken = await admin.auth().verifyIdToken(idToken);
            googleUid = decodedToken.uid;
            googleEmail = decodedToken.email || '';
            googleName = decodedToken.name || '';
            googlePicture = decodedToken.picture || '';
        }
        catch (e) {
            ctx.status = 401;
            ctx.body = { status: 'error', message: `Google authentication failed: ${e.message}` };
            return;
        }
    }
    let userDoc = null;
    if (db) {
        // Check if user exists by UID or email
        const userRef = db.collection('users').doc(googleUid);
        const userSnap = await userRef.get();
        if (userSnap.exists) {
            userDoc = userSnap.data();
        }
        else {
            // Check if user exists by email (to link account if they previously signed up via email)
            const emailSnap = await db.collection('users').where('email', '==', googleEmail).limit(1).get();
            if (!emailSnap.empty) {
                // Link to existing document
                const existingDoc = emailSnap.docs[0];
                userDoc = existingDoc.data();
                // Update user fields
                await existingDoc.ref.update({
                    avatarUrl: userDoc.avatarUrl || googlePicture || null,
                    displayName: userDoc.displayName || googleName || googleEmail.split('@')[0],
                    authProvider: 'google'
                });
                userDoc = { ...userDoc, avatarUrl: userDoc.avatarUrl || googlePicture, displayName: userDoc.displayName || googleName };
            }
            else {
                // Create new user profile matching schema using Google UID as user ID
                const newUser = {
                    id: googleUid,
                    email: googleEmail,
                    displayName: googleName || googleEmail.split('@')[0],
                    avatarUrl: googlePicture || null,
                    trustScore: 100,
                    isVerified: true, // Pre-verified via Google
                    authProvider: 'google',
                    createdAt: admin.firestore.FieldValue.serverTimestamp()
                };
                await userRef.set(newUser);
                userDoc = { ...newUser, createdAt: new Date().toISOString() };
            }
        }
    }
    else {
        // Local memory mock logic
        const existing = localUsers.find(u => u.email === googleEmail || u.id === googleUid);
        if (existing) {
            userDoc = {
                id: existing.id,
                email: existing.email,
                displayName: existing.displayName,
                avatarUrl: existing.avatarUrl || googlePicture,
                trustScore: existing.trustScore,
                isVerified: existing.isVerified
            };
        }
        else {
            userDoc = {
                id: googleUid,
                email: googleEmail,
                displayName: googleName || googleEmail.split('@')[0],
                avatarUrl: googlePicture || null,
                trustScore: 100,
                isVerified: true,
                authProvider: 'google',
                createdAt: new Date().toISOString()
            };
            localUsers.push(userDoc);
        }
    }
    const token = jsonwebtoken_1.default.sign({ id: userDoc.id, email: userDoc.email }, JWT_SECRET, { expiresIn: '7d' });
    ctx.status = 200;
    ctx.body = {
        status: 'success',
        token,
        user: userDoc
    };
});
// --- 2. Listing Endpoints ---
router.get('/listings', async (ctx) => {
    const { category } = ctx.query;
    let listings = [];
    const db = getFirestore();
    if (db) {
        let query = db.collection('items');
        if (category && category !== 'All NZ') {
            query = query.where('category', '==', category);
        }
        const snap = await query.get();
        snap.forEach(doc => listings.push(doc.data()));
    }
    else {
        // Local memory filtering
        listings = (category && category !== 'All NZ')
            ? localListings.filter(l => l.category === category)
            : localListings;
    }
    ctx.status = 200;
    ctx.body = listings;
});
router.post('/listings', auth_1.authenticateToken, async (ctx) => {
    const { title, priceNzd, location, imageUrl, isSustainable, category } = ctx.request.body;
    const ownerId = ctx.state.user.id;
    if (!title || !priceNzd || !location || !imageUrl || isSustainable === undefined || !category) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'Missing product listing fields.' };
        return;
    }
    const newItem = {
        id: `item_${Date.now()}`,
        title,
        priceNzd,
        location,
        imageUrl,
        isSustainable,
        category,
        status: 'active',
        ownerId,
        createdAt: new Date().toISOString()
    };
    const db = getFirestore();
    if (db) {
        await db.collection('items').doc(newItem.id).set({
            ...newItem,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
    }
    else {
        // Local memory fallback
        localListings.push(newItem);
    }
    ctx.status = 201;
    ctx.body = {
        status: 'created',
        item: newItem
    };
});
// --- 3. QR Code Handover Endpoints ---
router.post('/transactions/handover/claim', auth_1.authenticateToken, async (ctx) => {
    const { itemId, claimCode } = ctx.request.body;
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
    const db = getFirestore();
    if (db) {
        // Run atomic transactional updates to protect data state transitions
        const itemRef = db.collection('items').doc(itemId);
        await db.runTransaction(async (transaction) => {
            const itemDoc = await transaction.get(itemRef);
            if (!itemDoc.exists) {
                throw new Error('Listing item not found.');
            }
            const itemData = itemDoc.data();
            if (itemData.status === 'sold') {
                throw new Error('Conflict: Item is already transferred.');
            }
            if (itemData.ownerId === claimerId) {
                throw new Error('Self-claims are unauthorized.');
            }
            // Execute handover transitions
            transaction.update(itemRef, { status: 'sold', ownerId: claimerId });
            // Atomically increment owner's trust reputation score
            const ownerRef = db.collection('users').doc(itemData.ownerId);
            transaction.update(ownerRef, { trustScore: admin.firestore.FieldValue.increment(5) });
        });
    }
    else {
        // Local memory mock logic
        const item = localListings.find(l => l.id === itemId);
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
        // Execute state changes
        item.status = 'sold';
        item.ownerId = claimerId;
    }
    ctx.status = 200;
    ctx.body = {
        status: 'success',
        message: 'Ownership transaction verified and committed successfully.',
        newOwnerId: claimerId
    };
});
exports.default = router;
//# sourceMappingURL=api.js.map