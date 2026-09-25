import React, { useEffect, useRef, useState } from 'react';

const DEFAULT_GOOGLE_WEB_CLIENT_ID =
  '353504132004-v9hv2iktcb0164pgsrp9ov41ihc7kba2.apps.googleusercontent.com';

declare global {
  interface Window {
    google?: {
      accounts: {
        id: {
          initialize: (config: {
            client_id: string;
            callback: (response: { credential?: string }) => void;
            auto_select?: boolean;
            cancel_on_tap_outside?: boolean;
          }) => void;
          renderButton: (
            parent: HTMLElement,
            options: {
              type?: 'standard' | 'icon';
              theme?: 'outline' | 'filled_blue' | 'filled_black';
              size?: 'large' | 'medium' | 'small';
              text?: 'signin_with' | 'signup_with' | 'continue_with' | 'signin';
              shape?: 'rectangular' | 'pill' | 'circle' | 'square';
              width?: number;
              logo_alignment?: 'left' | 'center';
            },
          ) => void;
        };
      };
    };
  }
}

let googleScriptPromise: Promise<void> | null = null;

function loadGoogleIdentityServices(): Promise<void> {
  if (window.google?.accounts?.id) return Promise.resolve();
  if (googleScriptPromise) return googleScriptPromise;

  googleScriptPromise = new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      'script[src="https://accounts.google.com/gsi/client"]',
    );
    if (existing) {
      existing.addEventListener('load', () => resolve(), { once: true });
      existing.addEventListener(
        'error',
        () => reject(new Error('Failed to load Google Identity Services.')),
        { once: true },
      );
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.defer = true;
    script.onload = () => resolve();
    script.onerror = () =>
      reject(new Error('Failed to load Google Identity Services.'));
    document.head.appendChild(script);
  });

  return googleScriptPromise;
}

interface GoogleIdentityButtonProps {
  onCredential: (idToken: string) => void | Promise<void>;
  disabled?: boolean;
  text?: 'signin_with' | 'signup_with' | 'continue_with';
  onError?: (message: string) => void;
}

export const GoogleIdentityButton: React.FC<GoogleIdentityButtonProps> = ({
  onCredential,
  disabled = false,
  text = 'continue_with',
  onError,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const credentialHandlerRef = useRef(onCredential);
  const errorHandlerRef = useRef(onError);
  const [ready, setReady] = useState(false);

  credentialHandlerRef.current = onCredential;
  errorHandlerRef.current = onError;

  useEffect(() => {
    let cancelled = false;

    loadGoogleIdentityServices()
      .then(() => {
        if (cancelled || !containerRef.current || !window.google?.accounts?.id) {
          return;
        }

        const clientId =
          import.meta.env.VITE_GOOGLE_CLIENT_ID || DEFAULT_GOOGLE_WEB_CLIENT_ID;

        window.google.accounts.id.initialize({
          client_id: clientId,
          auto_select: false,
          cancel_on_tap_outside: true,
          callback: (response) => {
            const credential = response.credential?.trim();
            if (!credential) {
              errorHandlerRef.current?.('Google did not return a valid sign-in credential.');
              return;
            }
            void credentialHandlerRef.current(credential);
          },
        });

        containerRef.current.replaceChildren();
        window.google.accounts.id.renderButton(containerRef.current, {
          type: 'standard',
          theme: 'outline',
          size: 'large',
          text,
          shape: 'rectangular',
          width: Math.min(containerRef.current.clientWidth || 400, 400),
          logo_alignment: 'left',
        });
        setReady(true);
      })
      .catch((error) => {
        if (!cancelled) {
          errorHandlerRef.current?.(
            error instanceof Error
              ? error.message
              : 'Google sign-in is currently unavailable.',
          );
        }
      });

    return () => {
      cancelled = true;
    };
  }, [text]);

  return (
    <div
      aria-busy={!ready}
      style={{
        width: '100%',
        minHeight: 44,
        display: 'flex',
        justifyContent: 'center',
        opacity: disabled ? 0.55 : 1,
        pointerEvents: disabled ? 'none' : 'auto',
      }}
    >
      <div ref={containerRef} style={{ width: '100%', maxWidth: 400 }} />
    </div>
  );
};
