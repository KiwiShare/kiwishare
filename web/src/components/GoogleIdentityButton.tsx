import React, { useState } from 'react';
import { GoogleAuthProvider, signInWithPopup } from 'firebase/auth';
import { getFirebaseAuth } from '../lib/firebase';

interface GoogleIdentityButtonProps {
  onCredential: (idToken: string) => void | Promise<void>;
  disabled?: boolean;
  text?: 'signin_with' | 'signup_with' | 'continue_with';
  onError?: (message: string) => void;
}

const labels = {
  signin_with: 'Sign in with Google',
  signup_with: 'Sign up with Google',
  continue_with: 'Continue with Google',
} as const;

export const GoogleIdentityButton: React.FC<GoogleIdentityButtonProps> = ({
  onCredential,
  disabled = false,
  text = 'continue_with',
  onError,
}) => {
  const [busy, setBusy] = useState(false);

  const handleGoogleSignIn = async () => {
    try {
      setBusy(true);
      onError?.('');

      const provider = new GoogleAuthProvider();
      provider.setCustomParameters({ prompt: 'select_account' });

      const result = await signInWithPopup(getFirebaseAuth(), provider);
      const credential = GoogleAuthProvider.credentialFromResult(result);
      const idToken = credential?.idToken?.trim();

      if (!idToken) {
        throw new Error('Google did not return a valid identity token.');
      }

      await onCredential(idToken);
    } catch (error: any) {
      if (error?.code === 'auth/popup-closed-by-user') return;

      if (error?.code === 'auth/popup-blocked') {
        onError?.('Your browser blocked the Google sign-in popup. Please allow popups and try again.');
        return;
      }

      if (error?.code === 'auth/unauthorized-domain') {
        onError?.('This KiwiShare domain is not authorized in Firebase Authentication.');
        return;
      }

      onError?.(
        error instanceof Error
          ? error.message
          : 'Google sign-in is currently unavailable.',
      );
    } finally {
      setBusy(false);
    }
  };

  const isDisabled = disabled || busy;

  return (
    <button
      type="button"
      onClick={handleGoogleSignIn}
      disabled={isDisabled}
      aria-busy={busy}
      className="btn btn-secondary"
      style={{
        width: '100%',
        minHeight: 44,
        borderRadius: '8px',
        backgroundColor: '#ffffff',
        border: '1px solid #dadce0',
        color: '#3c4043',
        fontWeight: 600,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: '10px',
        opacity: isDisabled ? 0.6 : 1,
      }}
    >
      <span
        aria-hidden="true"
        style={{
          width: 20,
          height: 20,
          borderRadius: '50%',
          border: '1px solid #dadce0',
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontWeight: 800,
          fontSize: '0.8rem',
          color: '#4285f4',
          backgroundColor: '#fff',
        }}
      >
        G
      </span>
      <span>{busy ? 'Connecting to Google…' : labels[text]}</span>
    </button>
  );
};
