import mongoose, { Schema, Document } from 'mongoose';

export interface IItem extends Document {
  id: string; // uuid
  title: string;
  priceNzd: string;
  location: string;
  imageUrl: string;
  isSustainable: boolean;
  category: string;
  status: 'active' | 'reserved' | 'sold';
  ownerId: string; // references User.id string
  createdAt: Date;
}

const ItemSchema = new Schema<IItem>({
  id: { type: String, required: true, unique: true, index: true },
  title: { type: String, required: true },
  priceNzd: { type: String, required: true },
  location: { type: String, required: true },
  imageUrl: { type: String, required: true },
  isSustainable: { type: Boolean, required: true },
  category: { type: String, required: true },
  status: { type: String, enum: ['active', 'reserved', 'sold'], default: 'active' },
  ownerId: { type: String, required: true, index: true },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.models.Item || mongoose.model<IItem>('Item', ItemSchema);
