import mongoose, { Schema } from 'mongoose';

const ReportSchema = new Schema({
  reporterId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  targetType: { type: String, enum: ['general', 'user', 'listing'], required: true },
  targetId: { type: String },
  contextType: { type: String, enum: ['general', 'profile', 'listing', 'chat', 'transaction'], required: true },
  contextId: { type: String },
  reason: { type: String, required: true },
  details: { type: String, required: true, minlength: 10, maxlength: 1000 },
  status: { type: String, enum: ['pending', 'reviewed', 'dismissed'], default: 'pending' }
}, { timestamps: true });

export default mongoose.models.Report || mongoose.model('Report', ReportSchema);
