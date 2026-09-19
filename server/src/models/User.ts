import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
  email: string;
  phone?: string;
  passwordHash?: string;
  username?: string;
  displayName: string;
  avatarUrl: string | null;
  bio?: string;
  status: 'active' | 'suspended' | 'deleted';
  location?: {
    city?: string;
    suburb?: string;
    coordinates?: {
      type: 'Point';
      coordinates: number[]; // [longitude, latitude]
    };
  };
  stripeCustomerId?: string;
  stripeConnectedAccountId?: string;
  stripeAccountStatus: 'not_created' | 'pending' | 'active' | 'restricted';
  stripePayoutsEnabled: boolean;
  rating: number;
  reviewCount: number;
  lastLoginAt?: Date;
  deletedAt?: Date;

  // Compatibility fields for existing flow
  googleId?: string;
  trustScore: number;
  isVerified: boolean;
  isStudentVerified: boolean;
  studentInstitution?: string;
  studentIdNumber?: string;
  studentEmail?: string;
  isBanned?: boolean;
  authProvider: string;
  role: 'user' | 'admin';
  kiwiGold: number;
  isVip?: boolean;
  vipExpiresAt?: Date;
  vipAutoRenew?: boolean;
  notificationPreferences?: {
    watchlistPriceDrop: boolean;
  };
  registrationPlatform: 'web' | 'mobile_ios' | 'mobile_android' | 'mobile' | 'unknown';
  lastUsedPlatform: 'web' | 'mobile_ios' | 'mobile_android' | 'mobile' | 'unknown';
  lastActiveAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<IUser>(
  {
    email: { type: String, required: true, unique: true, index: true, lowercase: true, trim: true },
    phone: { type: String, unique: true, sparse: true },
    passwordHash: { type: String, select: false },
    username: { type: String, unique: true, sparse: true, lowercase: true, trim: true },
    displayName: { type: String, required: true },
    avatarUrl: { type: String, default: null },
    bio: { type: String, default: '', maxlength: 200 },
    status: { type: String, enum: ['active', 'suspended', 'deleted', 'banned'], default: 'active' },
    role: { type: String, enum: ['user', 'admin'], default: 'user' },
    kiwiGold: { type: Number, default: 100 },
    isVip: { type: Boolean, default: false },
    vipExpiresAt: { type: Date },
    vipAutoRenew: { type: Boolean, default: true },
    location: {
      city: { type: String },
      suburb: { type: String },
      coordinates: {
        type: { type: String, enum: ['Point'] },
        coordinates: { type: [Number] } // [longitude, latitude]
      }
    },
    stripeCustomerId: { type: String, unique: true, sparse: true },
    stripeConnectedAccountId: { type: String, unique: true, sparse: true },
    stripeAccountStatus: { type: String, enum: ['not_created', 'pending', 'active', 'restricted'], default: 'not_created' },
    stripePayoutsEnabled: { type: Boolean, default: false },
    rating: { type: Number, default: 0 },
    reviewCount: { type: Number, default: 0 },
    lastLoginAt: { type: Date },
    lastActiveAt: { type: Date },
    registrationPlatform: { 
      type: String, 
      enum: ['web', 'mobile_ios', 'mobile_android', 'mobile', 'unknown'], 
      default: 'unknown' 
    },
    lastUsedPlatform: { 
      type: String, 
      enum: ['web', 'mobile_ios', 'mobile_android', 'mobile', 'unknown'], 
      default: 'unknown' 
    },
    deletedAt: { type: Date },
    notificationPreferences: {
      watchlistPriceDrop: { type: Boolean, default: true }
    },

    // Compatibility fields
    googleId: { type: String, unique: true, sparse: true },
    trustScore: { type: Number, default: 100, min: 0 },
    isVerified: { type: Boolean, default: false },
    isStudentVerified: { type: Boolean, default: false },
    studentInstitution: { type: String, default: 'University of Auckland' },
    studentIdNumber: { type: String },
    studentEmail: { type: String },
    isBanned: { type: Boolean, default: false },
    authProvider: { type: String, required: true, default: 'email_otp' }
  },
  {
    timestamps: true
  }
);

// Geo index for coordinates mapping
UserSchema.index({ 'location.coordinates': '2dsphere' });

// Add virtual 'id' mapping to '_id' for backward compatibility
UserSchema.virtual('id').get(function (this: IUser) {
  return this._id.toString();
});
UserSchema.set('toJSON', { virtuals: true });
UserSchema.set('toObject', { virtuals: true });

export default mongoose.models.User || mongoose.model<IUser>('User', UserSchema);
