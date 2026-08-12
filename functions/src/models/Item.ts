import mongoose, { Schema, Document } from 'mongoose';

export interface IItem extends Document {
  sellerId: mongoose.Types.ObjectId;
  title: string;
  description?: string;
  category: string;
  condition?: 'new' | 'like_new' | 'good' | 'fair' | 'poor';
  price: number; // in cents
  currency: string;
  negotiable: boolean;
  images: Array<{
    url: string;
    thumbnailUrl?: string;
    sortOrder: number;
  }>;
  location?: {
    city?: string;
    suburb?: string;
    coordinates?: {
      type: 'Point';
      coordinates: number[]; // [longitude, latitude]
    };
  };
  status: 'draft' | 'active' | 'reserved' | 'sold' | 'hidden' | 'deleted';
  reservedOrderId?: mongoose.Types.ObjectId;
  publishedAt?: Date;
  soldAt?: Date;
  viewCount: number;
  favouriteCount: number;
  deletedAt?: Date;

  // Compatibility fields
  imageUrl: string;
  priceNzd: string;
  isSustainable: boolean;
  ownerId: string; // User ID string
  createdAt: Date;
  updatedAt: Date;
}

const ItemSchema = new Schema<IItem>(
  {
    sellerId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    title: { type: String, required: true },
    description: { type: String },
    category: { type: String, required: true, index: true },
    condition: { type: String, enum: ['new', 'like_new', 'good', 'fair', 'poor'] },
    price: { type: Number, required: true }, // cents
    currency: { type: String, required: true, default: 'NZD' },
    negotiable: { type: Boolean, default: false },
    images: [
      {
        url: { type: String, required: true },
        thumbnailUrl: { type: String },
        sortOrder: { type: Number, default: 0 }
      }
    ],
    location: {
      city: { type: String },
      suburb: { type: String },
      coordinates: {
        type: { type: String, enum: ['Point'] },
        coordinates: { type: [Number] } // [longitude, latitude]
      }
    },
    status: {
      type: String,
      enum: ['draft', 'active', 'reserved', 'sold', 'hidden', 'deleted'],
      default: 'active',
      index: true
    },
    reservedOrderId: { type: Schema.Types.ObjectId, ref: 'Order' },
    publishedAt: { type: Date, default: Date.now },
    soldAt: { type: Date },
    viewCount: { type: Number, default: 0 },
    favouriteCount: { type: Number, default: 0 },
    deletedAt: { type: Date },

    // Compatibility fields
    imageUrl: { type: String },
    priceNzd: { type: String },
    isSustainable: { type: Boolean, default: false },
    ownerId: { type: String, index: true }
  },
  {
    timestamps: true
  }
);

// Indexes
ItemSchema.index({ 'location.coordinates': '2dsphere' });
ItemSchema.index({ createdAt: -1 });

ItemSchema.virtual('id').get(function (this: IItem) {
  return this._id.toString();
});
ItemSchema.set('toJSON', { virtuals: true });
ItemSchema.set('toObject', { virtuals: true });

export default mongoose.models.Item || mongoose.model<IItem>('Item', ItemSchema);
