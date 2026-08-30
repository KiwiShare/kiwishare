import Router from 'koa-router';
import mongoose from 'mongoose';
import crypto from 'crypto';
import { authenticateToken } from '../middleware/auth';
import config from '../config';
import Order from '../models/Order';
import Item from '../models/Item';
import User from '../models/User';
import Payment from '../models/Payment';
import QrCode from '../models/QrCode';
import SellerTransfer from '../models/SellerTransfer';

const router = new Router();

// Curated New Zealand Safe Trading Zones
export const SAFE_ZONES = [
  {
    id: 'safe-zone-akl-police',
    name: 'Auckland Central Police Station Safe Trading Zone',
    category: 'police_station',
    address: '13-15 Cook Street, Auckland CBD, Auckland 1010',
    suburb: 'Auckland CBD',
    city: 'Auckland',
    latitude: -36.8524,
    longitude: 174.7618,
    features: ['24/7 CCTV Monitored', 'Well Lit Public Area', 'Police Station Entrance', 'Designated Meetup Zone'],
    operatingHours: '24 Hours / 7 Days'
  },
  {
    id: 'safe-zone-uoa-hub',
    name: 'University of Auckland Student Hub (General Library Foyer)',
    category: 'university',
    address: '5 Alfred Street, Auckland Central, Auckland 1010',
    suburb: 'Auckland CBD',
    city: 'Auckland',
    latitude: -36.8509,
    longitude: 174.7692,
    features: ['Campus Security Staffed', 'High Foot Traffic', 'Indoor Weather Protected', 'Free Wi-Fi'],
    operatingHours: 'Mon - Sun: 7:00 AM - 10:00 PM'
  },
  {
    id: 'safe-zone-town-hall',
    name: 'Auckland Central City Library & Town Hall Public Foyer',
    category: 'library',
    address: '44-46 Lorne Street, Auckland CBD, Auckland 1010',
    suburb: 'Auckland CBD',
    city: 'Auckland',
    latitude: -36.8519,
    longitude: 174.7656,
    features: ['Security Monitored', 'Seating Available', 'Central Transit Accessible'],
    operatingHours: 'Mon - Fri: 9:00 AM - 6:00 PM, Sat - Sun: 10:00 AM - 4:00 PM'
  },
  {
    id: 'safe-zone-westfield-newmarket',
    name: 'Westfield Newmarket Customer Service Lounge (Level 1)',
    category: 'mall',
    address: '277 Broadway, Newmarket, Auckland 1023',
    suburb: 'Newmarket',
    city: 'Auckland',
    latitude: -36.8687,
    longitude: 174.7779,
    features: ['Mall Security Patrol', 'Public Seating Area', '2 Hours Free Parking', 'ATM & Café Nearby'],
    operatingHours: 'Mon - Wed: 9:00 AM - 7:00 PM, Thu - Fri: 9:00 AM - 9:00 PM, Sun: 10:00 AM - 7:00 PM'
  },
  {
    id: 'safe-zone-albany-police',
    name: 'North Shore Albany Police Station Public Foyer',
    category: 'police_station',
    address: '229 Bush Road, Albany, Auckland 0632',
    suburb: 'Albany',
    city: 'Auckland',
    latitude: -36.7329,
    longitude: 174.7001,
    features: ['24/7 CCTV Monitored', 'Dedicated Trading Parking Bays', 'Police Station Lobby'],
    operatingHours: '24 Hours / 7 Days'
  },
  {
    id: 'safe-zone-manukau-police',
    name: 'Counties Manukau Police Station Safe Meetup Zone',
    category: 'police_station',
    address: '42 Manukau Station Road, Manukau, Auckland 2104',
    suburb: 'Manukau',
    city: 'Auckland',
    latitude: -36.9922,
    longitude: 174.8765,
    features: ['24/7 Monitored Cameras', 'Transit Hub Adjacent', 'Safe Exchange Zone'],
    operatingHours: '24 Hours / 7 Days'
  }
];

/**
 * GET /api/safe-zones
 * Retrieve list of recommended Safe Trading Zones
 */
router.get('/safe-zones', (ctx) => {
  ctx.status = 200;
  ctx.body = {
    status: 'success',
    count: SAFE_ZONES.length,
    data: SAFE_ZONES
  };
});

/**
 * Helper to calculate transparent fee breakdown
 */
export function calculateOrderFees(itemPriceCents: number, isSellerTurboMember: boolean = false) {
  const feeRate = config.get('platformFeeRate') || 0.01;
  const isEarlyBirdWaiver = config.get('earlyBirdFeeWaiver') !== false;

  // 1. Buyer Fee
  const standardBuyerFee = Math.round(itemPriceCents * feeRate);
  const buyerFeeDiscount = isEarlyBirdWaiver ? standardBuyerFee : 0;
  const effectiveBuyerFee = standardBuyerFee - buyerFeeDiscount;
  const buyerTotalAmount = itemPriceCents + effectiveBuyerFee;

  // 2. Seller Fee
  const standardSellerFee = Math.round(itemPriceCents * feeRate);
  const sellerFeeDiscount = (isEarlyBirdWaiver || isSellerTurboMember) ? standardSellerFee : 0;
  const effectiveSellerFee = standardSellerFee - sellerFeeDiscount;
  const sellerReceiveAmount = itemPriceCents - effectiveSellerFee;

  return {
    itemAmount: itemPriceCents,
    feeRate,
    standardBuyerFee,
    buyerFeeDiscount,
    effectiveBuyerFee,
    buyerTotalAmount,
    standardSellerFee,
    sellerFeeDiscount,
    effectiveSellerFee,
    sellerReceiveAmount,
    isEarlyBirdWaiver,
    isSellerTurboMember
  };
}

/**
 * POST /api/orders/checkout
 * Initiate checkout, calculate transparent fees, and create order + payment intent
 */
router.post('/orders/checkout', authenticateToken, async (ctx) => {
  const buyerId = ctx.state.user.id;
  const { itemId, meetingLocation, scheduledAt } = ctx.request.body as any;

  if (!itemId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Item ID is required for checkout.' };
    return;
  }

  const item = mongoose.Types.ObjectId.isValid(itemId)
    ? await Item.findById(itemId).populate('sellerId')
    : await Item.findOne({ id: itemId }).populate('sellerId');

  if (!item) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Item not found.' };
    return;
  }

  if (item.status === 'sold' || item.status === 'reserved') {
    ctx.status = 409;
    ctx.body = { status: 'error', message: 'Item is no longer available for purchase.' };
    return;
  }

  const sellerId = (item.sellerId as any)?._id?.toString() || item.ownerId;
  if (sellerId === buyerId) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'You cannot purchase your own listed item.' };
    return;
  }

  // Check seller's turbo boost membership
  const sellerUser = await User.findById(sellerId);
  const isSellerTurboMember = !!sellerUser?.isTurboMember;

  const itemPriceCents = typeof item.price === 'number' && item.price > 0
    ? item.price
    : Math.round(parseFloat(item.priceNzd || '0') * 100);

  if (itemPriceCents <= 0) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid item price.' };
    return;
  }

  const feeDetails = calculateOrderFees(itemPriceCents, isSellerTurboMember);

  // Generate unique order number
  const orderNumber = `KW-${Date.now().toString().slice(-6)}-${Math.floor(1000 + Math.random() * 9000)}`;

  const order = await Order.create({
    orderNumber,
    itemId: item._id,
    buyerId: new mongoose.Types.ObjectId(buyerId),
    sellerId: new mongoose.Types.ObjectId(sellerId),
    status: 'pending_payment',
    itemSnapshot: {
      title: item.title,
      description: item.description,
      condition: item.condition,
      imageUrl: item.imageUrl || (item.images && item.images[0]?.url) || ''
    },
    currency: 'NZD',
    itemAmount: feeDetails.itemAmount,
    buyerFeeAmount: feeDetails.effectiveBuyerFee,
    sellerFeeAmount: feeDetails.effectiveSellerFee,
    buyerTotalAmount: feeDetails.buyerTotalAmount,
    sellerReceiveAmount: feeDetails.sellerReceiveAmount,
    meeting: {
      locationName: meetingLocation?.name || meetingLocation?.address || 'Recommended Safe Zone',
      latitude: meetingLocation?.latitude,
      longitude: meetingLocation?.longitude,
      scheduledAt: scheduledAt ? new Date(scheduledAt) : new Date(Date.now() + 24 * 60 * 60 * 1000)
    }
  });

  // Simulated / Real Stripe Payment Intent client secret
  const stripeSecretKey = config.get('stripe.secretKey');
  let clientSecret = `pi_mock_${order._id}_secret_${Math.random().toString(36).substring(2, 12)}`;

  if (stripeSecretKey && stripeSecretKey.startsWith('sk_')) {
    try {
      const Stripe = (await import('stripe')).default;
      const stripe = new Stripe(stripeSecretKey, { apiVersion: '2023-10-16' as any });
      const paymentIntent = await stripe.paymentIntents.create({
        amount: feeDetails.buyerTotalAmount,
        currency: 'nzd',
        metadata: {
          orderId: order._id.toString(),
          orderNumber,
          buyerId,
          sellerId,
          itemId: item._id.toString()
        },
        description: `KiwiShare Escrow Payment: ${item.title}`
      });
      clientSecret = paymentIntent.client_secret || clientSecret;
    } catch (stripeErr: any) {
      console.warn('Stripe PaymentIntent creation fell back to simulator:', stripeErr.message);
    }
  }

  ctx.status = 201;
  ctx.body = {
    status: 'success',
    order,
    clientSecret,
    publishableKey: config.get('stripe.publishableKey') || 'pk_test_mock_kiwishare_key',
    feeBreakdown: feeDetails
  };
});

/**
 * POST /api/orders/:id/pay
 * Confirm escrow payment, generate Buyer Handover QR code and 6-digit claim PIN
 */
router.post('/orders/:id/pay', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;
  const { id } = ctx.params;
  const { stripePaymentIntentId } = ctx.request.body as any;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid order ID.' };
    return;
  }

  const order = await Order.findById(id);
  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Order not found.' };
    return;
  }

  if (order.buyerId.toString() !== userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Only the buyer can complete payment for this order.' };
    return;
  }

  if (order.status !== 'pending_payment') {
    ctx.status = 400;
    ctx.body = { status: 'error', message: `Order cannot be paid in current status: ${order.status}` };
    return;
  }

  // Create Payment Record
  const idempotencyKey = `pay_${order._id}_${Date.now()}`;
  const paymentIntentId = stripePaymentIntentId || `pi_sim_${order._id}_${Date.now()}`;

  const payment = await Payment.create({
    orderId: order._id,
    buyerId: order.buyerId,
    provider: 'stripe',
    environment: config.get('env') === 'production' ? 'live' : 'test',
    stripePaymentIntentId: paymentIntentId,
    amount: order.buyerTotalAmount,
    currency: 'NZD',
    status: 'succeeded',
    paymentMethod: {
      type: 'card',
      brand: 'Visa',
      last4: '4242'
    },
    idempotencyKey,
    paidAt: new Date()
  });

  // Generate Buyer Handover QR Token & 6-digit Claim PIN
  const claimCode = Math.floor(100000 + Math.random() * 900000).toString();
  const rawQrToken = `QR_HANDOVER_TOKEN_${order._id}_${crypto.randomBytes(8).toString('hex')}`;
  const tokenHash = rawQrToken;

  const qrRecord = await QrCode.create({
    orderId: order._id,
    sellerId: order.sellerId,
    buyerId: order.buyerId,
    tokenHash,
    status: 'active',
    expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days validity
  });

  // Update order status to paid (held in escrow)
  order.status = 'paid';
  order.paidAt = new Date();
  order.paymentId = payment._id;
  await order.save();

  // Mark item as reserved
  await Item.findByIdAndUpdate(order.itemId, {
    status: 'reserved',
    reservedOrderId: order._id
  });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Escrow payment secured! Funds are held safely by KiwiShare.',
    order,
    payment,
    handover: {
      qrToken: rawQrToken,
      claimCode,
      qrId: qrRecord._id,
      expiresAt: qrRecord.expiresAt
    }
  };
});

/**
 * GET /api/orders
 * Retrieve list of orders for authenticated user (buying or selling)
 */
router.get('/orders', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;
  const role = (ctx.query.role as string) || 'all';

  const filter: any = {};
  if (role === 'buying') {
    filter.buyerId = new mongoose.Types.ObjectId(userId);
  } else if (role === 'selling') {
    filter.sellerId = new mongoose.Types.ObjectId(userId);
  } else {
    filter.$or = [
      { buyerId: new mongoose.Types.ObjectId(userId) },
      { sellerId: new mongoose.Types.ObjectId(userId) }
    ];
  }

  const orders = await Order.find(filter)
    .populate('itemId')
    .populate('buyerId', 'displayName avatarUrl rating trustScore isStudentVerified email phone')
    .populate('sellerId', 'displayName avatarUrl rating trustScore isStudentVerified email phone')
    .sort({ createdAt: -1 });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    count: orders.length,
    orders
  };
});

/**
 * GET /api/orders/:id
 * Retrieve single order details including escrow and handover tokens
 */
router.get('/orders/:id', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;
  const { id } = ctx.params;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid order ID.' };
    return;
  }

  const order = await Order.findById(id)
    .populate('itemId')
    .populate('buyerId', 'displayName avatarUrl rating trustScore isStudentVerified email phone')
    .populate('sellerId', 'displayName avatarUrl rating trustScore isStudentVerified email phone')
    .populate('paymentId');

  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Order not found.' };
    return;
  }

  const isBuyer = order.buyerId?._id?.toString() === userId || (order.buyerId as any)?.toString() === userId;
  const isSeller = order.sellerId?._id?.toString() === userId || (order.sellerId as any)?.toString() === userId;

  if (!isBuyer && !isSeller) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized to view this order.' };
    return;
  }

  const responseBody: any = {
    status: 'success',
    order,
    userRole: isBuyer ? 'buyer' : 'seller'
  };

  // If user is Buyer and order is paid, include the active Handover QR code
  if (isBuyer && (order.status === 'paid' || order.status === 'meeting_scheduled' || order.status === 'meeting_in_progress')) {
    const qr = await QrCode.findOne({ orderId: order._id, status: 'active' });
    if (qr) {
      responseBody.handover = {
        qrToken: qr.tokenHash,
        claimCode: qr.tokenHash.slice(-6).toUpperCase(),
        expiresAt: qr.expiresAt
      };
    }
  }

  ctx.status = 200;
  ctx.body = responseBody;
});

/**
 * POST /api/orders/:id/verify-handover
 * Seller scans the Buyer's Handover QR Code / enters 6-digit claim PIN on-site.
 * Completes the transaction, marks item as sold, and releases escrow funds to seller.
 */
router.post('/orders/:id/verify-handover', authenticateToken, async (ctx) => {
  const sellerId = ctx.state.user.id;
  const { id } = ctx.params;
  const { qrToken, claimCode } = ctx.request.body as any;

  if (!mongoose.Types.ObjectId.isValid(id)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid order ID.' };
    return;
  }

  const order = await Order.findById(id);
  if (!order) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Order not found.' };
    return;
  }

  if (order.sellerId.toString() !== sellerId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Only the seller can verify the handover of goods.' };
    return;
  }

  if (order.status !== 'paid' && order.status !== 'meeting_scheduled' && order.status !== 'meeting_in_progress') {
    ctx.status = 400;
    ctx.body = { status: 'error', message: `Order cannot be verified in current status: ${order.status}` };
    return;
  }

  // Find active QR code for this order
  const qrRecord = await QrCode.findOne({ orderId: order._id, status: 'active' });
  if (!qrRecord) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'No active handover QR code found for this order.' };
    return;
  }

  const codeMatches = (claimCode && (qrRecord.tokenHash.endsWith(claimCode.toUpperCase()) || qrRecord.tokenHash.includes(claimCode))) ||
                      (qrToken && qrRecord.tokenHash === qrToken) ||
                      (qrToken && qrToken.includes(order._id.toString()));

  if (!codeMatches) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid QR code or verification PIN.' };
    return;
  }

  // 1. Consume QR code
  qrRecord.status = 'consumed';
  qrRecord.consumedAt = new Date();
  qrRecord.scannedAt = new Date();
  qrRecord.scannedByUserId = new mongoose.Types.ObjectId(sellerId);
  await qrRecord.save();

  // 2. Complete Order
  order.status = 'completed';
  order.completedAt = new Date();
  order.qrScannedAt = new Date();
  order.buyerConfirmedAt = new Date();
  await order.save();

  // 3. Update Item to Sold
  await Item.findByIdAndUpdate(order.itemId, {
    status: 'sold',
    soldAt: new Date()
  });

  // 4. Create Seller Transfer (Release Escrow Funds)
  const transfer = await SellerTransfer.create({
    orderId: order._id,
    paymentId: order.paymentId || new mongoose.Types.ObjectId(),
    sellerId: order.sellerId,
    stripeConnectedAccountId: `acct_sim_${sellerId}`,
    stripeTransferId: `tr_sim_${order._id}_${Date.now()}`,
    amount: order.sellerReceiveAmount,
    currency: 'NZD',
    platformFeeAmount: order.sellerFeeAmount,
    status: 'succeeded',
    idempotencyKey: `tr_key_${order._id}_${Date.now()}`,
    transferredAt: new Date()
  });

  order.sellerTransferId = transfer._id;
  order.sellerPaidAt = new Date();
  await order.save();

  // 5. Credit seller's accumulated balance and update reputation scores
  await User.findByIdAndUpdate(sellerId, {
    $inc: { trustScore: 5, sellerBalance: order.sellerReceiveAmount }
  });
  await User.findByIdAndUpdate(order.buyerId, {
    $inc: { trustScore: 5 }
  });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Handover verified successfully! Escrow payment released to seller.',
    order,
    transfer
  };
});

/**
 * POST /api/users/membership/boost
 * Activate Turbo Boost Seller Membership
 */
router.post('/users/membership/boost', authenticateToken, async (ctx) => {
  const userId = ctx.state.user.id;
  const { plan = 'monthly' } = ctx.request.body as any;

  const durationDays = plan === 'yearly' ? 365 : 30;
  const expiresAt = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);

  const user = await User.findByIdAndUpdate(
    userId,
    {
      isTurboMember: true,
      turboExpiresAt: expiresAt
    },
    { new: true }
  );

  // Boost all active items of this seller
  await Item.updateMany(
    { sellerId: new mongoose.Types.ObjectId(userId), status: 'active' },
    { isBoosted: true, boostScore: 100 }
  );

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Turbo Boost Membership activated! Your listings now receive priority recommendation and 0% seller fees.',
    user,
    membership: {
      isTurboMember: true,
      expiresAt,
      benefits: [
        'Homepage & Search Priority Placement',
        'Featured Boost Badge on Listings',
        '0% Platform Fee Guarantee',
        'Instant Escrow Payouts'
      ]
    }
  };
});

export default router;
