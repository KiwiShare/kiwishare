import mongoose, { Document, Schema } from 'mongoose';

export type PushPlatform = 'android' | 'ios';

export interface IPushDevice extends Document {
  userId: mongoose.Types.ObjectId;
  token: string;
  platform: PushPlatform;
  lastSeenAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

const PushDeviceSchema = new Schema<IPushDevice>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    token: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      select: false
    },
    platform: {
      type: String,
      enum: ['android', 'ios'],
      required: true
    },
    lastSeenAt: { type: Date, required: true, default: Date.now }
  },
  { timestamps: true }
);

PushDeviceSchema.index({ userId: 1, platform: 1 });

export default mongoose.models.PushDevice ||
  mongoose.model<IPushDevice>('PushDevice', PushDeviceSchema);
