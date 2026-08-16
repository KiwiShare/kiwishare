import 'dotenv/config';
import mongoose from 'mongoose';
import app from './app';
import Item from './models/Item';
import connectDB from './config/db';

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://REDACTED@/kiwishare';
const MONGODB_URI_TEST = process.env.MONGODB_URI_TEST || MONGODB_URI;

async function seedInitialData() {
  try {
    const count = await Item.countDocuments();
    if (count === 0) {
      console.log('🌱 Seeding initial database listings including dummy items...');
      await Item.create([
        {
          id: 'item_1',
          title: 'Retro Armchair',
          priceNzd: '45',
          price: 4500,
          currency: 'NZD',
          location: {
            city: 'Auckland',
            suburb: 'Central',
            coordinates: {
              type: 'Point',
              coordinates: [174.7633, -36.8485]
            }
          },
          imageUrl: 'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c',
          images: [{ url: 'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c', sortOrder: 0 }],
          isSustainable: true,
          category: 'Furniture',
          status: 'active',
          ownerId: 'user_sam',
          sellerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011')
        },
        {
          id: 'item_2',
          title: 'Monstera Deliciosa',
          priceNzd: '15',
          price: 1500,
          currency: 'NZD',
          location: {
            city: 'Wellington',
            suburb: 'Te Aro',
            coordinates: {
              type: 'Point',
              coordinates: [174.7762, -41.2865]
            }
          },
          imageUrl: 'https://images.unsplash.com/photo-1545241047-6083a3684587',
          images: [{ url: 'https://images.unsplash.com/photo-1545241047-6083a3684587', sortOrder: 0 }],
          isSustainable: true,
          category: 'Plants',
          status: 'active',
          ownerId: 'user_jenny',
          sellerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439012')
        },
        {
          id: 'item_3',
          title: 'Used Specialized Mountain Bike',
          priceNzd: '450',
          price: 45000,
          currency: 'NZD',
          location: {
            city: 'Auckland',
            suburb: 'Ponsonby',
            coordinates: {
              type: 'Point',
              coordinates: [174.7437, -36.8524]
            }
          },
          imageUrl: 'https://images.unsplash.com/photo-1485965120184-e220f721d03e',
          images: [{ url: 'https://images.unsplash.com/photo-1485965120184-e220f721d03e', sortOrder: 0 }],
          isSustainable: true,
          category: 'vehicle',
          condition: 'good',
          description: 'Specialized Rockhopper mountain bike in good condition. 29 inch wheels, minor scratches but rides perfectly.',
          status: 'active',
          ownerId: 'user_jack',
          sellerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439013')
        },
        {
          id: 'item_4',
          title: 'iPhone 13 Pro 128GB Gold',
          priceNzd: '890',
          price: 89000,
          currency: 'NZD',
          location: {
            city: 'Auckland',
            suburb: 'Newmarket',
            coordinates: {
              type: 'Point',
              coordinates: [174.7785, -36.8682]
            }
          },
          imageUrl: 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5',
          images: [{ url: 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5', sortOrder: 0 }],
          isSustainable: false,
          category: 'electronics',
          condition: 'like_new',
          description: 'Unlocked iPhone 13 Pro in pristine condition. Battery health is at 88%. Comes with a free screen protector and case.',
          status: 'active',
          ownerId: 'user_alice',
          sellerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439014')
        },
        {
          id: 'item_5',
          title: 'Vintage Leather Jacket',
          priceNzd: '120',
          price: 12000,
          currency: 'NZD',
          location: {
            city: 'Wellington',
            suburb: 'Te Aro',
            coordinates: {
              type: 'Point',
              coordinates: [174.7762, -41.2865]
            }
          },
          imageUrl: 'https://images.unsplash.com/photo-1551028719-00167b16eac5',
          images: [{ url: 'https://images.unsplash.com/photo-1551028719-00167b16eac5', sortOrder: 0 }],
          isSustainable: true,
          category: 'clothing',
          condition: 'good',
          description: 'Genuine brown leather jacket from the 90s. Heavy duty zippers, distressed look, very cool fit (size M).',
          status: 'active',
          ownerId: 'user_bob',
          sellerId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439015')
        }
      ]);
      console.log('✅ Seeding completed.');
    }
  } catch (error) {
    console.error('❌ Failed to seed initial data:', error);
  }
}

async function startServer() {
  try {
    console.log('🔄 Connecting to MongoDB...');
    const connectionUri = process.env.NODE_ENV === 'production' ? MONGODB_URI : MONGODB_URI_TEST;
    await connectDB(connectionUri);
    console.log('✅ Connected to MongoDB successfully.');

    // Seed data for clean local dev experience
    await seedInitialData();

    app.listen(PORT, HOST, () => {
      console.log(`\n🚀 [KiwiShare Koa Server] Running on http://${HOST}:${PORT}`);
      console.log(`👋 Local: http://localhost:${PORT}/api/listings\n`);
    });
  } catch (error) {
    console.error('❌ Failed to start the server:', error);
    process.exit(1);
  }
}

if (process.env.NODE_ENV !== 'test') {
  startServer();
}

export { seedInitialData };
