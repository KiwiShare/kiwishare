import 'dotenv/config';
import app from './app';
import config from './config';
import connectDB from './config/db';
import { getJwtSecret } from './middleware/auth';

const PORT = config.get('port');
const HOST = config.get('host');
const MONGODB_URI = config.get('mongodb.uri');
const MONGODB_URI_TEST = config.get('mongodb.uriTest') || MONGODB_URI;

async function startServer() {
  try {
    // Validate authentication configuration before opening a database or
    // network listener. The secret itself is never logged.
    getJwtSecret();
    console.log('🔄 Connecting to MongoDB...');
    const connectionUri = config.get('env') === 'production' ? MONGODB_URI : MONGODB_URI_TEST;
    await connectDB(connectionUri);
    console.log('✅ Connected to MongoDB successfully.');

    app.listen(PORT, HOST, () => {
      console.log(`\n🚀 [KiwiShare Koa Server] Running on http://${HOST}:${PORT}`);
      console.log(`👋 Local: http://localhost:${PORT}/api/usedItems\n`);
    });
  } catch (error) {
    console.error('❌ Failed to start the server:', error);
    process.exit(1);
  }
}

if (config.get('env') !== 'test') {
  startServer();
}
