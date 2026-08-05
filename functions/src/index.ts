import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import app from './app';

// Initialize Firebase Admin SDK if not already done in the current context
try {
  admin.initializeApp();
} catch (e) {
  // Silent fallback for testing contexts where Firebase credentials are empty
}

// Export the Koa app instance as a serverless onRequest function
export const api = onRequest({ cors: true }, app.callback());
