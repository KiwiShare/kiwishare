import Router from 'koa-router';
import Category from '../models/Category';
import Item from '../models/Item';
import { authenticateToken } from '../middleware/auth';

const router = new Router();

// GET /api/categories - List all active categories with live item counts
router.get('/categories', async (ctx) => {
  const includeInactive = ctx.query.includeInactive === 'true';
  const filter = includeInactive ? {} : { isActive: true };

  const categories = await Category.find(filter).sort({ sortOrder: 1, name: 1 });

  // Compute item count per category
  const counts = await Item.aggregate([
    { $match: { status: 'active' } },
    { $group: { _id: '$category', count: { $sum: 1 } } }
  ]);

  const countMap = new Map<string, number>();
  counts.forEach((c: any) => {
    if (c._id) {
      countMap.set(c._id.toLowerCase(), c.count);
    }
  });

  const enrichedCategories = categories.map((cat) => {
    const json = cat.toJSON();
    json.itemCount = countMap.get(cat.name.toLowerCase()) || countMap.get(cat.slug.toLowerCase()) || 0;
    return json;
  });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    count: enrichedCategories.length,
    categories: enrichedCategories
  };
});

// POST /api/categories - Create a new category
router.post('/categories', authenticateToken, async (ctx) => {
  const { name, slug, icon, description, sortOrder } = ctx.request.body as any;

  if (!name) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Category name is required.' };
    return;
  }

  const generatedSlug = (slug || name).toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');

  const existing = await Category.findOne({ slug: generatedSlug });
  if (existing) {
    ctx.status = 409;
    ctx.body = { status: 'error', message: `Category with slug '${generatedSlug}' already exists.` };
    return;
  }

  const newCat = await Category.create({
    name: name.trim(),
    slug: generatedSlug,
    icon: icon || 'Package',
    description: description || '',
    sortOrder: typeof sortOrder === 'number' ? sortOrder : 0,
    isActive: true
  });

  ctx.status = 201;
  ctx.body = {
    status: 'success',
    category: newCat
  };
});

// PATCH /api/categories/:id - Update an existing category
router.patch('/categories/:id', authenticateToken, async (ctx) => {
  const { id } = ctx.params;
  const { name, icon, description, sortOrder, isActive } = ctx.request.body as any;

  const category = await Category.findById(id);
  if (!category) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Category not found.' };
    return;
  }

  if (name !== undefined) category.name = name.trim();
  if (icon !== undefined) category.icon = icon;
  if (description !== undefined) category.description = description;
  if (sortOrder !== undefined) category.sortOrder = sortOrder;
  if (isActive !== undefined) category.isActive = isActive;

  await category.save();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    category
  };
});

// DELETE /api/categories/:id - Delete a category
router.delete('/categories/:id', authenticateToken, async (ctx) => {
  const { id } = ctx.params;

  const category = await Category.findById(id);
  if (!category) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Category not found.' };
    return;
  }

  await Category.findByIdAndDelete(id);

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    message: 'Category deleted successfully.'
  };
});

export default router;
