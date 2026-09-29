import bcrypt from 'bcryptjs';
import Category from '../models/Category';
import User from '../models/User';
import Item from '../models/Item';
import Order from '../models/Order';

export const DEFAULT_CATEGORIES = [
  { name: 'Furniture', slug: 'furniture', icon: 'Armchair', description: 'Chairs, desks, sofas, and home furnishings', sortOrder: 1 },
  { name: 'Electronics', slug: 'electronics', icon: 'Tv', description: 'Computers, screens, audio, and gadgets', sortOrder: 2 },
  { name: 'Books', slug: 'books', icon: 'BookOpen', description: 'Novels, textbooks, puzzles, and board games', sortOrder: 3 },
  { name: 'Home', slug: 'home', icon: 'House', description: 'Homeware, decor, and household essentials', sortOrder: 4 },
  { name: 'Sports', slug: 'sports', icon: 'Trophy', description: 'Bikes, surfboards, rackets, and fitness items', sortOrder: 5 },
  { name: 'Kids', slug: 'kids', icon: 'Baby', description: 'Toys, baby gear, and children items', sortOrder: 6 },
  { name: 'Fashion', slug: 'fashion', icon: 'Shirt', description: 'Clothing, shoes, bags, and accessories', sortOrder: 7 },
  { name: 'Cars & Vehicles', slug: 'cars-vehicles', icon: 'Car', description: 'Cars and road vehicles with vehicle-specific details', sortOrder: 8 },
  { name: 'Other', slug: 'other', icon: 'Package', description: 'Miscellaneous community treasures', sortOrder: 9 },
  // Legacy discovery categories are retained for existing listings.
  { name: 'Outdoor', slug: 'outdoor', icon: 'Tent', description: 'Camping, hiking, tents, and adventure gear', sortOrder: 20 },
  { name: 'Clothing', slug: 'clothing', icon: 'Shirt', description: 'Vintage, jackets, shoes, and apparel', sortOrder: 21 },
  { name: 'Tools', slug: 'tools', icon: 'Wrench', description: 'Power tools, hand tools, and DIY equipment', sortOrder: 22 },
  { name: 'Kitchen', slug: 'kitchen', icon: 'Utensils', description: 'Cookware, appliances, and dining essentials', sortOrder: 23 },
  { name: 'Plants', slug: 'plants', icon: 'Flower2', description: 'Indoor plants, cuttings, pots, and garden tools', sortOrder: 24 },
];

export async function seedDatabase() {
  try {
    // 1. Ensure all built-in Categories exist without overwriting admin edits.
    await Category.bulkWrite(
      DEFAULT_CATEGORIES.map((category) => ({
        updateOne: {
          filter: { slug: category.slug },
          update: { $setOnInsert: category },
          upsert: true
        }
      }))
    );

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

    // 5. Seed Demo Escrow Orders if Order collection is empty
    const orderCount = await Order.countDocuments();
    if (orderCount === 0) {
      console.log('🌱 [Seeding] Populating initial demo escrow orders in MongoDB...');
      const firstItem = await Item.findOne({ title: 'Retro Armchair' }) || await Item.findOne();
      const secondItem = await Item.findOne({ title: 'Used Specialized Mountain Bike' }) || firstItem;

      if (firstItem && moviegoerUser && adminUser) {
        const sampleOrders = [
          {
            orderNumber: 'KS-20260904-9821',
            itemId: firstItem._id,
            buyerId: adminUser._id,
            sellerId: moviegoerUser._id,
            status: 'completed',
            itemSnapshot: {
              title: firstItem.title,
              description: firstItem.description,
              condition: firstItem.condition,
              imageUrl: firstItem.imageUrl
            },
            currency: 'NZD',
            itemAmount: 6500,
            buyerFeeAmount: 325,
            sellerFeeAmount: 325,
            buyerTotalAmount: 6825,
            sellerReceiveAmount: 6175,
            paidAt: new Date(Date.now() - 24 * 3600 * 1000),
            completedAt: new Date(Date.now() - 2 * 3600 * 1000)
          },
          {
            orderNumber: 'KS-20260904-9844',
            itemId: secondItem ? secondItem._id : firstItem._id,
            buyerId: adminUser._id,
            sellerId: moviegoerUser._id,
            status: 'meeting_scheduled',
            itemSnapshot: {
              title: secondItem ? secondItem.title : firstItem.title,
              description: secondItem ? secondItem.description : firstItem.description,
              condition: secondItem ? secondItem.condition : firstItem.condition,
              imageUrl: secondItem ? secondItem.imageUrl : firstItem.imageUrl
            },
            currency: 'NZD',
            itemAmount: 28000,
            buyerFeeAmount: 1400,
            sellerFeeAmount: 1400,
            buyerTotalAmount: 29400,
            sellerReceiveAmount: 26600,
            paidAt: new Date(Date.now() - 6 * 3600 * 1000),
            meeting: {
              scheduledAt: new Date(Date.now() + 18 * 3600 * 1000),
              locationName: 'UOA General Library Ground Floor',
              latitude: -36.8523,
              longitude: 174.7691
            }
          }
        ];
        await Order.insertMany(sampleOrders);
        console.log(`✅ [Seeding] Inserted ${sampleOrders.length} initial demo escrow orders.`);
      }
    }
  } catch (error) {
    console.error('❌ [Seeding Error] Failed to seed initial database:', error);
  }
}

export default seedDatabase;
