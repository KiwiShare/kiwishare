import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Item from '../models/Item';

const router = new Router();

// --- 2. Listing Endpoints ---

const visibleListingStatuses = ['active', 'reserved', 'sold'];

function formatListing(item: any) {
  const itemObj = item.toObject({ virtuals: true });
  const populatedSeller =
    itemObj.sellerId && typeof itemObj.sellerId === 'object' && itemObj.sellerId._id
      ? itemObj.sellerId
      : null;
  const ownerId = populatedSeller?._id?.toString() || itemObj.sellerId?.toString() || itemObj.ownerId || '';
  const suburb = itemObj.location?.suburb || '';
  const city = itemObj.location?.city || '';
  const location = [suburb, city].filter(Boolean).join(', ') || 'Auckland';
  const imageUrls = (itemObj.images || [])
    .slice()
    .sort((first: any, second: any) => (first.sortOrder || 0) - (second.sortOrder || 0))
    .map((image: any) => image.url)
    .filter(Boolean);
  const imageUrl = imageUrls[0] || itemObj.imageUrl || '';

  return {
    ...itemObj,
    id: itemObj.id,
    sellerId: ownerId,
    ownerId,
    imageUrl,
    imageUrls: imageUrls.length > 0 ? imageUrls : imageUrl ? [imageUrl] : [],
    location,
    priceNzd: itemObj.priceNzd || (itemObj.price ? (itemObj.price / 100).toString() : '0'),
    sellerName: populatedSeller?.displayName || null,
    sellerAvatarUrl: populatedSeller?.avatarUrl || null,
    sellerRating: populatedSeller?.rating ?? null,
    sellerReviewCount: populatedSeller?.reviewCount ?? null,
    sellerTrustScore: populatedSeller?.trustScore ?? null,
    sellerIsVerified: populatedSeller?.isVerified ?? false
  };
}

router.get('/listings', async (ctx) => {
  const { category, query } = ctx.query;
  const filter: any = { status: { $in: ['active', 'reserved'] } };

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

  const listings = await Item.find(filter)
    .populate('sellerId', 'displayName avatarUrl rating reviewCount trustScore isVerified')
    .sort({ createdAt: -1 });
  const formattedListings = listings.map(formatListing);

  ctx.status = 200;
  ctx.body = formattedListings;
});

router.get('/listings/:id', async (ctx) => {
  const { id } = ctx.params;
  if (!mongoose.Types.ObjectId.isValid(id)) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing item not found.' };
    return;
  }

  const item = await Item.findOne({
    _id: new mongoose.Types.ObjectId(id),
    status: { $in: visibleListingStatuses }
  }).populate('sellerId', 'displayName avatarUrl rating reviewCount trustScore isVerified');

  if (!item) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing item not found.' };
    return;
  }

  ctx.status = 200;
  ctx.body = formatListing(item);
});

router.put('/listings/:id', authenticateToken, async (ctx) => {
  const { id } = ctx.params;
  if (!mongoose.Types.ObjectId.isValid(id)) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing item not found.' };
    return;
  }

  const item = await Item.findById(id);
  if (!item || !['active', 'reserved'].includes(item.status)) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing item not found.' };
    return;
  }

  const currentOwnerId = item.sellerId?.toString() || item.ownerId;
  if (currentOwnerId !== ctx.state.user.id) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'You can only edit your own listing.' };
    return;
  }

  const { title, description, condition, category, priceNzd, location, negotiable, isSustainable } =
    ctx.request.body as any;
  const normalizedTitle = typeof title === 'string' ? title.trim() : '';
  const normalizedDescription = typeof description === 'string' ? description.trim() : '';
  const normalizedCategory = typeof category === 'string' ? category.trim() : '';
  const normalizedPrice = typeof priceNzd === 'string' ? priceNzd.trim() : '';
  const normalizedLocation = typeof location === 'string' ? location.trim() : '';
  const validConditions = ['new', 'like_new', 'good', 'fair', 'poor'];
  const priceValue = Number(normalizedPrice);

  if (
    normalizedTitle.length < 3 ||
    normalizedTitle.length > 100 ||
    normalizedDescription.length < 3 ||
    normalizedDescription.length > 2000 ||
    !normalizedCategory ||
    !validConditions.includes(condition) ||
    !/^\d+(\.\d{1,2})?$/.test(normalizedPrice) ||
    !Number.isFinite(priceValue) ||
    priceValue <= 0 ||
    !normalizedLocation ||
    typeof negotiable !== 'boolean' ||
    typeof isSustainable !== 'boolean'
  ) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Please provide valid listing details.' };
    return;
  }

  const locationParts = normalizedLocation.split(',').map((part: string) => part.trim()).filter(Boolean);
  const city = locationParts[locationParts.length - 1];
  const suburb = locationParts.length > 1 ? locationParts.slice(0, -1).join(', ') : '';

  item.title = normalizedTitle;
  item.description = normalizedDescription;
  item.condition = condition;
  item.category = normalizedCategory;
  item.price = Math.round(priceValue * 100);
  item.priceNzd = normalizedPrice;
  item.location = {
    city,
    suburb,
    coordinates: item.location?.coordinates
  };
  item.negotiable = negotiable;
  item.isSustainable = isSustainable;
  await item.save();
  await item.populate('sellerId', 'displayName avatarUrl rating reviewCount trustScore isVerified');

  ctx.status = 200;
  ctx.body = { status: 'updated', item: formatListing(item) };
});

router.delete('/listings/:id', authenticateToken, async (ctx) => {
  const { id } = ctx.params;
  if (!mongoose.Types.ObjectId.isValid(id)) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing item not found.' };
    return;
  }

  const item = await Item.findById(id);
  if (!item || !['active', 'reserved'].includes(item.status)) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Listing item not found.' };
    return;
  }

  const currentOwnerId = item.sellerId?.toString() || item.ownerId;
  if (currentOwnerId !== ctx.state.user.id) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'You can only delete your own listing.' };
    return;
  }

  item.status = 'deleted';
  item.deletedAt = new Date();
  await item.save();

  ctx.status = 200;
  ctx.body = { status: 'deleted', message: 'Listing deleted successfully.' };
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
