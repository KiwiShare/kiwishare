import { onRequest } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import app from './app';

import * as path from 'path';

// Initialize Firebase Admin SDK if not already done in the current context
try {
  let credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (credPath) {
    credPath = credPath.trim();
    // Strip surrounding backticks, single quotes, or double quotes
    if (
      (credPath.startsWith('`') && credPath.endsWith('`')) ||
      (credPath.startsWith('"') && credPath.endsWith('"')) ||
      (credPath.startsWith("'") && credPath.endsWith("'"))
    ) {
      credPath = credPath.slice(1, -1).trim();
    }

    if (credPath.startsWith('{') && credPath.endsWith('}')) {
      // Inline JSON string credentials
      const serviceAccount = JSON.parse(credPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: projectId
      });
    } else {
      // File path credentials
      const absolutePath = path.isAbsolute(credPath)
        ? credPath
        : path.resolve(__dirname, '..', credPath);
      admin.initializeApp({
        credential: admin.credential.cert(absolutePath),
        projectId: projectId
      });
    }
  } else {
    admin.initializeApp();
  }
} catch (e) {
  // Silent fallback for testing contexts where Firebase credentials are empty
  try {
    admin.initializeApp();
  } catch (err) {
    // Ignore if already initialized
  }
}

// Export the Koa app instance as a serverless onRequest function
export const api = onRequest({ cors: true }, app.callback());
