import mongoose, { Document, Schema } from 'mongoose';

export const REPORT_TARGET_TYPES = ['user', 'listing', 'general'] as const;
export type ReportTargetType = (typeof REPORT_TARGET_TYPES)[number];

export const REPORT_CONTEXT_TYPES = [
  'profile',
  'listing',
  'chat',
  'transaction',
  'general'
] as const;
export type ReportContextType = (typeof REPORT_CONTEXT_TYPES)[number];

export const USER_REPORT_REASONS = [
  'scam_or_fraud',
  'harassment_or_abusive_behaviour',
  'unsafe_meetup_behaviour',
  'did_not_show_up_repeatedly',
  'fake_identity_or_impersonation',
  'suspicious_payment_request',
  'off_platform_communication',
  'other'
] as const;

export const LISTING_REPORT_REASONS = [
  'misleading_information',
  'prohibited_or_unsafe_item',
  'counterfeit_item',
  'suspected_stolen_item',
  'duplicate_listing_or_spam',
  'other'
] as const;

export const REPORT_REASON_CODES = [
  'scam_or_fraud',
  'harassment_or_abusive_behaviour',
  'unsafe_meetup_behaviour',
  'did_not_show_up_repeatedly',
  'fake_identity_or_impersonation',
  'suspicious_payment_request',
  'off_platform_communication',
  'misleading_information',
  'prohibited_or_unsafe_item',
  'counterfeit_item',
  'suspected_stolen_item',
  'duplicate_listing_or_spam',
  'other'
] as const;
export type ReportReasonCode = (typeof REPORT_REASON_CODES)[number];

export const REPORT_STATUSES = ['pending', 'reviewed', 'dismissed'] as const;
export type ReportStatus = (typeof REPORT_STATUSES)[number];

export interface IReport extends Document {
  reporterId: mongoose.Types.ObjectId;
  targetType: ReportTargetType;
  targetId?: mongoose.Types.ObjectId;
  dedupeKey?: string;
  contextType: ReportContextType;
  contextId?: mongoose.Types.ObjectId;
  reason: ReportReasonCode;
  details: string;
  status: ReportStatus;
  createdAt: Date;
}

const ReportSchema = new Schema<IReport>(
  {
    reporterId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      immutable: true,
      index: true
    },
    targetType: {
      type: String,
      enum: REPORT_TARGET_TYPES,
      required: true,
      immutable: true
    },
    targetId: {
      type: Schema.Types.ObjectId,
      immutable: true,
      required: function (this: IReport) {
        return this.targetType !== 'general';
      }
    },
    dedupeKey: {
      type: String,
      immutable: true,
      select: false
    },
    contextType: {
      type: String,
      enum: REPORT_CONTEXT_TYPES,
      required: true,
      immutable: true
    },
    contextId: { type: Schema.Types.ObjectId, immutable: true },
    reason: {
      type: String,
      enum: REPORT_REASON_CODES,
      required: true,
      immutable: true
    },
    details: {
      type: String,
      required: true,
      trim: true,
      minlength: 10,
      maxlength: 1000,
      immutable: true
    },
    status: {
      type: String,
      enum: REPORT_STATUSES,
      required: true,
      default: 'pending',
      index: true
    }
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    versionKey: false
  }
);

ReportSchema.index({ reporterId: 1, createdAt: -1 });
ReportSchema.index({ targetType: 1, targetId: 1, createdAt: -1 });
ReportSchema.index({ status: 1, createdAt: 1 });
ReportSchema.index({
  dedupeKey: 1
}, {
  unique: true,
  sparse: true,
  name: 'unique_reporter_target'
});

export default mongoose.models.Report ||
  mongoose.model<IReport>('Report', ReportSchema);
