import mongoose, { Schema, Document } from 'mongoose';

export interface IPayment extends Document {
  orderId: mongoose.Types.ObjectId;
  buyerId: mongoose.Types.ObjectId;
  provider: 'stripe';
  environment: 'test' | 'live';
  stripePaymentIntentId: string;
  stripeChargeId?: string;
  amount: number; // cents
  currency: string;
  status:
    | 'pending'
    | 'requires_action'
    | 'processing'
    | 'succeeded'
    | 'failed'
    | 'cancelled'
    | 'partially_refunded'
    | 'refunded'
    | 'disputed';
  paymentMethod?: {
    type: string; // card, apple_pay, google_pay
    brand?: string;
    last4?: string;
  };
  refundedAmount?: number; // cents
  failureCode?: string;
  failureMessage?: string;
  idempotencyKey: string;
  paidAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const PaymentSchema = new Schema<IPayment>(
  {
    orderId: { type: Schema.Types.ObjectId, ref: 'Order', required: true, index: true },
    buyerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    provider: { type: String, enum: ['stripe'], required: true, default: 'stripe' },
    environment: { type: String, enum: ['test', 'live'], required: true },
    stripePaymentIntentId: { type: String, required: true, unique: true, index: true },
    stripeChargeId: { type: String, index: true },
    amount: { type: Number, required: true },
    currency: { type: String, required: true, default: 'NZD' },
    status: {
      type: String,
      enum: [
        'pending',
        'requires_action',
        'processing',
        'succeeded',
        'failed',
        'cancelled',
        'partially_refunded',
        'refunded',
        'disputed'
      ],
      default: 'pending'
    },
    paymentMethod: {
      type: { type: String },
      brand: { type: String },
      last4: { type: String }
    },
    refundedAmount: { type: Number, default: 0 },
    failureCode: { type: String },
    failureMessage: { type: String },
    idempotencyKey: { type: String, required: true, unique: true, index: true },
    paidAt: { type: Date }
  },
  {
    timestamps: true
  }
);

PaymentSchema.virtual('id').get(function (this: IPayment) {
  return this._id.toString();
});
PaymentSchema.set('toJSON', { virtuals: true });
PaymentSchema.set('toObject', { virtuals: true });

export default mongoose.models.Payment || mongoose.model<IPayment>('Payment', PaymentSchema);
