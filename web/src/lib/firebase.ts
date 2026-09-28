import { getApp, getApps, initializeApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';

let authInstance: Auth | null = null;

function requireValue(name: string, value: string | undefined): string {
  const normalized = value?.trim();
  if (!normalized) {
    throw new Error(`Firebase Web Auth is missing ${name}.`);
  }
  return normalized;
}

export function getFirebaseAuth(): Auth {
  if (authInstance) return authInstance;

  const firebaseConfig = {
    apiKey: requireValue('VITE_FIREBASE_API_KEY', import.meta.env.VITE_FIREBASE_API_KEY),
    authDomain: requireValue(
      'VITE_FIREBASE_AUTH_DOMAIN',
      import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
    ),
    projectId: requireValue(
      'VITE_FIREBASE_PROJECT_ID',
      import.meta.env.VITE_FIREBASE_PROJECT_ID,
    ),
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET?.trim(),
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID?.trim(),
    appId: requireValue('VITE_FIREBASE_APP_ID', import.meta.env.VITE_FIREBASE_APP_ID),
    measurementId: import.meta.env.VITE_FIREBASE_MEASUREMENT_ID?.trim(),
  };

  const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
  authInstance = getAuth(app);
  return authInstance;
}
