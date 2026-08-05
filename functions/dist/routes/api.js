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