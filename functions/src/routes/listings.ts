import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';

const router = new Router();

const escapeRegExp = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const formatListing = (item: any, distanceKm?: number) => {
  const itemObj = item.toObject({ virtuals: true });
  const suburb = itemObj.location?.suburb || '';
  const city = itemObj.location?.city || '';
  const coordinates = itemObj.location?.coordinates?.coordinates;
  return {
    ...itemObj,
    id: itemObj.id,
    imageUrl: itemObj.images?.[0]?.url || itemObj.imageUrl || '',
    location: [suburb, city].filter(Boolean).join(', ') || 'Location unavailable',
    priceNzd: itemObj.priceNzd || (itemObj.price ? (itemObj.price / 100).toString() : '0'),
    ownerId: itemObj.sellerId?.toString() || itemObj.ownerId || '',
    latitude: coordinates?.[1],
    longitude: coordinates?.[0],
    ...(distanceKm === undefined ? {} : { distanceKm: Number(distanceKm.toFixed(1)) })
  };
};

const distanceKm = (lat: number, lng: number, item: any) => {
  const coordinates = item.location?.coordinates?.coordinates;
  if (!coordinates || coordinates.length < 2) return undefined;
  const [itemLng, itemLat] = coordinates;
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const dLat = radians(itemLat - lat);
  const dLng = radians(itemLng - lng);
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(radians(lat)) * Math.cos(radians(itemLat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

router.get('/listings', async (ctx) => {
  const { category, query, location, sort, latitude, longitude, radiusKm, limit } = ctx.query;
  const filter: any = { status: 'active' };

  if (typeof category === 'string' && category !== 'All NZ' && category !== 'All') {
    const aliases = category.toLowerCase() === 'transport' ? ['Transport', 'Vehicle'] : [category];
    filter.category = { $in: aliases.map(value => new RegExp(`^${escapeRegExp(value)}$`, 'i')) };
  }
  if (typeof query === 'string' && query.trim()) {
    const searchRegex = new RegExp(escapeRegExp(query.trim()), 'i');
    filter.$or = [
      { title: searchRegex },
      { description: searchRegex },
      { category: searchRegex },
      { 'location.city': searchRegex },
      { 'location.suburb': searchRegex }
    ];
  }
  if (typeof location === 'string' && location.trim()) {
    const locationRegex = new RegExp(escapeRegExp(location.trim()), 'i');
    filter.$and = [{ $or: [{ 'location.city': locationRegex }, { 'location.suburb': locationRegex }] }];
  }

  const sortMap: Record<string, any> = {
    popular: { favouriteCount: -1, viewCount: -1, createdAt: -1 },
    newest: { createdAt: -1 },
    price_asc: { price: 1 },
    price_desc: { price: -1 }
  };
  const selectedSort = typeof sort === 'string' ? sort : 'popular';
  const requestedLimit = Math.min(Math.max(Number(limit) || 50, 1), 100);
  const listings = await Item.find(filter).sort(sortMap[selectedSort] || sortMap.popular).limit(requestedLimit);

  const lat = Number(latitude);
  const lng = Number(longitude);
  if (Number.isFinite(lat) && Number.isFinite(lng)) {
    const radius = Math.min(Math.max(Number(radiusKm) || 25, 1), 100);
    const withDistance = listings
      .map(item => ({ item, distance: distanceKm(lat, lng, item) }))
      .filter(entry => entry.distance !== undefined && entry.distance <= radius);
    if (selectedSort === 'nearest') withDistance.sort((a, b) => a.distance! - b.distance!);
    ctx.body = withDistance.map(entry => formatListing(entry.item, entry.distance));
  } else {
    ctx.body = listings.map(item => formatListing(item));
  }
  ctx.status = 200;
});

router.get('/listings/:id', async (ctx) => {
  if (!mongoose.Types.ObjectId.isValid(ctx.params.id)) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing not found.' };
    return;
  }
  const listing = await Item.findById(ctx.params.id);
  if (!listing) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing not found.' };
    return;
  }
  ctx.status = 200;
  ctx.body = formatListing(listing);
});

router.post('/listings', authenticateToken, async (ctx) => {
  const { title, priceNzd, location, imageUrl, isSustainable, category } = ctx.request.body as any;
  const ownerId = ctx.state.user.id;
  if (!title || !priceNzd || !location || !imageUrl || isSustainable === undefined || !category) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing product listing fields.' };
    return;
  }
  const parts = location.split(',').map((value: string) => value.trim());
  const city = parts[parts.length - 1] || 'Auckland';
  const suburb = parts.length > 1 ? parts[0] : '';
  const newItem = await Item.create({
    sellerId: new mongoose.Types.ObjectId(ownerId),
    title,
    price: Math.round(parseFloat(priceNzd) * 100),
    currency: 'NZD',
    negotiable: false,
    images: [{ url: imageUrl, thumbnailUrl: imageUrl, sortOrder: 0 }],
    location: { city, suburb, coordinates: { type: 'Point', coordinates: [174.7633, -36.8485] } },
    category,
    status: 'active',
    imageUrl,
    priceNzd,
    isSustainable,
    ownerId
  });
  ctx.status = 201;
  ctx.body = { status: 'created', item: formatListing(newItem) };
});

export default router;
