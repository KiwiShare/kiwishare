import mongoose, { Schema, Document } from 'mongoose';

export interface IOtp extends Document {
  email: string;
  code: string;
  expiresAt: Date;
  used: boolean;
  createdAt: Date;
}

const OtpSchema = new Schema<IOtp>({
  email: { type: String, required: true, index: true },
  code: { type: String, required: true },
  expiresAt: { type: Date, required: true },
  used: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.models.Otp || mongoose.model<IOtp>('Otp', OtpSchema);
