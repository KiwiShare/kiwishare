import mongoose, { Schema, Document } from 'mongoose';

export interface IWatchlist extends Document {
  userId: mongoose.Types.ObjectId;
  itemId: mongoose.Types.ObjectId;
  createdAt: Date;
  updatedAt: Date;
}

const WatchlistSchema = new Schema<IWatchlist>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    itemId: {
      type: Schema.Types.ObjectId,
      ref: 'Item',
      required: true,
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

// Compound unique index ensuring a user can only watch an item once
WatchlistSchema.index({ userId: 1, itemId: 1 }, { unique: true });

WatchlistSchema.virtual('id').get(function (this: IWatchlist) {
  return this._id.toString();
});

WatchlistSchema.set('toJSON', { virtuals: true });
WatchlistSchema.set('toObject', { virtuals: true });

export default mongoose.models.Watchlist || mongoose.model<IWatchlist>('Watchlist', WatchlistSchema);
