import 'dotenv/config';
import mongoose from 'mongoose';
import app from './app';
import Item from './models/Item';

const PORT = process.env.PORT || 3000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://REDACTED@/kiwishare';

async function seedInitialData() {
  try {
    const count = await Item.countDocuments();
    if (count === 0) {
      console.log('🌱 Seeding initial database listings...');
      await Item.create([
        {
          id: 'item_1',
          title: 'Retro Armchair',
          priceNzd: '45',
          location: 'Auckland',
          imageUrl: 'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c',
          isSustainable: true,
          category: 'Furniture',
          status: 'active',
          ownerId: 'user_sam'
        },
        {
          id: 'item_2',
          title: 'Monstera Deliciosa',
          priceNzd: '15',
          location: 'Wellington',
          imageUrl: 'https://images.unsplash.com/photo-1545241047-6083a3684587',
          isSustainable: true,
          category: 'Plants',
          status: 'active',
          ownerId: 'user_jenny'
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
    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB successfully.');

    // Seed data for clean local dev experience
    await seedInitialData();

    app.listen(PORT, () => {
      console.log(`\n🚀 [KiwiShare Koa Server] Running locally on http://localhost:${PORT}`);
      console.log(`👋 Development endpoints: http://localhost:${PORT}/api/listings\n`);
    });
  } catch (error) {
    console.error('❌ Failed to start the server:', error);
    process.exit(1);
  }
}

if (process.env.NODE_ENV !== 'test') {
  startServer();
}

export { seedInitialData }; // Export for test runner reuse
