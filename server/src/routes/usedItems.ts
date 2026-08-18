import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';

const router = new Router();

// Helper to format Item document for client response
export function formatItem(itemDoc: any) {
  const itemObj = itemDoc.toObject ? itemDoc.toObject({ virtuals: true }) : itemDoc;
  const suburb = itemObj.location?.suburb || '';
  const city = itemObj.location?.city || '';
  const locationStr = typeof itemObj.location === 'string'
    ? itemObj.location
    : [suburb, city].filter(Boolean).join(', ') || 'Auckland';

  const priceNzd = itemObj.priceNzd || (itemObj.price != null ? (itemObj.price / 100).toString() : '0');
  const imageUrl = itemObj.images?.[0]?.url || itemObj.imageUrl || '';
  const ownerId = itemObj.sellerId ? itemObj.sellerId.toString() : (itemObj.ownerId || '');

  return {
    ...itemObj,
    id: itemObj.id || itemObj._id?.toString(),
    imageUrl,
    location: locationStr,
    priceNzd,
    ownerId,
    sellerId: ownerId
  };
}

// Helper to parse location string into structured location object
function parseLocation(location: string | any) {
  if (typeof location !== 'string') {
    return location || { city: 'Auckland', suburb: '' };
  }
  const parts = location.split(',').map((s: string) => s.trim());
  const city = parts[parts.length - 1] || 'Auckland';
  const suburb = parts.length > 1 ? parts[0] : '';
  return {
    city,
    suburb,
    coordinates: {
      type: 'Point' as const,
      coordinates: [174.7633, -36.8485]
    }
  };
}

// --- RESTful Used Items Endpoints ---

// 1. GET /usedItems (and GET /listings) - List & filter used items
async function getUsedItemsHandler(ctx: any) {
  const { category, query, status, ownerId, sellerId } = ctx.query;
  const filter: any = {};

  if (category && category !== 'All NZ' && category !== 'All') {
    filter.category = category;
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

  const filterOwner = sellerId || ownerId;
  if (filterOwner) {
    if (mongoose.Types.ObjectId.isValid(filterOwner)) {
      filter.$or = [
        { sellerId: new mongoose.Types.ObjectId(filterOwner) },
        { ownerId: filterOwner }
      ];
    } else {
      filter.ownerId = filterOwner;
    }
  }

  if (query && typeof query === 'string' && query.trim() !== '') {
    const searchRegex = new RegExp(query.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    filter.$or = [
      { title: searchRegex },
      { category: searchRegex },
      { description: searchRegex },
      { 'location.city': searchRegex },
      { 'location.suburb': searchRegex }
    ];
  }

  const items = await Item.find(filter).sort({ createdAt: -1 });
  ctx.status = 200;
  ctx.body = items.map(formatItem);
}

// 2. GET /usedItems/:id (and GET /listings/:id) - Get item by ID
async function getUsedItemByIdHandler(ctx: any) {
  const { id } = ctx.params;
  const item = mongoose.Types.ObjectId.isValid(id)
    ? await Item.findById(id)
    : await Item.findOne({ id });

  if (!item || item.status === 'deleted') {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Used item not found.' };
    return;
  }

  ctx.status = 200;
  ctx.body = formatItem(item);
}

// 3. POST /usedItems (and POST /listings) - Create new used item
async function createUsedItemHandler(ctx: any) {
  const { title, priceNzd, location, imageUrl, isSustainable, category, description, condition } = ctx.request.body as any;
  const ownerId = ctx.state.user.id;

  if (!title || priceNzd == null || !location || !imageUrl || isSustainable === undefined || !category) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing product listing fields.' };
    return;
  }

  const parsedLoc = parseLocation(location);
  const priceCents = Math.round(parseFloat(priceNzd.toString()) * 100);

  const newItem = await Item.create({
    sellerId: mongoose.Types.ObjectId.isValid(ownerId) ? new mongoose.Types.ObjectId(ownerId) : undefined,
    title,
    description: description || '',
    condition: condition || 'good',
    price: priceCents,
    currency: 'NZD',
    negotiable: false,
    images: [{ url: imageUrl, thumbnailUrl: imageUrl, sortOrder: 0 }],
    location: parsedLoc,
    category,
    status: 'active',
    imageUrl,
    priceNzd: priceNzd.toString(),
    isSustainable: Boolean(isSustainable),
    ownerId
  });

  ctx.status = 201;
  ctx.body = {
    status: 'created',
    item: formatItem(newItem)
  };
}

// 4. PATCH/PUT /usedItems/:id - Update used item
async function updateUsedItemHandler(ctx: any) {
  const { id } = ctx.params;
  const userId = ctx.state.user.id;
  const updates = ctx.request.body as any;

  const item = mongoose.Types.ObjectId.isValid(id)
    ? await Item.findById(id)
    : await Item.findOne({ id });

  if (!item || item.status === 'deleted') {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Used item not found.' };
    return;
  }

  const currentOwner = item.sellerId ? item.sellerId.toString() : item.ownerId;
  if (currentOwner !== userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized: You can only edit your own listings.' };
    return;
  }

  if (updates.title != null) item.title = updates.title;
  if (updates.description != null) item.description = updates.description;
  if (updates.category != null) item.category = updates.category;
  if (updates.condition != null) item.condition = updates.condition;
  if (updates.status != null) item.status = updates.status;
  if (updates.isSustainable != null) item.isSustainable = Boolean(updates.isSustainable);
  if (updates.imageUrl != null) {
    item.imageUrl = updates.imageUrl;
    item.images = [{ url: updates.imageUrl, thumbnailUrl: updates.imageUrl, sortOrder: 0 }];
  }
  if (updates.priceNzd != null) {
    item.priceNzd = updates.priceNzd.toString();
    item.price = Math.round(parseFloat(updates.priceNzd.toString()) * 100);
  }
  if (updates.location != null) {
    item.location = parseLocation(updates.location);
  }

  await item.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    item: formatItem(item)
  };
}

// 5. DELETE /usedItems/:id - Delete used item
async function deleteUsedItemHandler(ctx: any) {
  const { id } = ctx.params;
  const userId = ctx.state.user.id;

  const item = mongoose.Types.ObjectId.isValid(id)
    ? await Item.findById(id)
    : await Item.findOne({ id });

  if (!item || item.status === 'deleted') {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Used item not found.' };
    return;
  }

  const currentOwner = item.sellerId ? item.sellerId.toString() : item.ownerId;
  if (currentOwner !== userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Unauthorized: You can only delete your own listings.' };
    return;
  }

  item.status = 'deleted';
  item.deletedAt = new Date();
  await item.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Used item deleted successfully.'
  };
}

// Register RESTful routes under /usedItems
router.get('/usedItems', getUsedItemsHandler);
router.get('/usedItems/:id', getUsedItemByIdHandler);
router.post('/usedItems', authenticateToken, createUsedItemHandler);
router.put('/usedItems/:id', authenticateToken, updateUsedItemHandler);
router.patch('/usedItems/:id', authenticateToken, updateUsedItemHandler);
router.delete('/usedItems/:id', authenticateToken, deleteUsedItemHandler);

// Maintain backwards compatibility with /listings
router.get('/listings', getUsedItemsHandler);
router.get('/listings/:id', getUsedItemByIdHandler);
router.post('/listings', authenticateToken, createUsedItemHandler);
router.put('/listings/:id', authenticateToken, updateUsedItemHandler);
router.patch('/listings/:id', authenticateToken, updateUsedItemHandler);
router.delete('/listings/:id', authenticateToken, deleteUsedItemHandler);

export default router;
