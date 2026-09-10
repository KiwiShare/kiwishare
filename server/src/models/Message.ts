import mongoose, { Schema, Document } from 'mongoose';

export interface IMessage extends Document {
  conversationId: mongoose.Types.ObjectId;
  senderId: mongoose.Types.ObjectId;
  receiverId: mongoose.Types.ObjectId;
  type: 'text' | 'image' | 'voice' | 'location' | 'meetup' | 'system';
  text?: string;
  imageUrl?: string;
  audioUrl?: string;
  durationMs?: number;
  location?: {
    name?: string;
    latitude: number;
    longitude: number;
  };
  meetup?: {
    orderId?: mongoose.Types.ObjectId;
    scheduledAt?: Date;
    locationName?: string;
    latitude?: number;
    longitude?: number;
    proposalStatus?: 'proposed' | 'confirmed' | 'declined' | 'cancelled';
    proposedBy?: mongoose.Types.ObjectId;
    note?: string;
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
    type: { type: String, enum: ['text', 'image', 'voice', 'location', 'meetup', 'system'], default: 'text' },
    text: { type: String },
    imageUrl: { type: String },
    audioUrl: { type: String },
    durationMs: { type: Number, min: 1, max: 60000 },
    location: {
      name: { type: String },
      latitude: { type: Number },
      longitude: { type: Number }
    },
    meetup: {
      orderId: { type: Schema.Types.ObjectId, ref: 'Order' },
      scheduledAt: { type: Date },
      locationName: { type: String },
      latitude: { type: Number },
      longitude: { type: Number },
      proposalStatus: {
        type: String,
        enum: ['proposed', 'confirmed', 'declined', 'cancelled'],
        default: 'proposed'
      },
      proposedBy: { type: Schema.Types.ObjectId, ref: 'User' },
      note: { type: String }
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
