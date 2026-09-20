import mongoose, { Schema, Document } from 'mongoose';

export interface IPlatformSetting extends Document {
  key: string;
  value: any;
  description?: string;
  updatedAt: Date;
}

const PlatformSettingSchema = new Schema<IPlatformSetting>(
  {
    key: { type: String, required: true, unique: true, index: true },
    value: { type: Schema.Types.Mixed, required: true },
    description: { type: String }
  },
  { timestamps: true }
);

export async function getPlatformFeeSettings(): Promise<{
  buyerFeePercent: number;
  minFeeCents: number;
}> {
  const setting = await PlatformSetting.findOne({ key: 'platform_fees' });
  if (setting && setting.value) {
    const percent = Number(setting.value.buyerFeePercent);
    const minCents = Number(setting.value.minFeeCents);
    return {
      buyerFeePercent: !isNaN(percent) && percent >= 0 ? percent : 3.5,
      minFeeCents: !isNaN(minCents) && minCents >= 0 ? minCents : 50
    };
  }
  return {
    buyerFeePercent: 3.5, // 3.5%
    minFeeCents: 50 // 50 cents ($0.50 NZD)
  };
}

export async function updatePlatformFeeSettings(
  buyerFeePercent: number,
  minFeeCents: number
): Promise<{ buyerFeePercent: number; minFeeCents: number }> {
  const percent = Math.max(0, Math.min(50, Number(buyerFeePercent) || 0));
  const minCents = Math.max(0, Math.round(Number(minFeeCents) || 0));

  const updated = await PlatformSetting.findOneAndUpdate(
    { key: 'platform_fees' },
    {
      $set: {
        value: { buyerFeePercent: percent, minFeeCents: minCents },
        description: 'Platform service fees applied to campus transactions'
      }
    },
    { upsert: true, new: true }
  );

  return {
    buyerFeePercent: updated.value.buyerFeePercent,
    minFeeCents: updated.value.minFeeCents
  };
}

const PlatformSetting =
  mongoose.models.PlatformSetting ||
  mongoose.model<IPlatformSetting>('PlatformSetting', PlatformSettingSchema);

export default PlatformSetting;
