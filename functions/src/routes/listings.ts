import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';

const router = new Router();

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
      { 'location.city': searchRegex },
      { 'location.suburb': searchRegex }
    ];
  }

  const listings = await Item.find(filter).sort({ createdAt: -1 });
  const formattedListings = listings.map(item => {
    const itemObj = item.toObject({ virtuals: true });
    const suburb = itemObj.location?.suburb || '';
    const city = itemObj.location?.city || '';
    const locationStr = [suburb, city].filter(Boolean).join(', ') || 'Auckland';
    const coordinates = itemObj.location?.coordinates?.coordinates;

    return {
      ...itemObj,
      id: itemObj.id,
      imageUrl: itemObj.images?.[0]?.url || itemObj.imageUrl || '',
      location: locationStr,
      priceNzd: itemObj.priceNzd || (itemObj.price ? (itemObj.price / 100).toString() : '0'),
      ownerId: itemObj.sellerId?.toString() || itemObj.ownerId || '',
      longitude: Array.isArray(coordinates) ? coordinates[0] : undefined,
      latitude: Array.isArray(coordinates) ? coordinates[1] : undefined
    };
  });

  ctx.status = 200;
  ctx.body = formattedListings;
});

router.post('/listings', authenticateToken, async (ctx) => {
  const { title, priceNzd, location, imageUrl, isSustainable, category } = ctx.request.body as any;
  const ownerId = ctx.state.user.id;

  if (!title || !priceNzd || !location || !imageUrl || isSustainable === undefined || !category) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Missing product listing fields.' };
    return;
  }

  const parts = location.split(',').map((s: string) => s.trim());
  const city = parts[parts.length - 1] || 'Auckland';
  const suburb = parts.length > 1 ? parts[0] : '';
  const priceCents = Math.round(parseFloat(priceNzd) * 100);

  const newItem = await Item.create({
    sellerId: new mongoose.Types.ObjectId(ownerId),
    title,
    price: priceCents,
    currency: 'NZD',
    negotiable: false,
    images: [{ url: imageUrl, thumbnailUrl: imageUrl, sortOrder: 0 }],
    location: {
      city,
      suburb,
      coordinates: {
        type: 'Point',
        coordinates: [174.7633, -36.8485]
      }
    },
    category,
    status: 'active',
    imageUrl,
    priceNzd,
    isSustainable,
    ownerId
  });

  const itemObj = newItem.toObject({ virtuals: true });
  const formattedItem = {
    ...itemObj,
    id: itemObj.id,
    imageUrl: imageUrl,
    location: location,
    priceNzd: priceNzd,
    ownerId: ownerId
  };

  ctx.status = 201;
  ctx.body = {
    status: 'created',
    item: formattedItem
  };
});

export default router;
