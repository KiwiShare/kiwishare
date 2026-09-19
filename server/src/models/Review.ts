import mongoose, { Schema, Document } from 'mongoose';

export interface IReview extends Document {
  orderId?: mongoose.Types.ObjectId;
  itemId?: mongoose.Types.ObjectId;
  reviewerId: mongoose.Types.ObjectId;
  targetUserId: mongoose.Types.ObjectId;
  role: 'buyer' | 'seller';
  rating: number; // 1 - 5
  comment: string;
  tags: string[];
  itemSnapshot?: {
    title: string;
    imageUrl?: string;
    price?: number;
  };
  createdAt: Date;
  updatedAt: Date;
}

const ReviewSchema = new Schema<IReview>(
  {
    orderId: { type: Schema.Types.ObjectId, ref: 'Order', index: true },
    itemId: { type: Schema.Types.ObjectId, ref: 'Item', index: true },
    reviewerId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    targetUserId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    role: { type: String, enum: ['buyer', 'seller'], required: true },
    rating: { type: Number, required: true, min: 1, max: 5 },
    comment: { type: String, required: true, trim: true, maxlength: 1000 },
    tags: [{ type: String, trim: true }],
    itemSnapshot: {
      title: { type: String },
      imageUrl: { type: String },
      price: { type: Number }
    }
  },
  {
    timestamps: true
  }
);

ReviewSchema.index({ targetUserId: 1, createdAt: -1 });

export default mongoose.models.Review || mongoose.model<IReview>('Review', ReviewSchema);
