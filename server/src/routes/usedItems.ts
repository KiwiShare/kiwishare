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
    : [suburb, city].filter(Boolean).join(', ') || 'Location not supplied';
  const coordinates = itemObj.location?.coordinates?.coordinates;
  const longitude = Array.isArray(coordinates) && coordinates.length === 2
    ? Number(coordinates[0])
    : undefined;
  const latitude = Array.isArray(coordinates) && coordinates.length === 2
    ? Number(coordinates[1])
    : undefined;

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
    sellerId: ownerId,
    latitude: Number.isFinite(latitude) ? latitude : null,
    longitude: Number.isFinite(longitude) ? longitude : null
  };
}

// Helper to parse location string into structured location object
function parseLocation(location: string | any) {
  if (location && typeof location === 'object') {
    const city = typeof location.city === 'string' ? location.city.trim() : '';
    const suburb = typeof location.suburb === 'string' ? location.suburb.trim() : '';
    const suppliedCoordinates = location.coordinates?.coordinates;
    const longitude = Array.isArray(suppliedCoordinates)
      ? Number(suppliedCoordinates[0])
      : Number(location.longitude);
    const latitude = Array.isArray(suppliedCoordinates)
      ? Number(suppliedCoordinates[1])
      : Number(location.latitude);
    const parsed: any = { city, suburb };

    if (Number.isFinite(latitude) && Number.isFinite(longitude)
      && latitude >= -90 && latitude <= 90
      && longitude >= -180 && longitude <= 180) {
      parsed.coordinates = {
        type: 'Point' as const,
        coordinates: [longitude, latitude]
      };
    }
    return parsed;
  }

  if (typeof location !== 'string') return { city: '', suburb: '' };
  const parts = location.split(',').map((s: string) => s.trim());
  const city = parts[parts.length - 1] || '';
  const suburb = parts.length > 1 ? parts[0] : '';
  return { city, suburb };
}

function queryText(value: unknown) {
  return Array.isArray(value) ? value[0] : value;
}

function parseOptionalNumber(value: unknown) {
  const parsed = Number(queryText(value));
  return Number.isFinite(parsed) ? parsed : undefined;
}

function escapeRegExp(value: string) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

// --- RESTful Used Items Endpoints ---

// 1. GET /usedItems (and GET /listings) - List & filter used items
async function getUsedItemsHandler(ctx: any) {
  const {
    category,
    query,
    status,
    ownerId,
    sellerId,
    location,
    minPrice,
    maxPrice,
    sustainable,
    sort,
    latitude,
    longitude,
    radiusKm
  } = ctx.query;
  const filter: any = {};

  if (category && category !== 'All NZ' && category !== 'All') {
    filter.category = new RegExp(`^${escapeRegExp(String(queryText(category)))}$`, 'i');
  }

  if (status) {
    if (status.includes(',')) {
      filter.status = { $in: status.split(',').map((s: string) => s.trim()) };
    } else {
      filter.status = status;
    }
  } else {
    filter.status = 'active';
  }

  const locationText = queryText(location);
  if (typeof locationText === 'string' && locationText.trim() !== '' && locationText !== 'All NZ') {
    filter['location.city'] = new RegExp(`^${escapeRegExp(locationText.trim())}$`, 'i');
  }

  const minimumPrice = parseOptionalNumber(minPrice);
  const maximumPrice = parseOptionalNumber(maxPrice);
  if (minimumPrice !== undefined || maximumPrice !== undefined) {
    filter.price = {};
    if (minimumPrice !== undefined) filter.price.$gte = Math.round(minimumPrice * 100);
    if (maximumPrice !== undefined) filter.price.$lte = Math.round(maximumPrice * 100);
  }

  if (queryText(sustainable) === 'true') filter.isSustainable = true;

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

  const searchText = queryText(query);
  if (typeof searchText === 'string' && searchText.trim() !== '') {
    const searchRegex = new RegExp(escapeRegExp(searchText.trim()), 'i');
    filter.$or = [
      { title: searchRegex },
      { category: searchRegex },
      { description: searchRegex },
      { 'location.city': searchRegex },
      { 'location.suburb': searchRegex }
    ];
  }

  const nearbyLatitude = parseOptionalNumber(latitude);
  const nearbyLongitude = parseOptionalNumber(longitude);
  const nearbyRadiusKm = parseOptionalNumber(radiusKm) ?? 50;
  const hasNearbyFilter = nearbyLatitude !== undefined && nearbyLongitude !== undefined;
  if (hasNearbyFilter) {
    filter['location.coordinates'] = {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: [nearbyLongitude, nearbyLatitude]
        },
        $maxDistance: Math.max(1, nearbyRadiusKm) * 1000
      }
    };
  }

  let itemQuery = Item.find(filter);
  const sortValue = queryText(sort);
  if (sortValue === 'price_asc') {
    itemQuery = itemQuery.sort({ price: 1, createdAt: -1 });
  } else if (sortValue === 'price_desc') {
    itemQuery = itemQuery.sort({ price: -1, createdAt: -1 });
  } else if (!hasNearbyFilter) {
    itemQuery = itemQuery.sort({ favouriteCount: -1, viewCount: -1, createdAt: -1 });
  }

  const items = await itemQuery;
  ctx.status = 200;
  ctx.body = items.map(formatItem);
}

async function getDiscoveryOptionsHandler(ctx: any) {
  const [facets] = await Item.aggregate([
    { $match: { status: 'active' } },
    {
      $facet: {
        categories: [
          { $match: { category: { $type: 'string', $ne: '' } } },
          {
            $group: {
              _id: { $toLower: '$category' },
              value: { $first: '$category' },
              count: { $sum: 1 }
            }
          },
          { $sort: { value: 1 } }
        ],
        locations: [
          { $match: { 'location.city': { $type: 'string', $ne: '' } } },
          {
            $group: {
              _id: { $toLower: '$location.city' },
              value: { $first: '$location.city' },
              count: { $sum: 1 },
              coordinates: { $push: '$location.coordinates.coordinates' }
            }
          },
          { $sort: { value: 1 } }
        ],
        prices: [
          { $match: { price: { $type: 'number' } } },
          {
            $group: {
              _id: null,
              minimum: { $min: '$price' },
              maximum: { $max: '$price' }
            }
          }
        ]
      }
    }
  ]);

  const locations = (facets?.locations || []).map((entry: any) => {
    const points = (entry.coordinates || []).filter((coordinates: unknown) =>
      Array.isArray(coordinates)
      && coordinates.length === 2
      && coordinates.every((coordinate) => Number.isFinite(Number(coordinate)))
    );
    const longitude = points.length === 0
      ? null
      : points.reduce((sum: number, point: number[]) => sum + Number(point[0]), 0) / points.length;
    const latitude = points.length === 0
      ? null
      : points.reduce((sum: number, point: number[]) => sum + Number(point[1]), 0) / points.length;
    return {
      value: entry.value,
      count: entry.count,
      latitude,
      longitude
    };
  });
  const prices = facets?.prices?.[0];

  ctx.status = 200;
  ctx.body = {
    categories: (facets?.categories || []).map((entry: any) => ({
      value: entry.value,
      count: entry.count
    })),
    locations,
    priceRange: {
      minimum: prices ? prices.minimum / 100 : null,
      maximum: prices ? prices.maximum / 100 : null
    }
  };
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
router.get('/usedItems/discovery-options', getDiscoveryOptionsHandler);
router.get('/usedItems/:id', getUsedItemByIdHandler);
router.post('/usedItems', authenticateToken, createUsedItemHandler);
router.put('/usedItems/:id', authenticateToken, updateUsedItemHandler);
router.patch('/usedItems/:id', authenticateToken, updateUsedItemHandler);
router.delete('/usedItems/:id', authenticateToken, deleteUsedItemHandler);

// Maintain backwards compatibility with /listings
router.get('/listings', getUsedItemsHandler);
router.get('/listings/discovery-options', getDiscoveryOptionsHandler);
router.get('/listings/:id', getUsedItemByIdHandler);
router.post('/listings', authenticateToken, createUsedItemHandler);
router.put('/listings/:id', authenticateToken, updateUsedItemHandler);
router.patch('/listings/:id', authenticateToken, updateUsedItemHandler);
router.delete('/listings/:id', authenticateToken, deleteUsedItemHandler);

export default router;
