import mongoose, { Schema, Document } from 'mongoose';

export interface IMessage extends Document {
  conversationId: mongoose.Types.ObjectId;
  senderId: mongoose.Types.ObjectId;
  receiverId: mongoose.Types.ObjectId;
  type: 'text' | 'image' | 'location' | 'system';
  text?: string;
  imageUrl?: string;
  location?: {
    name?: string;
    latitude: number;
    longitude: number;
  };
  status: 'sent' | 'delivered' | 'read' | 'deleted';
  readAt?: Date;
  deletedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const MessageSchema = new Schema<IMessage>(
  {
    conversationId: { type: Schema.Types.ObjectId, ref: 'Conversation', required: true },
    senderId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    receiverId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, enum: ['text', 'image', 'location', 'system'], default: 'text' },
    text: { type: String },
    imageUrl: { type: String },
    location: {
      name: { type: String },
      latitude: { type: Number },
      longitude: { type: Number }
    },
    status: { type: String, enum: ['sent', 'delivered', 'read', 'deleted'], default: 'sent' },
    readAt: { type: Date },
    deletedAt: { type: Date }
  },
  {
    timestamps: true
  }
);

// Compound index for fast chat thread loading
MessageSchema.index({ conversationId: 1, createdAt: 1 });

MessageSchema.virtual('id').get(function (this: IMessage) {
  return this._id.toString();
});
MessageSchema.set('toJSON', { virtuals: true });
MessageSchema.set('toObject', { virtuals: true });

export default mongoose.models.Message || mongoose.model<IMessage>('Message', MessageSchema);
