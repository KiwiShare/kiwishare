import Router from 'koa-router';
import { Context } from 'koa';
import mongoose from 'mongoose';
import { authenticateToken } from '../middleware/auth';
import Conversation from '../models/Conversation';
import Message from '../models/Message';
import Item from '../models/Item';

const router = new Router({ prefix: '/conversations' });
const DEFAULT_MESSAGE_LIMIT = 50;
const MAX_MESSAGE_LIMIT = 100;
const MAX_MESSAGE_LENGTH = 2000;

router.use(authenticateToken);

function currentUserId(ctx: Context): mongoose.Types.ObjectId | null {
  const value = ctx.state.user?.id;
  return mongoose.Types.ObjectId.isValid(value)
    ? new mongoose.Types.ObjectId(value)
    : null;
}

function objectId(value: any): string {
  return (value?._id ?? value)?.toString() ?? '';
}

function formatConversation(conversation: any, userId: string) {
  const buyerId = objectId(conversation.buyerId);
  const buying = buyerId === userId;
  const participant = buying ? conversation.sellerId : conversation.buyerId;
  const item = conversation.itemId;
  const rawImages = Array.isArray(item?.images) ? item.images : [];

  return {
    id: objectId(conversation),
    status: conversation.status,
    direction: buying ? 'buying' : 'selling',
    unreadCount: buying
      ? conversation.buyerUnreadCount ?? 0
      : conversation.sellerUnreadCount ?? 0,
    lastMessageText: conversation.lastMessageText ?? '',
    lastMessageAt: conversation.lastMessageAt ?? null,
    item: {
      id: objectId(item),
      title: item?.title ?? 'Unavailable item',
      imageUrl: item?.imageUrl ?? rawImages[0]?.url ?? ''
    },
    participant: {
      id: objectId(participant),
      displayName: participant?.displayName ?? 'Kiwi member',
      avatarUrl: participant?.avatarUrl ?? null
    },
    createdAt: conversation.createdAt,
    updatedAt: conversation.updatedAt
  };
}

function formatMessage(message: any, userId: string) {
  const senderId = objectId(message.senderId);
  return {
    id: objectId(message),
    conversationId: objectId(message.conversationId),
    senderId,
    receiverId: objectId(message.receiverId),
    type: message.type,
    text: message.text ?? '',
    status: message.status,
    isMine: senderId === userId,
    readAt: message.readAt ?? null,
    createdAt: message.createdAt,
    updatedAt: message.updatedAt
  };
}

async function findConversationForUser(
  ctx: Context,
  conversationId: string,
  userId: mongoose.Types.ObjectId
) {
  if (!mongoose.Types.ObjectId.isValid(conversationId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'Invalid conversation ID.' };
    return null;
  }

  const conversation = await Conversation.findById(conversationId);
  if (!conversation) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Conversation not found.' };
    return null;
  }

  const userIdText = userId.toString();
  if (
    conversation.buyerId.toString() !== userIdText &&
    conversation.sellerId.toString() !== userIdText
  ) {
    ctx.status = 403;
    ctx.body = {
      status: 'error',
      message: 'You do not have access to this conversation.'
    };
    return null;
  }

  return conversation;
}

router.get('/', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const conversations = await Conversation.find({
    $or: [{ buyerId: userId }, { sellerId: userId }],
    hiddenForUserIds: { $ne: userId }
  })
    .populate('itemId', 'title imageUrl images status')
    .populate('buyerId', 'displayName avatarUrl')
    .populate('sellerId', 'displayName avatarUrl')
    .sort({ lastMessageAt: -1, updatedAt: -1 });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    conversations: conversations.map((conversation) =>
      formatConversation(conversation, userId.toString())
    )
  };
});

router.post('/', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const { itemId } = ctx.request.body as { itemId?: unknown };
  if (typeof itemId !== 'string' || !mongoose.Types.ObjectId.isValid(itemId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'A valid item ID is required.' };
    return;
  }

  const item = await Item.findById(itemId);
  if (!item || ['deleted', 'hidden', 'revoked'].includes(item.status)) {
    ctx.status = 404;
    ctx.body = { status: 'error', message: 'Item not found.' };
    return;
  }

  const sellerId = new mongoose.Types.ObjectId(item.sellerId.toString());
  if (sellerId.equals(userId)) {
    ctx.status = 400;
    ctx.body = { status: 'error', message: 'You cannot message yourself about your own item.' };
    return;
  }

  let conversation = await Conversation.findOne({
    itemId: item._id,
    buyerId: userId,
    sellerId
  });
  let wasCreated = false;

  if (!conversation) {
    try {
      conversation = await Conversation.create({
        itemId: item._id,
        buyerId: userId,
        sellerId,
        status: 'active'
      });
      wasCreated = true;
    } catch (error: any) {
      if (error?.code !== 11000) throw error;
      conversation = await Conversation.findOne({
        itemId: item._id,
        buyerId: userId,
        sellerId
      });
    }
  }

  if (!conversation) {
    throw new Error('Conversation could not be created.');
  }

  if (
    conversation.hiddenForUserIds.some((hiddenId: mongoose.Types.ObjectId) =>
      hiddenId.equals(userId)
    )
  ) {
    conversation.hiddenForUserIds = conversation.hiddenForUserIds.filter(
      (hiddenId: mongoose.Types.ObjectId) => !hiddenId.equals(userId)
    );
    await conversation.save();
  }

  await conversation.populate('itemId', 'title imageUrl images status');
  await conversation.populate('buyerId', 'displayName avatarUrl');
  await conversation.populate('sellerId', 'displayName avatarUrl');

  ctx.status = wasCreated ? 201 : 200;
  ctx.body = {
    status: wasCreated ? 'created' : 'success',
    conversation: formatConversation(conversation, userId.toString())
  };
});

router.get('/:conversationId/messages', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const conversation = await findConversationForUser(
    ctx,
    ctx.params.conversationId,
    userId
  );
  if (!conversation) return;

  const rawLimit = Number(ctx.query.limit ?? DEFAULT_MESSAGE_LIMIT);
  const limit = Number.isInteger(rawLimit)
    ? Math.min(Math.max(rawLimit, 1), MAX_MESSAGE_LIMIT)
    : DEFAULT_MESSAGE_LIMIT;
  const filter: any = {
    conversationId: conversation._id,
    status: { $ne: 'deleted' }
  };

  if (ctx.query.before != null) {
    const before = new Date(String(ctx.query.before));
    if (Number.isNaN(before.getTime())) {
      ctx.status = 400;
      ctx.body = { status: 'error', message: 'The before cursor must be a valid date.' };
      return;
    }
    filter.createdAt = { $lt: before };
  }

  const messages = await Message.find(filter)
    .sort({ createdAt: -1 })
    .limit(limit + 1);
  const hasMore = messages.length > limit;
  const page = messages.slice(0, limit).reverse();

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    messages: page.map((message) => formatMessage(message, userId.toString())),
    pagination: {
      hasMore,
      nextBefore: hasMore && page.length > 0 ? page[0].createdAt : null
    }
  };
});

router.post('/:conversationId/messages', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const conversation = await findConversationForUser(
    ctx,
    ctx.params.conversationId,
    userId
  );
  if (!conversation) return;

  if (conversation.status !== 'active') {
    ctx.status = 409;
    ctx.body = { status: 'error', message: 'This conversation is not active.' };
    return;
  }

  const { text } = ctx.request.body as { text?: unknown };
  const normalizedText = typeof text === 'string' ? text.trim() : '';
  if (normalizedText.length < 1 || normalizedText.length > MAX_MESSAGE_LENGTH) {
    ctx.status = 400;
    ctx.body = {
      status: 'error',
      message: `Message text must be between 1 and ${MAX_MESSAGE_LENGTH} characters.`
    };
    return;
  }

  const sendingAsBuyer = conversation.buyerId.equals(userId);
  const receiverId = sendingAsBuyer ? conversation.sellerId : conversation.buyerId;
  const message = await Message.create({
    conversationId: conversation._id,
    senderId: userId,
    receiverId,
    type: 'text',
    text: normalizedText,
    status: 'sent'
  });

  await Conversation.findByIdAndUpdate(conversation._id, {
    $set: {
      lastMessageText: normalizedText,
      lastMessageAt: message.createdAt,
      lastMessageSenderId: userId
    },
    $inc: sendingAsBuyer
      ? { sellerUnreadCount: 1 }
      : { buyerUnreadCount: 1 },
    $pull: { hiddenForUserIds: { $in: [userId, receiverId] } }
  });

  ctx.status = 201;
  ctx.body = {
    status: 'created',
    message: formatMessage(message, userId.toString())
  };
});

router.patch('/:conversationId/read', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const conversation = await findConversationForUser(
    ctx,
    ctx.params.conversationId,
    userId
  );
  if (!conversation) return;

  const readAt = new Date();
  const result = await Message.updateMany(
    {
      conversationId: conversation._id,
      receiverId: userId,
      status: { $in: ['sent', 'delivered'] }
    },
    { $set: { status: 'read', readAt } }
  );

  const readingAsBuyer = conversation.buyerId.equals(userId);
  await Conversation.findByIdAndUpdate(conversation._id, {
    $set: readingAsBuyer
      ? { buyerUnreadCount: 0 }
      : { sellerUnreadCount: 0 }
  });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    readCount: result.modifiedCount
  };
});

router.delete('/:conversationId', async (ctx: Context) => {
  const userId = currentUserId(ctx);
  if (!userId) {
    ctx.status = 403;
    ctx.body = { status: 'error', message: 'Invalid authenticated user.' };
    return;
  }

  const conversation = await findConversationForUser(
    ctx,
    ctx.params.conversationId,
    userId
  );
  if (!conversation) return;

  const hidingAsBuyer = conversation.buyerId.equals(userId);
  await Conversation.findByIdAndUpdate(conversation._id, {
    $addToSet: { hiddenForUserIds: userId },
    $set: hidingAsBuyer
      ? { buyerUnreadCount: 0 }
      : { sellerUnreadCount: 0 }
  });

  ctx.status = 200;
  ctx.body = {
    status: 'success',
    conversationId: conversation.id
  };
});

export default router;
