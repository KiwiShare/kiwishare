import mongoose, { Schema, Document } from 'mongoose';

export interface IConversation extends Document {
  itemId: mongoose.Types.ObjectId;
  orderId?: mongoose.Types.ObjectId;
  buyerId: mongoose.Types.ObjectId;
  sellerId: mongoose.Types.ObjectId;
  status: 'active' | 'closed' | 'blocked';
  lastMessageText?: string;
  lastMessageAt?: Date;
  lastMessageSenderId?: mongoose.Types.ObjectId;
  buyerUnreadCount: number;
  sellerUnreadCount: number;
  hiddenForUserIds: mongoose.Types.ObjectId[];
  createdAt: Date;
  updatedAt: Date;
}

const ConversationSchema = new Schema<IConversation>(
  {
    itemId: { type: Schema.Types.ObjectId, ref: 'Item', required: true, index: true },
    orderId: { type: Schema.Types.ObjectId, ref: 'Order', index: true },
    buyerId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    sellerId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    status: { type: String, enum: ['active', 'closed', 'blocked'], default: 'active' },
    lastMessageText: { type: String },
    lastMessageAt: { type: Date, index: true },
    lastMessageSenderId: { type: Schema.Types.ObjectId, ref: 'User' },
    buyerUnreadCount: { type: Number, default: 0 },
    sellerUnreadCount: { type: Number, default: 0 },
    hiddenForUserIds: [{ type: Schema.Types.ObjectId, ref: 'User' }]
  },
  {
    timestamps: true
  }
);

// Avoid duplicate chats for same user-item combination
ConversationSchema.index({ itemId: 1, buyerId: 1, sellerId: 1 }, { unique: true });
ConversationSchema.index({ buyerId: 1, lastMessageAt: -1, updatedAt: -1 });
ConversationSchema.index({ sellerId: 1, lastMessageAt: -1, updatedAt: -1 });

ConversationSchema.virtual('id').get(function (this: IConversation) {
  return this._id.toString();
});
ConversationSchema.set('toJSON', { virtuals: true });
ConversationSchema.set('toObject', { virtuals: true });

export default mongoose.models.Conversation || mongoose.model<IConversation>('Conversation', ConversationSchema);
