import mongoose, { Schema, Document } from 'mongoose';

export interface ISellerTransfer extends Document {
  orderId: mongoose.Types.ObjectId;
  paymentId: mongoose.Types.ObjectId;
  sellerId: mongoose.Types.ObjectId;
  stripeConnectedAccountId: string;
  stripeTransferId?: string;
  amount: number; // cents
  currency: string;
  platformFeeAmount: number; // cents
  status: 'pending' | 'processing' | 'succeeded' | 'failed' | 'reversed';
  failureCode?: string;
  failureMessage?: string;
  idempotencyKey: string;
  transferredAt?: Date;
  reversedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const SellerTransferSchema = new Schema<ISellerTransfer>(
  {
    orderId: { type: Schema.Types.ObjectId, ref: 'Order', required: true, unique: true, index: true },
    paymentId: { type: Schema.Types.ObjectId, ref: 'Payment', required: true },
    sellerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    stripeConnectedAccountId: { type: String, required: true },
    stripeTransferId: { type: String, unique: true, sparse: true },
    amount: { type: Number, required: true },
    currency: { type: String, required: true, default: 'NZD' },
    platformFeeAmount: { type: Number, required: true, default: 0 },
    status: {
      type: String,
      enum: ['pending', 'processing', 'succeeded', 'failed', 'reversed'],
      default: 'pending'
    },
    failureCode: { type: String },
    failureMessage: { type: String },
    idempotencyKey: { type: String, required: true, unique: true },
    transferredAt: { type: Date },
    reversedAt: { type: Date }
  },
  {
    timestamps: true
  }
);

SellerTransferSchema.index({ sellerId: 1, createdAt: -1 });

SellerTransferSchema.virtual('id').get(function (this: ISellerTransfer) {
  return this._id.toString();
});
SellerTransferSchema.set('toJSON', { virtuals: true });
SellerTransferSchema.set('toObject', { virtuals: true });

export default mongoose.models.SellerTransfer || mongoose.model<ISellerTransfer>('SellerTransfer', SellerTransferSchema);
