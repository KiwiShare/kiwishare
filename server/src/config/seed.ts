import bcrypt from 'bcryptjs';
import Category from '../models/Category';
import User from '../models/User';
import Item from '../models/Item';

export const DEFAULT_CATEGORIES = [
  { name: 'Furniture', slug: 'furniture', icon: 'Armchair', description: 'Chairs, desks, sofas, and home furnishings', sortOrder: 1 },
  { name: 'Electronics', slug: 'electronics', icon: 'Tv', description: 'Computers, screens, audio, and gadgets', sortOrder: 2 },
  { name: 'Outdoor', slug: 'outdoor', icon: 'Tent', description: 'Camping, hiking, tents, and adventure gear', sortOrder: 3 },
  { name: 'Clothing', slug: 'clothing', icon: 'Shirt', description: 'Vintage, jackets, shoes, and apparel', sortOrder: 4 },
  { name: 'Tools', slug: 'tools', icon: 'Wrench', description: 'Power tools, hand tools, and DIY equipment', sortOrder: 5 },
  { name: 'Kitchen', slug: 'kitchen', icon: 'Utensils', description: 'Cookware, appliances, and dining essentials', sortOrder: 6 },
  { name: 'Plants', slug: 'plants', icon: 'Flower2', description: 'Indoor plants, cuttings, pots, and garden tools', sortOrder: 7 },
  { name: 'Sports', slug: 'sports', icon: 'Trophy', description: 'Bikes, surfboards, rackets, and fitness items', sortOrder: 8 },
  { name: 'Books', slug: 'books', icon: 'BookOpen', description: 'Novels, textbooks, puzzles, and board games', sortOrder: 9 },
  { name: 'Other', slug: 'other', icon: 'Package', description: 'Miscellaneous community treasures', sortOrder: 10 },
];

export async function seedDatabase() {
  try {
    // 1. Seed Categories if empty
    const categoryCount = await Category.countDocuments();
    if (categoryCount === 0) {
      console.log('🌱 [Seeding] Populating default Categories in MongoDB...');
      await Category.insertMany(DEFAULT_CATEGORIES);
      console.log(`✅ [Seeding] Inserted ${DEFAULT_CATEGORIES.length} default categories.`);
    }

    // 2. Seed Default Admin User if not present
    const adminEmail = 'admin@kiwishare.online';
    let adminUser = await User.findOne({ email: adminEmail });
    if (!adminUser) {
      console.log(`🌱 [Seeding] Creating default Admin account (${adminEmail})...`);
      const passwordHash = await bcrypt.hash('password123', 12);
      adminUser = await User.create({
        email: adminEmail,
        displayName: 'Kiwi Admin',
        role: 'admin',
        trustScore: 100,
        isVerified: true,
        authProvider: 'email_password',
        registrationPlatform: 'web',
        lastUsedPlatform: 'web',
        passwordHash
      });
      console.log(`✅ [Seeding] Admin account created: ${adminEmail} / password123`);
    } else if (adminUser.role !== 'admin') {
      adminUser.role = 'admin';
      await adminUser.save();
    }

    // 3. Ensure User demo@example.com exists with verified student credentials
    const targetEmail = 'demo@example.com';
    let moviegoerUser = await User.findOne({ email: targetEmail });
    if (!moviegoerUser) {
      console.log(`🌱 [Seeding] Creating user account (${targetEmail})...`);
      const passwordHash = await bcrypt.hash('password123', 12);
      moviegoerUser = await User.create({
        email: targetEmail,
        displayName: 'MovieGoer24',
        role: 'user',
        trustScore: 100,
        isVerified: true,
        isStudentVerified: true,
        studentInstitution: 'University of Auckland',
        studentIdNumber: 'UOA-734-2026',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
        authProvider: 'email_password',
        registrationPlatform: 'web',
        lastUsedPlatform: 'web',
        passwordHash
      });
      console.log(`✅ [Seeding] User account created: ${targetEmail}`);
    }

    // 4. Seed Demo Pre-Loved Items if collection is empty
    const itemCount = await Item.countDocuments();
    if (itemCount === 0) {
      console.log('🌱 [Seeding] Populating initial community used items in MongoDB...');
      const demoSellerId = moviegoerUser._id;

      const sampleItems = [
        {
          sellerId: demoSellerId,
          ownerId: demoSellerId.toString(),
          title: 'Retro Velvet Armchair',
          description: 'Solid timber frame vintage armchair in forest green velvet. Extremely comfortable, well-cared for in a smoke-free home in Ponsonby.',
          category: 'Furniture',
          condition: 'good',
          price: 6500,
          priceNzd: '65',
          currency: 'NZD',
          status: 'active',
          isSustainable: true,
          imageUrl: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&auto=format&fit=crop&q=80',
          images: [{ url: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
          location: {
            city: 'Auckland',
            suburb: 'Ponsonby',
            coordinates: { type: 'Point', coordinates: [174.7431, -36.8532] }
          }
        },
        {
          sellerId: demoSellerId,
          ownerId: demoSellerId.toString(),
          title: 'Monstera Deliciosa (Swiss Cheese Plant)',
          description: 'Healthy and thriving indoor plant with large fenestrated leaves. Comes in a stylish terracotta pot.',
          category: 'Plants',
          condition: 'like_new',
          price: 2500,
          priceNzd: '25',
          currency: 'NZD',
          status: 'active',
          isSustainable: true,
          imageUrl: 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=800&auto=format&fit=crop&q=80',
          images: [{ url: 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
          location: {
            city: 'Wellington',
            suburb: 'Te Aro',
            coordinates: { type: 'Point', coordinates: [174.7762, -41.2865] }
          }
        },
        {
          sellerId: demoSellerId,
          ownerId: demoSellerId.toString(),
          title: 'Dell 27-inch 4K USB-C Monitor',
          description: 'UltraSharp 4K IPS display. USB-C 90W power delivery, HDMI, DisplayPort. Perfect for home office or study.',
          category: 'Electronics',
          condition: 'like_new',
          price: 28000,
          priceNzd: '280',
          currency: 'NZD',
          status: 'active',
          isSustainable: false,
          imageUrl: 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800&auto=format&fit=crop&q=80',
          images: [{ url: 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
          location: {
            city: 'Auckland',
            suburb: 'CBD',
            coordinates: { type: 'Point', coordinates: [174.7633, -36.8485] }
          }
        },
        {
          sellerId: demoSellerId,
          ownerId: demoSellerId.toString(),
          title: 'Macpac 3-Person Waterproof Tent',
          description: 'Rugged lightweight hiking and camping tent with aluminum poles. Used only twice on the Abel Tasman track.',
          category: 'Outdoor',
          condition: 'good',
          price: 12000,
          priceNzd: '120',
          currency: 'NZD',
          status: 'active',
          isSustainable: true,
          imageUrl: 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&auto=format&fit=crop&q=80',
          images: [{ url: 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
          location: {
            city: 'Christchurch',
            suburb: 'Riccarton',
            coordinates: { type: 'Point', coordinates: [172.5855, -43.5321] }
          }
        },
        {
          sellerId: demoSellerId,
          ownerId: demoSellerId.toString(),
          title: 'Makita 18V Cordless Drill & Driver Kit',
          description: 'Brushless drill with 2x 3.0Ah Li-ion batteries, fast charger, and heavy duty carry case.',
          category: 'Tools',
          condition: 'good',
          price: 9500,
          priceNzd: '95',
          currency: 'NZD',
          status: 'active',
          isSustainable: true,
          imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&auto=format&fit=crop&q=80',
          images: [{ url: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
          location: {
            city: 'Hamilton',
            suburb: 'Frankton',
            coordinates: { type: 'Point', coordinates: [175.2575, -37.7870] }
          }
        },
        {
          sellerId: demoSellerId,
          ownerId: demoSellerId.toString(),
          title: 'Cast Iron Enamelled Dutch Oven (5.5L)',
          description: 'Heavy duty round casserole pot, excellent heat retention for sourdough bread and stews. Cherry red.',
          category: 'Kitchen',
          condition: 'good',
          price: 4500,
          priceNzd: '45',
          currency: 'NZD',
          status: 'active',
          isSustainable: true,
          imageUrl: 'https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?w=800&auto=format&fit=crop&q=80',
          images: [{ url: 'https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
          location: {
            city: 'Auckland',
            suburb: 'Takapuna',
            coordinates: { type: 'Point', coordinates: [174.7738, -36.7879] }
          }
        }
      ];

      await Item.insertMany(sampleItems);
      console.log(`✅ [Seeding] Inserted ${sampleItems.length} demo community items.`);
    }
  } catch (error) {
    console.error('❌ [Seeding Error] Failed to seed initial database:', error);
  }
}

export default seedDatabase;
