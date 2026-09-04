<<<<<<< HEAD
import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';
import Category from '../models/Category';
import User from '../models/User';
import { notifyWatchlistPriceDrop } from '../services/pushNotification';

const router = new Router();

const MAX_TITLE_LENGTH = 120;
const MAX_DESCRIPTION_LENGTH = 2000;
const MAX_CATEGORY_LENGTH = 50;
const MAX_IMAGE_COUNT = 10;
const VALID_CONDITIONS = new Set(['new', 'like_new', 'good', 'fair', 'poor']);

class ListingValidationError extends Error {}

function requireTrimmedText(
  value: unknown,
  fieldName: string,
  { minLength = 1, maxLength }: { minLength?: number; maxLength: number }
) {
  if (typeof value !== 'string') {
    throw new ListingValidationError(`${fieldName} is required.`);
  }
  const text = value.trim();
  if (text.length < minLength || text.length > maxLength) {
    throw new ListingValidationError(
      `${fieldName} must be between ${minLength} and ${maxLength} characters.`
    );
  }
  return text;
}

function parseListingPrice(priceNzd: unknown, priceCents: unknown) {
  if (priceNzd != null) {
    const priceText = typeof priceNzd === 'number'
      ? priceNzd.toString()
      : typeof priceNzd === 'string'
        ? priceNzd.trim()
        : '';
    if (!/^\d{1,7}(\.\d{1,2})?$/.test(priceText)) {
      throw new ListingValidationError(
        'priceNzd must be a positive amount with no more than two decimal places.'
      );
    }
    const amount = Number(priceText);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new ListingValidationError('priceNzd must be greater than zero.');
    }
    return {
      priceCents: Math.round(amount * 100),
      priceNzd: priceText
    };
  }

  const cents = Number(priceCents);
  if (!Number.isSafeInteger(cents) || cents <= 0) {
    throw new ListingValidationError(
      'A positive priceNzd amount or integer price in cents is required.'
    );
  }
  return {
    priceCents: cents,
    priceNzd: (cents / 100).toString()
  };
}

function parseRequiredLocation(location: unknown) {
  if (typeof location === 'string') {
    const label = location.trim();
    if (label.length < 2 || label.length > 120) {
      throw new ListingValidationError(
        'Location must contain a suburb or city between 2 and 120 characters.'
      );
    }
    return parseLocation(label);
  }

  if (!location || typeof location !== 'object' || Array.isArray(location)) {
    throw new ListingValidationError('A suburb or city is required.');
  }

  const value = location as Record<string, unknown>;
  const city = typeof value.city === 'string' ? value.city.trim() : '';
  const suburb = typeof value.suburb === 'string' ? value.suburb.trim() : '';
  if (!city && !suburb) {
    throw new ListingValidationError('A suburb or city is required.');
  }
  if (city.length > 80 || suburb.length > 80) {
    throw new ListingValidationError(
      'Location city and suburb must each be 80 characters or fewer.'
    );
  }

  const nestedCoordinates = value.coordinates as
    | { coordinates?: unknown }
    | undefined;
  const coordinatePair = nestedCoordinates?.coordinates;
  const hasNestedCoordinates = nestedCoordinates !== undefined;
  const hasFlatLatitude = value.latitude !== undefined && value.latitude !== null;
  const hasFlatLongitude = value.longitude !== undefined && value.longitude !== null;
  let latitude: number | undefined;
  let longitude: number | undefined;

  const parseCoordinate = (coordinate: unknown) => {
    if (typeof coordinate === 'number') return coordinate;
    if (typeof coordinate === 'string' && coordinate.trim() !== '') {
      return Number(coordinate);
    }
    return Number.NaN;
  };

  if (hasNestedCoordinates) {
    if (!Array.isArray(coordinatePair) || coordinatePair.length !== 2) {
      throw new ListingValidationError(
        'Location coordinates must contain longitude and latitude.'
      );
    }
    longitude = parseCoordinate(coordinatePair[0]);
    latitude = parseCoordinate(coordinatePair[1]);
  } else if (hasFlatLatitude || hasFlatLongitude) {
    if (!hasFlatLatitude || !hasFlatLongitude) {
      throw new ListingValidationError(
        'Location latitude and longitude must be supplied together.'
      );
    }
    latitude = parseCoordinate(value.latitude);
    longitude = parseCoordinate(value.longitude);
  }

  const parsed: any = { city, suburb };
  if (latitude !== undefined || longitude !== undefined) {
    if (
      !Number.isFinite(latitude)
      || !Number.isFinite(longitude)
      || latitude! < -90
      || latitude! > 90
      || longitude! < -180
      || longitude! > 180
    ) {
      throw new ListingValidationError('Location coordinates are invalid.');
    }
    parsed.coordinates = {
      type: 'Point' as const,
      coordinates: [longitude, latitude]
    };
  }
  return parsed;
}

function requirePublicImageUrl(value: unknown, fieldName: string) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new ListingValidationError(`${fieldName} must be a public image URL.`);
  }
  try {
    const url = new URL(value.trim());
    if ((url.protocol !== 'https:' && url.protocol !== 'http:') || url.href.length > 2048) {
      throw new Error('Invalid image URL');
    }
    return url.href;
  } catch (_) {
    throw new ListingValidationError(`${fieldName} must be a valid HTTP(S) URL.`);
  }
}

function parseRequiredImages(images: unknown, imageUrl: unknown) {
  if (Array.isArray(images) && images.length > 0) {
    if (images.length > MAX_IMAGE_COUNT) {
      throw new ListingValidationError(
        `A listing can contain at most ${MAX_IMAGE_COUNT} images.`
      );
    }
    return images.map((image, index) => {
      const value = typeof image === 'string' ? { url: image } : image;
      if (!value || typeof value !== 'object' || Array.isArray(value)) {
        throw new ListingValidationError(`images[${index}] is invalid.`);
      }
      const record = value as Record<string, unknown>;
      const url = requirePublicImageUrl(
        record.url ?? record.thumbnailUrl,
        `images[${index}].url`
      );
      const thumbnailUrl = record.thumbnailUrl == null
        ? url
        : requirePublicImageUrl(record.thumbnailUrl, `images[${index}].thumbnailUrl`);
      return { url, thumbnailUrl, sortOrder: index };
    });
  }

  if (images !== undefined && !Array.isArray(images)) {
    throw new ListingValidationError('images must be an array of uploaded image URLs.');
  }

  const url = requirePublicImageUrl(imageUrl, 'imageUrl');
  return [{ url, thumbnailUrl: url, sortOrder: 0 }];
}

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
      displayName: itemObj.sellerId.displayName || 'Kiwi Member',
      email: itemObj.sellerId.email,
      avatarUrl: itemObj.sellerId.avatarUrl,
      trustScore: itemObj.sellerId.trustScore ?? 100,
      isVerified: Boolean(itemObj.sellerId.isVerified),
      isStudentVerified: Boolean(itemObj.sellerId.isStudentVerified),
      studentInstitution: itemObj.sellerId.studentInstitution || 'University of Auckland',
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

  let itemQuery = Item.find(filter).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');
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
    ? await Item.findById(id).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role')
    : await Item.findOne({ id }).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');

  if (!item || item.status === 'deleted') {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Used item not found.' };
    return;
  }

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
  const ownerId = ctx.state.user.id;
  if (!mongoose.Types.ObjectId.isValid(ownerId) || !await User.exists({ _id: ownerId })) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'The authenticated user no longer exists.' };
    return;
  }

  let validated: {
    title: string;
    description: string;
    category: string;
    condition: string;
    priceCents: number;
    priceNzd: string;
    images: Array<{ url: string; thumbnailUrl: string; sortOrder: number }>;
    location: any;
    isSustainable: boolean;
  };
  try {
    const title = requireTrimmedText(body.title, 'Title', {
      minLength: 3,
      maxLength: MAX_TITLE_LENGTH
    });
    const category = requireTrimmedText(body.category, 'Category', {
      maxLength: MAX_CATEGORY_LENGTH
    });
    const description = body.description == null
      ? ''
      : requireTrimmedText(body.description, 'Description', {
          minLength: 0,
          maxLength: MAX_DESCRIPTION_LENGTH
        });
    const condition = body.condition == null ? 'good' : String(body.condition).trim();
    if (!VALID_CONDITIONS.has(condition)) {
      throw new ListingValidationError(
        `Condition must be one of: ${Array.from(VALID_CONDITIONS).join(', ')}.`
      );
    }
    if (body.isSustainable != null && typeof body.isSustainable !== 'boolean') {
      throw new ListingValidationError('isSustainable must be a boolean.');
    }
    const parsedPrice = parseListingPrice(body.priceNzd, body.price);
    validated = {
      title,
      description,
      category,
      condition,
      ...parsedPrice,
      images: parseRequiredImages(body.images, body.imageUrl),
      location: parseRequiredLocation(
        body.location ?? (body.city || body.suburb
          ? { city: body.city, suburb: body.suburb }
          : undefined)
      ),
      isSustainable: body.isSustainable ?? false
    };
  } catch (error) {
    if (!(error instanceof ListingValidationError)) throw error;
    ctx.status = 400;
    ctx.body = { status: 'error', message: error.message };
    return;
  }

  const newItem = await Item.create({
    sellerId: new mongoose.Types.ObjectId(ownerId),
    title: validated.title,
    description: validated.description,
    condition: validated.condition,
    price: validated.priceCents,
    currency: 'NZD',
    negotiable: false,
    images: validated.images,
    location: validated.location,
    category: validated.category,
    status: 'active',
    imageUrl: validated.images[0].url,
    priceNzd: validated.priceNzd,
    isSustainable: validated.isSustainable,
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

  const updateFields: Record<string, unknown> = {};

  if (updates.title != null) updateFields.title = updates.title;
  if (updates.description != null) updateFields.description = updates.description;
  if (updates.category != null) updateFields.category = updates.category;
  if (updates.condition != null) updateFields.condition = updates.condition;
  if (updates.status != null) updateFields.status = updates.status;
  if (updates.isSustainable != null) {
    updateFields.isSustainable = Boolean(updates.isSustainable);
  }
  if (updates.imageUrl != null) {
    updateFields.imageUrl = updates.imageUrl;
    updateFields.images = [
      { url: updates.imageUrl, thumbnailUrl: updates.imageUrl, sortOrder: 0 }
    ];
  }
  if (updates.priceNzd != null || updates.price != null) {
    try {
      const parsedPrice = parseListingPrice(updates.priceNzd, updates.price);
      updateFields.priceNzd = parsedPrice.priceNzd;
      updateFields.price = parsedPrice.priceCents;
    } catch (error) {
      if (error instanceof ListingValidationError) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: error.message };
        return;
      }
      throw error;
    }
  }
  if (updates.location != null) {
    updateFields.location = parseLocation(updates.location);
  }

  // A single atomic update returns the document immediately before this
  // request's successful write. This pre-image is the authoritative previous
  // price even when multiple PATCH requests race. Updating only explicit
  // fields also avoids replacing unrelated concurrent changes.
  const ownerFilter = item.sellerId
    ? { sellerId: item.sellerId }
    : { ownerId: userId };
  const previousItem = await Item.findOneAndUpdate(
    {
      _id: item._id,
      status: { $ne: 'deleted' },
      ...ownerFilter
    },
    { $set: updateFields },
    { new: false, runValidators: true }
  );

  if (!previousItem) {
    const latestItem = await Item.findById(item._id);
    if (!latestItem || latestItem.status === 'deleted') {
      ctx.status = 404;
      ctx.body = { status: 'error', message: 'Used item not found.' };
    } else {
      ctx.status = 403;
      ctx.body = {
        status: 'error',
        message: 'Unauthorized: You can only edit your own listings.'
      };
    }
    return;
  }

  const previousPriceCents = previousItem.price;
  const previousPriceNzd = previousItem.priceNzd;
  const updatedItem = previousItem;
  updatedItem.set(updateFields);
  const newPriceCents = updatedItem.price;
  const newPriceNzd = updatedItem.priceNzd;

  // Price drop detection: trigger notifications only if newPrice < oldPrice
  if (newPriceCents < previousPriceCents) {
    // A fresh immutable identity represents this persisted price-change event.
    // It intentionally does not deduplicate by item/new price, because a later
    // genuine drop may return to a price seen in an earlier event.
    const eventId = new mongoose.Types.ObjectId().toHexString();
    notifyWatchlistPriceDrop({
      item: updatedItem,
      oldPriceNzd: previousPriceNzd,
      newPriceNzd,
      oldPriceCents: previousPriceCents,
      newPriceCents,
      eventId
    }).catch((err) => {
      console.warn(
        '[Notification] Background price drop dispatch warning:',
        err instanceof Error ? err.message : err
      );
    });
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    item: formatItem(updatedItem)
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

  const items = await Item.find(filter).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');
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
=======
import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';
import Category from '../models/Category';
import User from '../models/User';
import { notifyWatchlistPriceDrop } from '../services/pushNotification';
import { sendAdminItemNotification } from '../services/adminNotification';

const router = new Router();

const MAX_TITLE_LENGTH = 120;
const MAX_DESCRIPTION_LENGTH = 2000;
const MAX_CATEGORY_LENGTH = 50;
const MAX_IMAGE_COUNT = 10;
const VALID_CONDITIONS = new Set(['new', 'like_new', 'good', 'fair', 'poor']);

class ListingValidationError extends Error {}

function requireTrimmedText(
  value: unknown,
  fieldName: string,
  { minLength = 1, maxLength }: { minLength?: number; maxLength: number }
) {
  if (typeof value !== 'string') {
    throw new ListingValidationError(`${fieldName} is required.`);
  }
  const text = value.trim();
  if (text.length < minLength || text.length > maxLength) {
    throw new ListingValidationError(
      `${fieldName} must be between ${minLength} and ${maxLength} characters.`
    );
  }
  return text;
}

function parseListingPrice(priceNzd: unknown, priceCents: unknown) {
  if (priceNzd != null) {
    const priceText = typeof priceNzd === 'number'
      ? priceNzd.toString()
      : typeof priceNzd === 'string'
        ? priceNzd.trim()
        : '';
    if (!/^\d{1,7}(\.\d{1,2})?$/.test(priceText)) {
      throw new ListingValidationError(
        'priceNzd must be a positive amount with no more than two decimal places.'
      );
    }
    const amount = Number(priceText);
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new ListingValidationError('priceNzd must be greater than zero.');
    }
    return {
      priceCents: Math.round(amount * 100),
      priceNzd: priceText
    };
  }

  const cents = Number(priceCents);
  if (!Number.isSafeInteger(cents) || cents <= 0) {
    throw new ListingValidationError(
      'A positive priceNzd amount or integer price in cents is required.'
    );
  }
  return {
    priceCents: cents,
    priceNzd: (cents / 100).toString()
  };
}

function parseRequiredLocation(location: unknown) {
  if (typeof location === 'string') {
    const label = location.trim();
    if (label.length < 2 || label.length > 120) {
      throw new ListingValidationError(
        'Location must contain a suburb or city between 2 and 120 characters.'
      );
    }
    return parseLocation(label);
  }

  if (!location || typeof location !== 'object' || Array.isArray(location)) {
    throw new ListingValidationError('A suburb or city is required.');
  }

  const value = location as Record<string, unknown>;
  const city = typeof value.city === 'string' ? value.city.trim() : '';
  const suburb = typeof value.suburb === 'string' ? value.suburb.trim() : '';
  if (!city && !suburb) {
    throw new ListingValidationError('A suburb or city is required.');
  }
  if (city.length > 80 || suburb.length > 80) {
    throw new ListingValidationError(
      'Location city and suburb must each be 80 characters or fewer.'
    );
  }

  const nestedCoordinates = value.coordinates as
    | { coordinates?: unknown }
    | undefined;
  const coordinatePair = nestedCoordinates?.coordinates;
  const hasNestedCoordinates = nestedCoordinates !== undefined;
  const hasFlatLatitude = value.latitude !== undefined && value.latitude !== null;
  const hasFlatLongitude = value.longitude !== undefined && value.longitude !== null;
  let latitude: number | undefined;
  let longitude: number | undefined;

  const parseCoordinate = (coordinate: unknown) => {
    if (typeof coordinate === 'number') return coordinate;
    if (typeof coordinate === 'string' && coordinate.trim() !== '') {
      return Number(coordinate);
    }
    return Number.NaN;
  };

  if (hasNestedCoordinates) {
    if (!Array.isArray(coordinatePair) || coordinatePair.length !== 2) {
      throw new ListingValidationError(
        'Location coordinates must contain longitude and latitude.'
      );
    }
    longitude = parseCoordinate(coordinatePair[0]);
    latitude = parseCoordinate(coordinatePair[1]);
  } else if (hasFlatLatitude || hasFlatLongitude) {
    if (!hasFlatLatitude || !hasFlatLongitude) {
      throw new ListingValidationError(
        'Location latitude and longitude must be supplied together.'
      );
    }
    latitude = parseCoordinate(value.latitude);
    longitude = parseCoordinate(value.longitude);
  }

  const parsed: any = { city, suburb };
  if (latitude !== undefined || longitude !== undefined) {
    if (
      !Number.isFinite(latitude)
      || !Number.isFinite(longitude)
      || latitude! < -90
      || latitude! > 90
      || longitude! < -180
      || longitude! > 180
    ) {
      throw new ListingValidationError('Location coordinates are invalid.');
    }
    parsed.coordinates = {
      type: 'Point' as const,
      coordinates: [longitude, latitude]
    };
  }
  return parsed;
}

function requirePublicImageUrl(value: unknown, fieldName: string) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new ListingValidationError(`${fieldName} must be a public image URL.`);
  }
  try {
    const url = new URL(value.trim());
    if ((url.protocol !== 'https:' && url.protocol !== 'http:') || url.href.length > 2048) {
      throw new Error('Invalid image URL');
    }
    return url.href;
  } catch (_) {
    throw new ListingValidationError(`${fieldName} must be a valid HTTP(S) URL.`);
  }
}

function parseRequiredImages(images: unknown, imageUrl: unknown) {
  if (Array.isArray(images) && images.length > 0) {
    if (images.length > MAX_IMAGE_COUNT) {
      throw new ListingValidationError(
        `A listing can contain at most ${MAX_IMAGE_COUNT} images.`
      );
    }
    return images.map((image, index) => {
      const value = typeof image === 'string' ? { url: image } : image;
      if (!value || typeof value !== 'object' || Array.isArray(value)) {
        throw new ListingValidationError(`images[${index}] is invalid.`);
      }
      const record = value as Record<string, unknown>;
      const url = requirePublicImageUrl(
        record.url ?? record.thumbnailUrl,
        `images[${index}].url`
      );
      const thumbnailUrl = record.thumbnailUrl == null
        ? url
        : requirePublicImageUrl(record.thumbnailUrl, `images[${index}].thumbnailUrl`);
      return { url, thumbnailUrl, sortOrder: index };
    });
  }

  if (images !== undefined && !Array.isArray(images)) {
    throw new ListingValidationError('images must be an array of uploaded image URLs.');
  }

  const url = requirePublicImageUrl(imageUrl, 'imageUrl');
  return [{ url, thumbnailUrl: url, sortOrder: 0 }];
}

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
      displayName: itemObj.sellerId.displayName || 'Kiwi Member',
      email: itemObj.sellerId.email,
      avatarUrl: itemObj.sellerId.avatarUrl,
      trustScore: itemObj.sellerId.trustScore ?? 100,
      isVerified: Boolean(itemObj.sellerId.isVerified),
      isStudentVerified: Boolean(itemObj.sellerId.isStudentVerified),
      studentInstitution: itemObj.sellerId.studentInstitution || 'University of Auckland',
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

  let itemQuery = Item.find(filter).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');
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
    ? await Item.findById(id).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role')
    : await Item.findOne({ id }).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');

  if (!item || item.status === 'deleted') {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Used item not found.' };
    return;
  }

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
  const ownerId = ctx.state.user.id;
  const callingUser = mongoose.Types.ObjectId.isValid(ownerId)
    ? await User.findById(ownerId)
    : null;
  if (!callingUser) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'The authenticated user no longer exists.' };
    return;
  }

  let assignedSeller = callingUser;
  if (callingUser.role === 'admin') {
    const rawTargetEmail = typeof body.targetUserEmail === 'string' ? body.targetUserEmail.trim() : '';
    const rawTargetId = typeof body.targetUserId === 'string' ? body.targetUserId.trim() : '';

    if (rawTargetEmail) {
      const email = rawTargetEmail.toLowerCase();
      const targetUser = await User.findOne({ email });
      if (!targetUser) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: `Target user with email "${rawTargetEmail}" not found.` };
        return;
      }
      if (targetUser.status === 'banned' || targetUser.status === 'deleted' || targetUser.isBanned) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'Target user account is suspended or banned.' };
        return;
      }
      assignedSeller = targetUser;
    } else if (rawTargetId) {
      if (!mongoose.Types.ObjectId.isValid(rawTargetId)) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: `Invalid target user ID "${rawTargetId}".` };
        return;
      }
      const targetUser = await User.findById(rawTargetId);
      if (!targetUser) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: `Target user with ID "${rawTargetId}" not found.` };
        return;
      }
      if (targetUser.status === 'banned' || targetUser.status === 'deleted' || targetUser.isBanned) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: 'Target user account is suspended or banned.' };
        return;
      }
      assignedSeller = targetUser;
    }
  }

  let validated: {
    title: string;
    description: string;
    category: string;
    condition: string;
    priceCents: number;
    priceNzd: string;
    images: Array<{ url: string; thumbnailUrl: string; sortOrder: number }>;
    location: any;
    isSustainable: boolean;
  };
  try {
    const title = requireTrimmedText(body.title, 'Title', {
      minLength: 3,
      maxLength: MAX_TITLE_LENGTH
    });
    const category = requireTrimmedText(body.category, 'Category', {
      maxLength: MAX_CATEGORY_LENGTH
    });
    const description = body.description == null
      ? ''
      : requireTrimmedText(body.description, 'Description', {
          minLength: 0,
          maxLength: MAX_DESCRIPTION_LENGTH
        });
    const condition = body.condition == null ? 'good' : String(body.condition).trim();
    if (!VALID_CONDITIONS.has(condition)) {
      throw new ListingValidationError(
        `Condition must be one of: ${Array.from(VALID_CONDITIONS).join(', ')}.`
      );
    }
    if (body.isSustainable != null && typeof body.isSustainable !== 'boolean') {
      throw new ListingValidationError('isSustainable must be a boolean.');
    }
    const parsedPrice = parseListingPrice(body.priceNzd, body.price);
    validated = {
      title,
      description,
      category,
      condition,
      ...parsedPrice,
      images: parseRequiredImages(body.images, body.imageUrl),
      location: parseRequiredLocation(
        body.location ?? (body.city || body.suburb
          ? { city: body.city, suburb: body.suburb }
          : undefined)
      ),
      isSustainable: body.isSustainable ?? true
    };
  } catch (error) {
    if (!(error instanceof ListingValidationError)) throw error;
    ctx.status = 400;
    ctx.body = { status: 'error', message: error.message };
    return;
  }

  const newItem = await Item.create({
    sellerId: assignedSeller._id,
    title: validated.title,
    description: validated.description,
    condition: validated.condition,
    price: validated.priceCents,
    currency: 'NZD',
    negotiable: false,
    images: validated.images,
    location: validated.location,
    category: validated.category,
    status: 'active',
    imageUrl: validated.images[0].url,
    priceNzd: validated.priceNzd,
    isSustainable: validated.isSustainable,
    ownerId: assignedSeller._id.toString()
  });

  await newItem.populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');

  // If created by an admin and assigned to another user, send email & push notification
  if (callingUser.role === 'admin' && assignedSeller._id.toString() !== callingUser._id.toString()) {
    sendAdminItemNotification({
      userId: assignedSeller._id,
      userEmail: assignedSeller.email,
      userName: assignedSeller.displayName,
      eventType: 'transferred_to_user',
      itemTitle: newItem.title,
      itemId: newItem._id.toString(),
      itemPriceNzd: newItem.priceNzd
    }).catch((err) => {
      console.warn('[Admin Create Item Assignment Notification] Dispatch failure:', err?.message || err);
    });
  }

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

  const updateFields: Record<string, unknown> = {};

  if (updates.title != null) updateFields.title = updates.title;
  if (updates.description != null) updateFields.description = updates.description;
  if (updates.category != null) updateFields.category = updates.category;
  if (updates.condition != null) updateFields.condition = updates.condition;
  if (updates.status != null) updateFields.status = updates.status;
  if (updates.isSustainable != null) {
    updateFields.isSustainable = Boolean(updates.isSustainable);
  }
  if (updates.imageUrl != null) {
    updateFields.imageUrl = updates.imageUrl;
    updateFields.images = [
      { url: updates.imageUrl, thumbnailUrl: updates.imageUrl, sortOrder: 0 }
    ];
  }
  if (updates.priceNzd != null || updates.price != null) {
    try {
      const parsedPrice = parseListingPrice(updates.priceNzd, updates.price);
      updateFields.priceNzd = parsedPrice.priceNzd;
      updateFields.price = parsedPrice.priceCents;
    } catch (error) {
      if (error instanceof ListingValidationError) {
        ctx.status = 400;
        ctx.body = { status: 'error', message: error.message };
        return;
      }
      throw error;
    }
  }
  if (updates.location != null) {
    updateFields.location = parseLocation(updates.location);
  }

  // A single atomic update returns the document immediately before this
  // request's successful write. This pre-image is the authoritative previous
  // price even when multiple PATCH requests race. Updating only explicit
  // fields also avoids replacing unrelated concurrent changes.
  const ownerFilter = item.sellerId
    ? { sellerId: item.sellerId }
    : { ownerId: userId };
  const previousItem = await Item.findOneAndUpdate(
    {
      _id: item._id,
      status: { $ne: 'deleted' },
      ...ownerFilter
    },
    { $set: updateFields },
    { new: false, runValidators: true }
  );

  if (!previousItem) {
    const latestItem = await Item.findById(item._id);
    if (!latestItem || latestItem.status === 'deleted') {
      ctx.status = 404;
      ctx.body = { status: 'error', message: 'Used item not found.' };
    } else {
      ctx.status = 403;
      ctx.body = {
        status: 'error',
        message: 'Unauthorized: You can only edit your own listings.'
      };
    }
    return;
  }

  const previousPriceCents = previousItem.price;
  const previousPriceNzd = previousItem.priceNzd;
  const updatedItem = previousItem;
  updatedItem.set(updateFields);
  const newPriceCents = updatedItem.price;
  const newPriceNzd = updatedItem.priceNzd;

  // Price drop detection: trigger notifications only if newPrice < oldPrice
  if (newPriceCents < previousPriceCents) {
    // A fresh immutable identity represents this persisted price-change event.
    // It intentionally does not deduplicate by item/new price, because a later
    // genuine drop may return to a price seen in an earlier event.
    const eventId = new mongoose.Types.ObjectId().toHexString();
    notifyWatchlistPriceDrop({
      item: updatedItem,
      oldPriceNzd: previousPriceNzd,
      newPriceNzd,
      oldPriceCents: previousPriceCents,
      newPriceCents,
      eventId
    }).catch((err) => {
      console.warn(
        '[Notification] Background price drop dispatch warning:',
        err instanceof Error ? err.message : err
      );
    });
  }

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    item: formatItem(updatedItem)
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

  const items = await Item.find(filter).populate('sellerId', 'displayName email avatarUrl trustScore isVerified isStudentVerified studentInstitution role');
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
>>>>>>> pre
