import mongoose, { Document, Schema } from 'mongoose';

export type NotificationStatus =
  | 'processing'
  | 'sent'
  | 'rate_limited'
  | 'opted_out'
  | 'no_devices'
  | 'failed';

export interface INotificationHistory extends Document {
  userId: mongoose.Types.ObjectId;
  itemId: mongoose.Types.ObjectId;
  type: string; // e.g. 'watchlist_price_drop'
  eventId: string; // stable price change event ID
  oldPriceNzd: string;
  newPriceNzd: string;
  oldPriceCents: number;
  newPriceCents: number;
  status: NotificationStatus;
  failureReason?: string;
  deviceCount: number;
  successfulDeviceCount: number;
  failedDeviceCount: number;
  createdAt: Date;
  updatedAt: Date;
}

const NotificationHistorySchema = new Schema<INotificationHistory>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    itemId: {
      type: Schema.Types.ObjectId,
      ref: 'Item',
      required: true,
      index: true
    },
    type: {
      type: String,
      required: true,
      default: 'watchlist_price_drop',
      index: true
    },
    eventId: {
      type: String,
      required: true
    },
    oldPriceNzd: {
      type: String,
      required: true
    },
    newPriceNzd: {
      type: String,
      required: true
    },
    oldPriceCents: {
      type: Number,
      required: true
    },
    newPriceCents: {
      type: Number,
      required: true
    },
    status: {
      type: String,
      enum: [
        'processing',
        'sent',
        'rate_limited',
        'opted_out',
        'no_devices',
        'failed'
      ],
      required: true,
      index: true
    },
    failureReason: {
      type: String
    },
    deviceCount: {
      type: Number,
      default: 0
    },
    successfulDeviceCount: {
      type: Number,
      default: 0
    },
    failedDeviceCount: {
      type: Number,
      default: 0
    }
  },
  { timestamps: true }
);

// Event-level idempotency: a user cannot receive the exact same price-change event twice
NotificationHistorySchema.index(
  { userId: 1, type: 1, eventId: 1 },
  { unique: true }
);

export default mongoose.models.NotificationHistory ||
  mongoose.model<INotificationHistory>(
    'NotificationHistory',
    NotificationHistorySchema
  );
