import mongoose from 'mongoose';
import type { App } from 'firebase-admin/app';
import PushDevice from '../models/PushDevice';
import Item from '../models/Item';
import User from '../models/User';

export interface ChatPushRequest {
  receiverId: mongoose.Types.ObjectId;
  conversationId: string;
  itemId: string;
  senderId: string;
  messageType: 'text' | 'image';
}

export interface ChatPushPayload extends ChatPushRequest {
  itemTitle: string;
  senderName: string;
}

interface PushDeliveryResult {
  invalidTokens: string[];
}

export interface PushGateway {
  send(tokens: string[], payload: ChatPushPayload): Promise<PushDeliveryResult>;
}

let firebaseApp: App | null | undefined;
let gatewayOverride: PushGateway | null = null;

export type FirebaseCredentialConfiguration =
  | { source: 'inline'; credentials: string }
  | { source: 'application-default'; projectId?: string }
  | null;

export function resolveFirebaseCredentialConfiguration(
  env: NodeJS.ProcessEnv = process.env
): FirebaseCredentialConfiguration {
  const inlineCredentials = env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim();
  if (inlineCredentials) {
    return { source: 'inline', credentials: inlineCredentials };
  }

  const credentialFile = env.GOOGLE_APPLICATION_CREDENTIALS?.trim();
  const projectId = env.FIREBASE_PROJECT_ID?.trim();
  if (!credentialFile && !projectId) return null;
  return {
    source: 'application-default',
    ...(projectId ? { projectId } : {})
  };
}

async function configuredFirebaseApp(): Promise<App | null> {
  if (firebaseApp !== undefined) return firebaseApp;

  try {
    const { applicationDefault, cert, getApps, initializeApp } = await import(
      'firebase-admin/app'
    );
    if (getApps().length > 0) {
      firebaseApp = getApps()[0];
      return firebaseApp;
    }

    const configuration = resolveFirebaseCredentialConfiguration();
    if (configuration?.source === 'inline') {
      firebaseApp = initializeApp({
        credential: cert(JSON.parse(configuration.credentials))
      });
    } else if (configuration?.source === 'application-default') {
      firebaseApp = initializeApp({
        credential: applicationDefault(),
        ...(configuration.projectId
          ? { projectId: configuration.projectId }
          : {})
      });
    } else {
      firebaseApp = null;
    }
  } catch (error) {
    firebaseApp = null;
    console.warn(
      '[Push Notification] Firebase Admin could not be initialized; push delivery is disabled.',
      error instanceof Error ? error.message : 'Unknown initialization error.'
    );
  }

  return firebaseApp;
}

const firebaseGateway: PushGateway = {
  async send(tokens, payload) {
    const app = await configuredFirebaseApp();
    if (!app || tokens.length === 0) return { invalidTokens: [] };

    const { getMessaging } = await import('firebase-admin/messaging');
    const response = await getMessaging(app).sendEachForMulticast({
      tokens,
      notification: {
        title: 'New KiwiShare message',
        body: `${payload.senderName} sent you ${payload.messageType === 'image' ? 'a photo' : 'a message'} about ${payload.itemTitle}.`
      },
      data: {
        type: 'chat_message',
        conversationId: payload.conversationId,
        itemId: payload.itemId,
        itemTitle: payload.itemTitle,
        participantId: payload.senderId,
        participantName: payload.senderName
      },
      android: {
        priority: 'high',
        notification: { sound: 'default' }
      },
      apns: {
        payload: { aps: { sound: 'default', contentAvailable: true } }
      }
    });

    const invalidTokens = response.responses.flatMap((result, index) => {
      const code = result.error?.code;
      return code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
        ? [tokens[index]]
        : [];
    });
    return { invalidTokens };
  }
};

export function setPushGatewayForTests(gateway: PushGateway | null) {
  gatewayOverride = gateway;
}

export async function notifyChatReceiver(request: ChatPushRequest): Promise<void> {
  try {
    const registrations = await PushDevice.find({ userId: request.receiverId })
      .select('+token')
      .sort({ lastSeenAt: -1 })
      .limit(20)
      .lean();
    const tokens = registrations
      .map((registration: any) => registration.token)
      .filter((token: unknown): token is string => typeof token === 'string');
    if (tokens.length === 0) return;

    const [itemResult, senderResult] = await Promise.all([
      Item.findById(request.itemId).select('title').lean(),
      User.findById(request.senderId).select('displayName').lean()
    ]);

    const item = itemResult as { title?: string } | null;
    const sender = senderResult as { displayName?: string } | null;
    const payload: ChatPushPayload = {
      ...request,
      itemTitle: item?.title ?? 'an item',
      senderName: sender?.displayName ?? 'A KiwiShare member'
    };
    const result = await (gatewayOverride ?? firebaseGateway).send(tokens, payload);
    if (result.invalidTokens.length > 0) {
      await PushDevice.deleteMany({ token: { $in: result.invalidTokens } });
    }
  } catch (error) {
    // Message persistence is authoritative. Push delivery is best-effort and
    // must never turn a successfully stored chat message into an API failure.
    console.warn(
      '[Push Notification] Chat notification delivery failed.',
      error instanceof Error ? error.message : 'Unknown delivery error.'
    );
  }
}
