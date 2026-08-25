import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';
import Category from '../models/Category';
import User from '../models/User';

const router = new Router();

// Helper to format Item document for client response
export function formatItem(itemDoc: any) {
  const itemObj = itemDoc.toObject ? itemDoc.toObject({ virtuals: true }) : itemDoc;
  const suburb = itemObj.location?.suburb || '';
  const city = itemObj.location?.city || '';
  const locationStr = typeof itemObj.location === 'string'
    ? itemObj.location
    : [suburb, city].filter(Boolean).join(', ');
  const coordinates = itemObj.location?.coordinates?.coordinates;
  const longitude = Array.isArray(coordinates) && coordinates.length === 2
    ? Number(coordinates[0])
    : undefined;
  const latitude = Array.isArray(coordinates) && coordinates.length === 2
    ? Number(coordinates[1])
    : undefined;

  const priceNzd = itemObj.priceNzd ?? (itemObj.price != null ? (itemObj.price / 100).toString() : '');
  const rawImages = Array.isArray(itemObj.images) && itemObj.images.length > 0
    ? itemObj.images
    : (itemObj.imageUrl ? [{ url: itemObj.imageUrl, sortOrder: 0 }] : []);
  const imageUrl = rawImages[0]?.url || itemObj.imageUrl || '';
  
  let sellerInfo: any = null;
  let ownerId = itemObj.ownerId || '';
  if (itemObj.sellerId && typeof itemObj.sellerId === 'object' && itemObj.sellerId.displayName) {
    ownerId = itemObj.sellerId._id?.toString() || itemObj.sellerId.id || ownerId;
    sellerInfo = {
      id: ownerId,
      displayName: itemObj.sellerId.displayName || '',
      avatarUrl: itemObj.sellerId.avatarUrl,
      trustScore: itemObj.sellerId.trustScore ?? null,
      rating: itemObj.sellerId.rating ?? null,
      reviewCount: itemObj.sellerId.reviewCount ?? null,
      isVerified: Boolean(itemObj.sellerId.isVerified),
      isStudentVerified: Boolean(itemObj.sellerId.isStudentVerified),
      studentInstitution: itemObj.sellerId.studentInstitution || null,
      role: itemObj.sellerId.role || 'user'
    };
  } else if (itemObj.sellerId) {
    ownerId = itemObj.sellerId.toString();
  }

  return {
    ...itemObj,
    id: itemObj.id || itemObj._id?.toString(),
    imageUrl,
    images: rawImages,
    location: locationStr,
    priceNzd,
    ownerId,
    sellerId: ownerId,
    seller: sellerInfo,
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

  let itemQuery = Item.find(filter).populate('sellerId', 'displayName avatarUrl trustScore rating reviewCount isVerified isStudentVerified studentInstitution role');
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
        ],
        conditions: [
          { $match: { condition: { $type: 'string', $ne: '' } } },
          {
            $group: {
              _id: { $toLower: '$condition' },
              value: { $first: '$condition' },
              count: { $sum: 1 }
            }
          },
          { $sort: { value: 1 } }
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

  // Retrieve active categories from Category model
  const dbCategories = await Category.find({ isActive: true }).sort({ sortOrder: 1, name: 1 });
  const facetCatMap = new Map<string, number>();
  (facets?.categories || []).forEach((c: any) => {
    if (c.value) facetCatMap.set(c.value.toLowerCase(), c.count);
  });

  const categories = dbCategories.length > 0
    ? dbCategories.map((cat) => ({
        value: cat.name,
        count: facetCatMap.get(cat.name.toLowerCase()) || 0
      }))
    : (facets?.categories || []).map((entry: any) => ({
        value: entry.value,
        count: entry.count
      }));

  ctx.status = 200;
  ctx.body = {
    categories,
    locations,
    conditions: (facets?.conditions || []).map((entry: any) => ({
      value: entry.value,
      count: entry.count
    })),
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
    ? await Item.findById(id).populate('sellerId', 'displayName avatarUrl trustScore rating reviewCount isVerified isStudentVerified studentInstitution role')
    : await Item.findOne({ id }).populate('sellerId', 'displayName avatarUrl trustScore rating reviewCount isVerified isStudentVerified studentInstitution role');

  if (!item || item.status === 'deleted') {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Used item not found.' };
    return;
  }

  item.viewCount = (item.viewCount || 0) + 1;
  await item.save();
  const formatted = formatItem(item);
  ctx.status = 200;
  ctx.body = {
    ...formatted,
    status: 'success',
    item: formatted
  };
}

// 3. POST /usedItems (and POST /listings) - Create new used item
async function createUsedItemHandler(ctx: any) {
  const body = ctx.request.body as any;
  const { title, priceNzd, price, location, city, suburb, imageUrl, images, isSustainable, category, description, condition, sellerId, targetUserId, targetUserEmail } = body;
  let ownerId = ctx.state.user.id;

  // Support binding item to specific user if specified
  const target = targetUserId || sellerId;
  if (target && target !== ownerId) {
    let boundUser = null;
    if (mongoose.Types.ObjectId.isValid(target)) {
      boundUser = await User.findById(target);
    }
    if (!boundUser) {
      boundUser = await User.findOne({ email: String(target).toLowerCase() });
    }
    if (boundUser) {
      ownerId = boundUser._id.toString();
    }
  } else if (targetUserEmail) {
    const boundUser = await User.findOne({ email: targetUserEmail.toLowerCase() });
    if (boundUser) {
      ownerId = boundUser._id.toString();
    }
  }

  if (!title || (priceNzd == null && price == null) || !category) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing product listing fields (title, price, category).' };
    return;
  }

  const rawLocation = location || (city ? { city, suburb } : 'Auckland');
  const parsedLoc = parseLocation(rawLocation);
  
  const finalPriceNzd = priceNzd != null 
    ? priceNzd.toString() 
    : (price != null ? (price / 100).toString() : '0');
  const priceCents = price != null 
    ? Number(price) 
    : Math.round(parseFloat(finalPriceNzd) * 100);

  const rawImageList = Array.isArray(images) && images.length > 0
    ? images.map((img: any, idx: number) => {
        if (typeof img === 'string') {
          return { url: img, thumbnailUrl: img, sortOrder: idx };
        }
        return {
          url: img.url || img.thumbnailUrl || '',
          thumbnailUrl: img.thumbnailUrl || img.url || '',
          sortOrder: img.sortOrder ?? idx
        };
      }).filter((im) => Boolean(im.url))
    : [];

  const finalImageUrl = imageUrl || (rawImageList.length > 0 ? rawImageList[0].url : 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800');

  const finalImages = rawImageList.length > 0
    ? rawImageList
    : [{ url: finalImageUrl, thumbnailUrl: finalImageUrl, sortOrder: 0 }];

  const newItem = await Item.create({
    sellerId: mongoose.Types.ObjectId.isValid(ownerId) ? new mongoose.Types.ObjectId(ownerId) : undefined,
    title,
    description: description || '',
    condition: condition || 'good',
    price: priceCents,
    currency: 'NZD',
    negotiable: false,
    images: finalImages,
    location: parsedLoc,
    category,
    status: 'active',
    imageUrl: finalImageUrl,
    priceNzd: finalPriceNzd,
    isSustainable: isSustainable !== undefined ? Boolean(isSustainable) : true,
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

  if (updates.title != null) {
    const title = String(updates.title).trim();
    if (title.length < 3 || title.length > 120) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'Title must be between 3 and 120 characters.' };
      return;
    }
    item.title = title;
  }
  if (updates.description != null) {
    const description = String(updates.description).trim();
    if (description.length > 2000) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'Description must be 2000 characters or fewer.' };
      return;
    }
    item.description = description;
  }
  if (updates.category != null) {
    const category = String(updates.category).trim();
    const storedCategory = await Category.findOne({ name: category, isActive: true });
    if (!storedCategory) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'Choose an active category from the database.' };
      return;
    }
    item.category = storedCategory.name;
  }
  if (updates.condition != null) {
    const condition = String(updates.condition).trim();
    if (condition.length === 0 || condition.length > 60) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'Condition must be between 1 and 60 characters.' };
      return;
    }
    item.condition = condition;
  }
  if (updates.isSustainable != null) item.isSustainable = Boolean(updates.isSustainable);
  if (updates.negotiable != null) item.negotiable = Boolean(updates.negotiable);
  if (updates.imageUrl != null) {
    item.imageUrl = updates.imageUrl;
    item.images = [{ url: updates.imageUrl, thumbnailUrl: updates.imageUrl, sortOrder: 0 }];
  }
  if (updates.priceNzd != null) {
    const price = Number(updates.priceNzd);
    if (!Number.isFinite(price) || price < 0) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'Price must be a non-negative number.' };
      return;
    }
    item.priceNzd = price.toString();
    item.price = Math.round(price * 100);
  }
  if (updates.location != null) {
    item.location = parseLocation(updates.location);
  }

  await item.save();
  await item.populate('sellerId', 'displayName avatarUrl trustScore rating reviewCount isVerified isStudentVerified studentInstitution role');

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

// 1b. GET /usedItems/recommended - Get recommended used items
async function getRecommendedItemsHandler(ctx: any) {
  const { limit = '10', category, excludeId } = ctx.query;
  const maxItems = Math.min(Math.max(1, parseInt(queryText(limit) || '10', 10) || 10), 50);

  const filter: any = { status: 'active' };

  const categoryText = queryText(category);
  if (typeof categoryText === 'string' && categoryText.trim() !== '' && categoryText !== 'All' && categoryText !== 'All NZ') {
    filter.category = new RegExp(`^${escapeRegExp(categoryText.trim())}$`, 'i');
  }

  const exclude = queryText(excludeId);
  if (typeof exclude === 'string' && exclude.trim() !== '') {
    if (mongoose.Types.ObjectId.isValid(exclude)) {
      filter._id = { $ne: new mongoose.Types.ObjectId(exclude) };
    }
  }

  const items = await Item.find(filter).populate('sellerId', 'displayName avatarUrl trustScore rating reviewCount isVerified isStudentVerified studentInstitution role');
  const now = Date.now();

  // Multi-factor Recommendation Scoring Algorithm:
  // 1. Popularity score: favouriteCount * 3 + viewCount * 1
  // 2. Freshness decay: 20 * exp(-ageInDays / 14)
  // 3. Sustainability boost: +10 points
  // 4. Condition quality boost: new (+6), like_new (+4), good (+2)
  const scoredItems = items.map((item) => {
    const favScore = (item.favouriteCount || 0) * 3;
    const viewScore = (item.viewCount || 0) * 1;
    const createdAtTime = item.createdAt ? new Date(item.createdAt).getTime() : now;
    const ageInDays = Math.max(0, (now - createdAtTime) / (1000 * 60 * 60 * 24));
    const freshnessScore = 20 * Math.exp(-ageInDays / 14);
    const sustainabilityScore = item.isSustainable ? 10 : 0;

    let conditionScore = 0;
    if (item.condition === 'new') conditionScore = 6;
    else if (item.condition === 'like_new') conditionScore = 4;
    else if (item.condition === 'good') conditionScore = 2;

    const totalScore = favScore + viewScore + freshnessScore + sustainabilityScore + conditionScore;
    return { item, score: totalScore };
  });

  scoredItems.sort((a, b) => b.score - a.score);
  const recommended = scoredItems.slice(0, maxItems).map((entry) => formatItem(entry.item));

  ctx.status = 200;
  ctx.body = recommended;
}

// Register RESTful routes under /usedItems
router.get('/usedItems', getUsedItemsHandler);
router.get('/usedItems/discovery-options', getDiscoveryOptionsHandler);
router.get('/usedItems/recommended', getRecommendedItemsHandler);
router.get('/usedItems/:id', getUsedItemByIdHandler);
router.post('/usedItems', authenticateToken, createUsedItemHandler);
router.put('/usedItems/:id', authenticateToken, updateUsedItemHandler);
router.patch('/usedItems/:id', authenticateToken, updateUsedItemHandler);
router.delete('/usedItems/:id', authenticateToken, deleteUsedItemHandler);

export default router;
