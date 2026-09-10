import mongoose, { Schema, Document } from 'mongoose';

export interface IAuditLog extends Document {
  userId?: mongoose.Types.ObjectId;
  actorType: 'user' | 'admin' | 'system' | 'stripe';
  action: string;
  targetType: 'user' | 'item' | 'order' | 'payment' | 'refund' | 'transfer';
  targetId: mongoose.Types.ObjectId;
  oldValue?: Record<string, any>;
  newValue?: Record<string, any>;
  requestId?: string;
  ipAddress?: string;
  deviceId?: string;
  result: 'success' | 'failed' | 'denied';
  errorMessage?: string;
  createdAt: Date;
}

const AuditLogSchema = new Schema<IAuditLog>(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', index: true },
    actorType: { type: String, enum: ['user', 'admin', 'system', 'stripe'], required: true },
    action: { type: String, required: true },
    targetType: {
      type: String,
      enum: ['user', 'item', 'order', 'payment', 'refund', 'transfer'],
      required: true
    },
    targetId: { type: Schema.Types.ObjectId, required: true },
    oldValue: { type: Schema.Types.Map, of: Schema.Types.Mixed },
    newValue: { type: Schema.Types.Map, of: Schema.Types.Mixed },
    requestId: { type: String },
    ipAddress: { type: String },
    deviceId: { type: String },
    result: { type: String, enum: ['success', 'failed', 'denied'], required: true },
    errorMessage: { type: String }
  },
  {
    timestamps: { createdAt: true, updatedAt: false } // Only createdAt is needed for logs
  }
);

// Indexes
AuditLogSchema.index({ userId: 1, createdAt: -1 });
AuditLogSchema.index({ targetType: 1, targetId: 1, createdAt: -1 });
AuditLogSchema.index({ action: 1, createdAt: -1 });

export default mongoose.models.AuditLog || mongoose.model<IAuditLog>('AuditLog', AuditLogSchema);
