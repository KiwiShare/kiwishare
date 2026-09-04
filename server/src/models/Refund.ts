import mongoose, { Schema, Document } from 'mongoose';

export interface IRefund extends Document {
  orderId: mongoose.Types.ObjectId;
  paymentId: mongoose.Types.ObjectId;
  requestedByUserId: mongoose.Types.ObjectId;
  reason:
    | 'buyer_cancelled'
    | 'seller_cancelled'
    | 'item_not_as_described'
    | 'buyer_no_show'
    | 'seller_no_show'
    | 'agreed_cancellation'
    | 'admin_decision';
  amount: number; // cents
  currency: string;
  status: 'pending' | 'processing' | 'succeeded' | 'failed' | 'cancelled';
  stripeRefundId?: string;
  idempotencyKey: string;
  failureCode?: string;
  failureMessage?: string;
  processedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const RefundSchema = new Schema<IRefund>(
  {
    orderId: { type: Schema.Types.ObjectId, ref: 'Order', required: true, index: true },
    paymentId: { type: Schema.Types.ObjectId, ref: 'Payment', required: true, index: true },
    requestedByUserId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reason: {
      type: String,
      enum: [
        'buyer_cancelled',
        'seller_cancelled',
        'item_not_as_described',
        'buyer_no_show',
        'seller_no_show',
        'agreed_cancellation',
        'admin_decision'
      ],
      required: true
    },
    amount: { type: Number, required: true },
    currency: { type: String, required: true, default: 'NZD' },
    status: {
      type: String,
      enum: ['pending', 'processing', 'succeeded', 'failed', 'cancelled'],
      default: 'pending'
    },
    stripeRefundId: { type: String, unique: true, sparse: true },
    idempotencyKey: { type: String, required: true, unique: true },
    failureCode: { type: String },
    failureMessage: { type: String },
    processedAt: { type: Date }
  },
  {
    timestamps: true
  }
);

RefundSchema.virtual('id').get(function (this: IRefund) {
  return this._id.toString();
});
RefundSchema.set('toJSON', { virtuals: true });
RefundSchema.set('toObject', { virtuals: true });

export default mongoose.models.Refund || mongoose.model<IRefund>('Refund', RefundSchema);
