import React, { useEffect, useMemo, useState } from 'react';
import { ArrowRight, Download, ExternalLink, Smartphone } from 'lucide-react';
import { Link, useParams } from 'react-router-dom';

import { itemsApi, UsedItem } from '../api/client';

const DEFAULT_IOS_APP_URL = 'https://apps.apple.com/nz/search?term=KiwiShare';
const DEFAULT_ANDROID_APP_URL =
  'https://play.google.com/store/search?q=KiwiShare&c=apps';

function platformFromUserAgent() {
  if (typeof navigator === 'undefined') return 'desktop';
  const ua = navigator.userAgent;
  if (/iPad|iPhone|iPod/i.test(ua)) return 'ios';
  if (/Android/i.test(ua)) return 'android';
  return 'desktop';
}

export const ShareLinkLandingPage: React.FC = () => {
  const { id = '' } = useParams<{ id: string }>();
  const platform = useMemo(platformFromUserAgent, []);
  const encodedId = encodeURIComponent(id);
  const deepLink = `kiwishare:///items/${encodedId}`;
  const webPath = `/products/${encodedId}`;
  const iosAppUrl =
    import.meta.env.VITE_IOS_APP_URL?.trim() || DEFAULT_IOS_APP_URL;
  const androidAppUrl =
    import.meta.env.VITE_ANDROID_APP_URL?.trim() || DEFAULT_ANDROID_APP_URL;

  const [item, setItem] = useState<UsedItem | null>(null);
  const [checkingApp, setCheckingApp] = useState(platform !== 'desktop');

  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    void itemsApi
      .getItemById(id)
      .then((response) => {
        if (!cancelled) setItem(response.item);
      })
      .catch(() => {
        // The landing page still works when the preview request fails.
      });
    return () => {
      cancelled = true;
    };
  }, [id]);

  useEffect(() => {
    if (!id || platform === 'desktop') {
      setCheckingApp(false);
      return;
    }

    const openTimer = window.setTimeout(() => {
      window.location.href = deepLink;
    }, 180);
    const fallbackTimer = window.setTimeout(() => {
      setCheckingApp(false);
    }, 1450);

    const handleVisibility = () => {
      if (document.hidden) {
        window.clearTimeout(fallbackTimer);
      }
    };
    document.addEventListener('visibilitychange', handleVisibility);

    return () => {
      window.clearTimeout(openTimer);
      window.clearTimeout(fallbackTimer);
      document.removeEventListener('visibilitychange', handleVisibility);
    };
  }, [deepLink, id, platform]);

  const imageUrl =
    item?.images?.[0]?.url || item?.imageUrl || '/kiwi-mark.png';
  const displayPrice =
    item?.isFree || Number(item?.priceNzd || 0) === 0
      ? 'FREE'
      : item?.priceNzd
        ? `$${item.priceNzd} NZD`
        : null;

  const openApp = () => {
    window.location.href = deepLink;
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        background:
          'radial-gradient(circle at 20% 0%, rgba(26, 122, 94, 0.14), transparent 34%), #f7faf8',
        display: 'grid',
        placeItems: 'center',
        padding: '24px',
      }}
    >
      <div
        style={{
          width: 'min(100%, 520px)',
          background: '#ffffff',
          border: '1px solid #dce8e2',
          borderRadius: '28px',
          boxShadow: '0 24px 70px rgba(9, 71, 54, 0.12)',
          padding: '26px',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            marginBottom: '24px',
          }}
        >
          <img
            src="/kiwi-mark.png"
            alt="KiwiShare logo"
            width={46}
            height={46}
            style={{ objectFit: 'contain' }}
          />
          <div>
            <div
              style={{
                fontSize: '1.2rem',
                fontWeight: 850,
                color: '#0b3d31',
                letterSpacing: '-0.02em',
              }}
            >
              KiwiShare
            </div>
            <div style={{ color: '#61756d', fontSize: '0.88rem' }}>
              Buy and sell locally, with a safer handover flow.
            </div>
          </div>
        </div>

        <div
          style={{
            display: 'flex',
            gap: '14px',
            padding: '12px',
            borderRadius: '18px',
            background: '#f3f7f5',
            marginBottom: '22px',
          }}
        >
          <img
            src={imageUrl}
            alt={item?.title || 'Shared KiwiShare listing'}
            width={86}
            height={86}
            style={{
              borderRadius: '14px',
              objectFit: item ? 'cover' : 'contain',
              background: '#e9f1ed',
              flexShrink: 0,
            }}
          />
          <div style={{ minWidth: 0, alignSelf: 'center' }}>
            <div
              style={{
                fontSize: '1rem',
                fontWeight: 760,
                color: '#173c31',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                display: '-webkit-box',
                WebkitLineClamp: 2,
                WebkitBoxOrient: 'vertical',
              }}
            >
              {item?.title || 'Open this shared listing'}
            </div>
            {displayPrice && (
              <div
                style={{
                  marginTop: '8px',
                  color: '#0b7356',
                  fontWeight: 850,
                  fontSize: '1.05rem',
                }}
              >
                {displayPrice}
              </div>
            )}
            {item?.location?.city && (
              <div
                style={{
                  marginTop: '4px',
                  color: '#70827b',
                  fontSize: '0.82rem',
                }}
              >
                {item.location.suburb
                  ? `${item.location.suburb}, ${item.location.city}`
                  : item.location.city}
              </div>
            )}
          </div>
        </div>

        <div style={{ textAlign: 'center', padding: '4px 8px 8px' }}>
          <Smartphone size={28} color="#0b7356" />
          <h1
            style={{
              margin: '10px 0 8px',
              color: '#102f27',
              fontSize: '1.55rem',
              lineHeight: 1.18,
              letterSpacing: '-0.03em',
            }}
          >
            Open this listing in the KiwiShare app
          </h1>
          <p
            style={{
              margin: '0 auto',
              color: '#61756d',
              lineHeight: 1.55,
              maxWidth: '410px',
            }}
          >
            The app gives you the full chat, Safe Pay, meetup and handover
            experience. If KiwiShare is installed, this page will open it
            automatically.
          </p>
        </div>

        {checkingApp && (
          <div
            style={{
              margin: '14px 0',
              padding: '11px 14px',
              borderRadius: '12px',
              background: '#ecf7f2',
              color: '#17644e',
              fontWeight: 700,
              textAlign: 'center',
              fontSize: '0.9rem',
            }}
          >
            Checking for KiwiShare…
          </div>
        )}

        <button
          type="button"
          onClick={openApp}
          style={{
            width: '100%',
            border: 0,
            borderRadius: '14px',
            padding: '13px 16px',
            background: '#0b7356',
            color: '#ffffff',
            fontSize: '0.98rem',
            fontWeight: 800,
            cursor: 'pointer',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px',
          }}
        >
          Open KiwiShare
          <ArrowRight size={18} />
        </button>

        <div
          style={{
            display: 'grid',
            gridTemplateColumns:
              platform === 'desktop' ? '1fr 1fr' : '1fr',
            gap: '10px',
            marginTop: '10px',
          }}
        >
          {(platform === 'ios' || platform === 'desktop') && (
            <a
              href={iosAppUrl}
              target="_blank"
              rel="noreferrer"
              style={storeButtonStyle}
            >
              <Download size={17} />
              Download on the App Store
            </a>
          )}
          {(platform === 'android' || platform === 'desktop') && (
            <a
              href={androidAppUrl}
              target="_blank"
              rel="noreferrer"
              style={storeButtonStyle}
            >
              <Download size={17} />
              Get it for Android
            </a>
          )}
        </div>

        <Link
          to={webPath}
          style={{
            marginTop: '12px',
            minHeight: '46px',
            borderRadius: '14px',
            border: '1px solid #cfded7',
            color: '#244c40',
            textDecoration: 'none',
            fontWeight: 760,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '7px',
          }}
        >
          Continue on web
          <ExternalLink size={17} />
        </Link>

        <div
          style={{
            marginTop: '16px',
            color: '#8a9a94',
            fontSize: '0.75rem',
            textAlign: 'center',
          }}
        >
          Shared securely through kiwishare.online
        </div>
      </div>
    </div>
  );
};

const storeButtonStyle: React.CSSProperties = {
  minHeight: '46px',
  borderRadius: '14px',
  border: '1px solid #cfded7',
  color: '#244c40',
  textDecoration: 'none',
  fontWeight: 740,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  gap: '7px',
  background: '#ffffff',
};
