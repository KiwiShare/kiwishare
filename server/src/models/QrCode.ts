import mongoose, { Schema, Document } from 'mongoose';

export interface IQrCode extends Document {
  orderId: mongoose.Types.ObjectId;
  sellerId: mongoose.Types.ObjectId;
  buyerId: mongoose.Types.ObjectId;
  tokenHash: string;
  status: 'active' | 'scanned' | 'consumed' | 'expired' | 'cancelled';
  expiresAt: Date;
  scannedAt?: Date;
  scannedByUserId?: mongoose.Types.ObjectId;
  scannedDeviceId?: string;
  scannedLocation?: {
    latitude: number;
    longitude: number;
  };
  consumedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const QrCodeSchema = new Schema<IQrCode>(
  {
    orderId: { type: Schema.Types.ObjectId, ref: 'Order', required: true },
    sellerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    buyerId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    tokenHash: { type: String, required: true, unique: true, index: true },
    status: {
      type: String,
      enum: ['active', 'scanned', 'consumed', 'expired', 'cancelled'],
      default: 'active'
    },
    expiresAt: { type: Date, required: true },
    scannedAt: { type: Date },
    scannedByUserId: { type: Schema.Types.ObjectId, ref: 'User' },
    scannedDeviceId: { type: String },
    scannedLocation: {
      latitude: { type: Number },
      longitude: { type: Number }
    },
    consumedAt: { type: Date }
  },
  {
    timestamps: true
  }
);

// Compound index
QrCodeSchema.index({ orderId: 1, status: 1 });

// TTL index for automatic expiration
QrCodeSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

QrCodeSchema.virtual('id').get(function (this: IQrCode) {
  return this._id.toString();
});
QrCodeSchema.set('toJSON', { virtuals: true });
QrCodeSchema.set('toObject', { virtuals: true });

export default mongoose.models.QrCode || mongoose.model<IQrCode>('QrCode', QrCodeSchema);
