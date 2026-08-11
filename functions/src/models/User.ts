import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
  id: string; // Custom string identifier (e.g. uid_123 or google_uid_123)
  email: string;
  displayName: string;
  avatarUrl: string | null;
  trustScore: number;
  isVerified: boolean;
  authProvider: string;
  hashedPassword?: string;
  createdAt: Date;
}

const UserSchema = new Schema<IUser>({
  id: { type: String, required: true, unique: true, index: true },
  email: { type: String, required: true, unique: true, index: true, lowercase: true, trim: true },
  displayName: { type: String, required: true },
  avatarUrl: { type: String, default: null },
  trustScore: { type: Number, default: 100 },
  isVerified: { type: Boolean, default: false },
  authProvider: { type: String, required: true, default: 'email_otp' },
  hashedPassword: { type: String, select: false },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.models.User || mongoose.model<IUser>('User', UserSchema);
