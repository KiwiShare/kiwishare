import 'dotenv/config';
import app from './app';
import connectDB from './config/db';
import seedDatabase from './config/seed';

const PORT = Number(process.env.PORT) || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://REDACTED@/kiwishare';
const MONGODB_URI_TEST = process.env.MONGODB_URI_TEST || MONGODB_URI;

async function startServer() {
  try {
    console.log('🔄 Connecting to MongoDB...');
    const connectionUri = process.env.NODE_ENV === 'production' ? MONGODB_URI : MONGODB_URI_TEST;
    await connectDB(connectionUri);
    console.log('✅ Connected to MongoDB successfully.');

    // Seed default categories, admin user, and sample items if empty
    await seedDatabase();

    app.listen(PORT, HOST, () => {
      console.log(`\n🚀 [KiwiShare Koa Server] Running on http://${HOST}:${PORT}`);
      console.log(`👋 Local: http://localhost:${PORT}/api/usedItems\n`);
    });
  } catch (error) {
    console.error('❌ Failed to start the server:', error);
    process.exit(1);
  }
}

if (process.env.NODE_ENV !== 'test') {
  startServer();
}
