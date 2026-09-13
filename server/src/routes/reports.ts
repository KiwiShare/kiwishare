import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Report from '../models/Report';
import User from '../models/User';
import Item from '../models/Item';

const router = new Router();
const userReasons = ['scam_or_fraud', 'harassment_or_abusive_behaviour',
  'unsafe_meetup_behaviour', 'did_not_show_up_repeatedly', 'fake_identity_or_impersonation',
  'suspicious_payment_request', 'off_platform_communication', 'other'];
const listingReasons = ['misleading_information', 'prohibited_or_unsafe_item',
  'counterfeit_item', 'suspected_stolen_item', 'duplicate_listing_or_spam', 'other'];

router.post('/reports', authenticateToken, async (ctx) => {
  const { targetType, targetId, contextType, contextId, reason, details } = ctx.request.body as any;
  const invalid = (message: string) => { ctx.status = 400; ctx.body = { message }; };
  if (!['general', 'user', 'listing'].includes(targetType) ||
      !['general', 'profile', 'listing', 'chat', 'transaction'].includes(contextType) ||
      !(targetType === 'listing' ? listingReasons : userReasons).includes(reason) ||
      typeof details !== 'string' || details.trim().length < 10 || details.trim().length > 1000) {
    invalid('Provide a valid report type, reason and 10-1000 characters of details.');
    return;
  }
  if ((targetType === 'general' && (targetId != null || contextType !== 'general')) ||
      (targetType !== 'general' && (typeof targetId !== 'string' || !mongoose.isValidObjectId(targetId))) ||
      (contextId != null && (typeof contextId !== 'string' || contextId.length > 128))) {
    invalid('Invalid report target or context.');
    return;
  }
  const reporterId = ctx.state.user.id;
  if (!mongoose.isValidObjectId(reporterId) || !await User.exists({ _id: reporterId })) {
    ctx.status = 401;
    ctx.body = { message: 'Please sign in again.' };
    return;
  }
  if (targetType !== 'general') {
    const exists = targetType === 'user'
      ? await User.exists({ _id: targetId }) : await Item.exists({ _id: targetId });
    if (!exists) { invalid('Report target does not exist.'); return; }
  }
  // Context is user-supplied evidence, not proof of a violation or permission
  // to retrieve private chats. Filing a report never changes trust scores.
  const report = await Report.create({ reporterId, targetType, targetId,
    contextType, contextId, reason, details: details.trim() });
  ctx.status = 201;
  ctx.body = { status: 'success', report: { id: report._id.toString(), status: report.status } };
});

export default router;
