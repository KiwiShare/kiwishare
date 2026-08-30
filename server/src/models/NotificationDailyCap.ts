import mongoose, { Document, Schema } from 'mongoose';

export interface INotificationDailyCap extends Document {
  userId: mongoose.Types.ObjectId;
  dateKey: string; // 'YYYY-MM-DD' in Pacific/Auckland
  count: number;
  createdAt: Date;
  updatedAt: Date;
}

const NotificationDailyCapSchema = new Schema<INotificationDailyCap>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true
    },
    dateKey: {
      type: String,
      required: true
    },
    count: {
      type: Number,
      required: true,
      default: 0
    }
  },
  { timestamps: true }
);

// Compound unique index ensuring atomic rate limit tracking per user and calendar day
NotificationDailyCapSchema.index({ userId: 1, dateKey: 1 }, { unique: true });

export default mongoose.models.NotificationDailyCap ||
  mongoose.model<INotificationDailyCap>(
    'NotificationDailyCap',
    NotificationDailyCapSchema
  );
