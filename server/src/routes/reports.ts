import { Context } from 'koa';
import Router from 'koa-router';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Conversation, { IConversation } from '../models/Conversation';
import Item, { IItem } from '../models/Item';
import Order, { IOrder } from '../models/Order';
import Report, {
  IReport,
  LISTING_REPORT_REASONS,
  REPORT_CONTEXT_TYPES,
  REPORT_TARGET_TYPES,
  ReportContextType,
  ReportReasonCode,
  ReportTargetType,
  USER_REPORT_REASONS
} from '../models/Report';
import User from '../models/User';
import { sendReportConfirmationEmail } from '../services/reportConfirmationEmail';

const router = new Router();

type ReportPayload = Record<string, unknown>;

function error(ctx: Context, status: number, message: string) {
  ctx.status = status;
  ctx.body = { status: 'error', message };
}

function enumValue<T extends string>(
  value: unknown,
  allowed: readonly T[]
): T | null {
  return typeof value === 'string' && allowed.includes(value as T)
    ? (value as T)
    : null;
}

function optionalId(
  payload: ReportPayload,
  key: 'targetId' | 'contextId'
): string | null | undefined {
  const value = payload[key];
  if (value === undefined || value === null) return undefined;
  if (typeof value !== 'string' || value.trim().length === 0) return null;
  return value.trim();
}

function serializeReport(report: IReport) {
  return {
    id: report._id.toString(),
    reporterId: report.reporterId.toString(),
    targetType: report.targetType,
    ...(report.targetId ? { targetId: report.targetId.toString() } : {}),
    contextType: report.contextType,
    ...(report.contextId ? { contextId: report.contextId.toString() } : {}),
    reason: report.reason,
    details: report.details,
    status: report.status,
    createdAt: report.createdAt.toISOString()
  };
}

function validReason(targetType: ReportTargetType, reason: string) {
  const reasons = targetType === 'listing'
    ? LISTING_REPORT_REASONS
    : USER_REPORT_REASONS;
  return reasons.includes(reason as never);
}

function duplicateReportMessage(targetType: ReportTargetType) {
  const target = targetType === 'listing' ? 'listing' : 'user';
  return `You have already reported this ${target}. We will review your existing report.`;
}

function isDuplicateKeyError(value: unknown): value is { code: number } {
  return typeof value === 'object' &&
    value !== null &&
    'code' in value &&
    (value as { code?: unknown }).code === 11000;
}

async function validateUserContext(
  reporterId: mongoose.Types.ObjectId,
  targetId: mongoose.Types.ObjectId,
  contextType: ReportContextType,
  contextId?: mongoose.Types.ObjectId
): Promise<{ status: number; message: string } | null> {
  if (contextType === 'profile') {
    if (contextId && !contextId.equals(targetId)) {
      return { status: 400, message: 'Profile report context does not match the reported user.' };
    }
    return null;
  }

  if (!contextId) {
    return { status: 400, message: 'A chat or transaction context ID is required.' };
  }

  if (contextType === 'chat') {
    const conversation = await Conversation.findById(contextId)
      .select('buyerId sellerId')
      .exec() as IConversation | null;
    if (!conversation) {
      return { status: 404, message: 'Report context not found.' };
    }
    const participants = [
      conversation.buyerId.toString(),
      conversation.sellerId.toString()
    ];
    if (
      !participants.includes(reporterId.toString()) ||
      !participants.includes(targetId.toString())
    ) {
      return { status: 403, message: 'Report context is not available to this user.' };
    }
    return null;
  }

  if (contextType === 'transaction') {
    const order = await Order.findById(contextId)
      .select('buyerId sellerId')
      .exec() as IOrder | null;
    if (!order) {
      return { status: 404, message: 'Report context not found.' };
    }
    const participants = [order.buyerId.toString(), order.sellerId.toString()];
    if (
      !participants.includes(reporterId.toString()) ||
      !participants.includes(targetId.toString())
    ) {
      return { status: 403, message: 'Report context is not available to this user.' };
    }
    return null;
  }

  return { status: 400, message: 'User reports require a profile, chat, or transaction context.' };
}

router.get('/reports', authenticateToken, async (ctx: Context) => {
  const reporterId = ctx.state.user?.id;
  if (
    typeof reporterId !== 'string' ||
    !mongoose.isValidObjectId(reporterId) ||
    !await User.exists({ _id: reporterId })
  ) {
    ctx.status = 401;
    ctx.body = { status: 'error', message: 'Please sign in again.' };
    return;
  }

  const reports = await Report.find({ reporterId })
    .select('targetType contextType reason details status createdAt')
    .sort({ createdAt: -1, _id: -1 })
    .lean()
    .exec();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    reports: reports.map((report) => ({
      id: String(report._id),
      targetType: report.targetType,
      contextType: report.contextType,
      reason: report.reason,
      details: report.details,
      status: report.status === 'submitted' ? 'pending' : report.status,
      createdAt: report.createdAt.toISOString()
    }))
  };
});

router.post('/reports', authenticateToken, async (ctx: Context) => {
  const payload = ctx.request.body;
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    error(ctx, 400, 'A report request body is required.');
    return;
  }
  const body = payload as ReportPayload;

  const targetType = enumValue(body.targetType, REPORT_TARGET_TYPES);
  const contextType = enumValue(body.contextType, REPORT_CONTEXT_TYPES);
  const reason = typeof body.reason === 'string' ? body.reason.trim() : '';
  const details = typeof body.details === 'string' ? body.details.trim() : '';
  const targetIdValue = optionalId(body, 'targetId');
  const contextIdValue = optionalId(body, 'contextId');

  if (!targetType) {
    error(ctx, 400, 'Invalid report target type.');
    return;
  }
  if (!contextType) {
    error(ctx, 400, 'Invalid report context type.');
    return;
  }
  if (!validReason(targetType, reason)) {
    error(ctx, 400, 'Invalid report reason for this target.');
    return;
  }
  if (details.length < 10 || details.length > 1000) {
    error(ctx, 400, 'Report details must be between 10 and 1000 characters.');
    return;
  }
  if (targetIdValue === null || contextIdValue === null) {
    error(ctx, 400, 'Report target and context IDs must be valid strings.');
    return;
  }

  const authenticatedUserId = ctx.state.user?.id;
  if (
    typeof authenticatedUserId !== 'string' ||
    !mongoose.Types.ObjectId.isValid(authenticatedUserId)
  ) {
    error(ctx, 401, 'The authenticated user is invalid.');
    return;
  }
  const reporterId = new mongoose.Types.ObjectId(authenticatedUserId);
  const reporter = await User.findById(reporterId)
    .select('email displayName')
    .lean<{ email: string; displayName: string }>()
    .exec();
  if (!reporter) {
    error(ctx, 401, 'The authenticated user no longer exists.');
    return;
  }

  let targetId: mongoose.Types.ObjectId | undefined;
  let contextId: mongoose.Types.ObjectId | undefined;
  if (targetIdValue !== undefined) {
    if (!mongoose.Types.ObjectId.isValid(targetIdValue)) {
      error(ctx, 400, 'Invalid report target ID.');
      return;
    }
    targetId = new mongoose.Types.ObjectId(targetIdValue);
  }
  if (contextIdValue !== undefined) {
    if (!mongoose.Types.ObjectId.isValid(contextIdValue)) {
      error(ctx, 400, 'Invalid report context ID.');
      return;
    }
    contextId = new mongoose.Types.ObjectId(contextIdValue);
  }

  if (targetType === 'general') {
    if (targetId || contextType !== 'general' || contextId) {
      error(ctx, 400, 'General reports cannot specify a target or related context.');
      return;
    }
  } else if (!targetId) {
    error(ctx, 400, 'A report target ID is required.');
    return;
  }

  if (targetType === 'user' && targetId) {
    if (reporterId.equals(targetId)) {
      error(ctx, 400, 'You cannot report your own account.');
      return;
    }
    if (!await User.exists({ _id: targetId })) {
      error(ctx, 404, 'Reported user not found.');
      return;
    }
    const contextError = await validateUserContext(
      reporterId,
      targetId,
      contextType,
      contextId
    );
    if (contextError) {
      error(ctx, contextError.status, contextError.message);
      return;
    }
    if (contextType === 'profile') contextId = targetId;
  }

  if (targetType === 'listing' && targetId) {
    if (contextType !== 'listing') {
      error(ctx, 400, 'Listing reports require a listing context.');
      return;
    }
    if (contextId && !contextId.equals(targetId)) {
      error(ctx, 400, 'Listing report context does not match the reported listing.');
      return;
    }
    const item = await Item.findById(targetId)
      .select('sellerId ownerId')
      .exec() as IItem | null;
    if (!item) {
      error(ctx, 404, 'Reported listing not found.');
      return;
    }
    const ownerId = item.sellerId?.toString() || item.ownerId;
    if (ownerId === reporterId.toString()) {
      error(ctx, 400, 'You cannot report your own listing.');
      return;
    }
    contextId = targetId;
  }

  const dedupeKey = targetId
    ? `${reporterId}:${targetType}:${targetId}`
    : undefined;
  if (targetId && await Report.exists({ reporterId, targetType, targetId })) {
    error(ctx, 409, duplicateReportMessage(targetType));
    return;
  }

  let report: IReport;
  try {
    report = await Report.create({
      reporterId,
      targetType,
      targetId,
      dedupeKey,
      contextType,
      contextId,
      reason: reason as ReportReasonCode,
      details,
      status: 'pending'
    });
  } catch (createError) {
    if (targetId && isDuplicateKeyError(createError)) {
      error(ctx, 409, duplicateReportMessage(targetType));
      return;
    }
    throw createError;
  }

  try {
    await sendReportConfirmationEmail({
      email: reporter.email,
      displayName: reporter.displayName,
      reportId: report._id.toString(),
      submittedAt: report.createdAt
    });
  } catch (emailError) {
    const message = emailError instanceof Error ? emailError.message : 'Unknown error';
    console.warn(`[Report confirmation email] ${report._id}: ${message}`);
  }

  ctx.status = 201;
  ctx.body = { status: 'success', report: serializeReport(report) };
});

export default router;
