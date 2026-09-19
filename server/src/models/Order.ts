import mongoose, { Schema, Document } from 'mongoose';

export interface IOrder extends Document {
  orderNumber: string;
  itemId: mongoose.Types.ObjectId;
  buyerId: mongoose.Types.ObjectId;
  sellerId: mongoose.Types.ObjectId;
  status:
    | 'pending_payment'
    | 'paid'
    | 'meeting_scheduled'
    | 'meeting_in_progress'
    | 'qr_scanned'
    | 'completed'
    | 'cancelled'
    | 'refund_pending'
    | 'refunded'
    | 'transfer_pending'
    | 'seller_paid'
    | 'disputed';
  itemSnapshot: {
    title: string;
    description?: string;
    condition?: string;
    imageUrl?: string;
  };
  currency: string;
  itemAmount: number; // in cents
  buyerFeeAmount: number; // in cents
  sellerFeeAmount: number; // in cents
  buyerTotalAmount: number; // in cents
  sellerReceiveAmount: number; // in cents
  paymentId?: mongoose.Types.ObjectId;
  refundId?: mongoose.Types.ObjectId;
  sellerTransferId?: mongoose.Types.ObjectId;
  meeting?: {
    scheduledAt?: Date;
    locationName?: string;
    latitude?: number;
    longitude?: number;
    proposedBy?: mongoose.Types.ObjectId;
    proposalStatus?: 'proposed' | 'confirmed' | 'declined' | 'cancelled';
    note?: string;
    buyerArrivedAt?: Date;
    sellerArrivedAt?: Date;
  };
  qrScannedAt?: Date;
  buyerConfirmedAt?: Date;
  sellerConfirmedAt?: Date;
  cancellation?: {
    cancelledBy?: mongoose.Types.ObjectId;
    reason?: string;
    cancelledAt?: Date;
  };
  paidAt?: Date;
  completedAt?: Date;
  completionCredit?: {
    pointsPerParticipant: number;
    awardedAt: Date;
  };
  refundedAt?: Date;
  sellerPaidAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const OrderSchema = new Schema<IOrder>(
  {
    orderNumber: { type: String, required: true, unique: true, index: true },
    itemId: { type: Schema.Types.ObjectId, ref: 'Item', required: true, index: true },
    buyerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    sellerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    status: {
      type: String,
      enum: [
        'pending_payment',
        'paid',
        'meeting_scheduled',
        'meeting_in_progress',
        'qr_scanned',
        'completed',
        'cancelled',
        'refund_pending',
        'refunded',
        'transfer_pending',
        'seller_paid',
        'disputed'
      ],
      required: true,
      index: true
    },
    itemSnapshot: {
      title: { type: String, required: true },
      description: { type: String },
      condition: { type: String },
      imageUrl: { type: String }
    },
    currency: { type: String, required: true, default: 'NZD' },
    itemAmount: { type: Number, required: true },
    buyerFeeAmount: { type: Number, default: 0 },
    sellerFeeAmount: { type: Number, default: 0 },
    buyerTotalAmount: { type: Number, required: true },
    sellerReceiveAmount: { type: Number, required: true },
    paymentId: { type: Schema.Types.ObjectId, ref: 'Payment', index: true },
    refundId: { type: Schema.Types.ObjectId, ref: 'Refund' },
    sellerTransferId: { type: Schema.Types.ObjectId, ref: 'SellerTransfer' },
    meeting: {
      scheduledAt: { type: Date },
      locationName: { type: String },
      latitude: { type: Number },
      longitude: { type: Number },
      proposedBy: { type: Schema.Types.ObjectId, ref: 'User' },
      proposalStatus: {
        type: String,
        enum: ['proposed', 'confirmed', 'declined', 'cancelled'],
        default: 'proposed'
      },
      note: { type: String },
      buyerArrivedAt: { type: Date },
      sellerArrivedAt: { type: Date }
    },
    qrScannedAt: { type: Date },
    buyerConfirmedAt: { type: Date },
    sellerConfirmedAt: { type: Date },
    cancellation: {
      cancelledBy: { type: Schema.Types.ObjectId, ref: 'User' },
      reason: { type: String },
      cancelledAt: { type: Date }
    },
    paidAt: { type: Date },
    completedAt: { type: Date },
    completionCredit: {
      pointsPerParticipant: { type: Number, min: 0 },
      awardedAt: { type: Date }
    },
    refundedAt: { type: Date },
    sellerPaidAt: { type: Date }
  },
  {
    timestamps: true
  }
);

OrderSchema.index({ buyerId: 1, createdAt: -1 });
OrderSchema.index({ sellerId: 1, createdAt: -1 });

OrderSchema.virtual('id').get(function (this: IOrder) {
  return this._id.toString();
});
OrderSchema.set('toJSON', { virtuals: true });
OrderSchema.set('toObject', { virtuals: true });

export default mongoose.models.Order || mongoose.model<IOrder>('Order', OrderSchema);
