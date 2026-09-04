import mongoose from 'mongoose';

const connectDB = async (uri: string) => {
  try {
    const conn = await mongoose.connect(uri);
    console.log(`📡 MongoDB Connected to database: ${conn.connection.name} on host: ${conn.connection.host}`);
    return conn;
  } catch (err) {
    console.error('❌ Error connecting to MongoDB:', err);
    // Exit process so orchestration (Cloud Run/Docker/etc.) can restart the container
    process.exit(1);
  }
};

export default connectDB;
