import React, { useEffect, useMemo, useState } from 'react';
import { ArrowRight, ExternalLink, Smartphone, Store } from 'lucide-react';
import { Link, useParams } from 'react-router-dom';

import { itemsApi, UsedItem } from '../api/client';
import './ShareLinkLandingPage.css';

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
        // The landing page remains usable if the preview request fails.
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
      if (document.hidden) window.clearTimeout(fallbackTimer);
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
  const location =
    item?.location?.city &&
    (item.location.suburb
      ? `${item.location.suburb}, ${item.location.city}`
      : item.location.city);

  const openApp = () => {
    window.location.href = deepLink;
  };

  return (
    <main className="share-landing">
      <section className="share-card" aria-label="KiwiShare shared listing">
        <header className="share-brand">
          <div className="share-brand-mark">
            <img src="/kiwi-mark.png" alt="" aria-hidden="true" />
          </div>
          <div className="share-brand-copy">
            <strong>KiwiShare</strong>
            <span>Local marketplace · safer handover</span>
          </div>
        </header>

        <article className="share-listing">
          <img
            className="share-listing-image"
            src={imageUrl}
            alt={item?.title || 'Shared KiwiShare listing'}
          />
          <div className="share-listing-copy">
            <h2>{item?.title || 'Open this shared listing'}</h2>
            <div className="share-listing-meta">
              {displayPrice && <strong>{displayPrice}</strong>}
              {location && <span>{location}</span>}
            </div>
          </div>
        </article>

        <div className="share-divider" />

        <div className="share-intro">
          <div className="share-app-icon" aria-hidden="true">
            <Smartphone size={22} strokeWidth={2.1} />
          </div>
          <p className="share-eyebrow">CONTINUE IN KIWISHARE</p>
          <h1>Open this listing in the app</h1>
          <p className="share-description">
            Chat with the seller, arrange a meetup, use Safe Pay and complete
            the handover in one place.
          </p>
        </div>

        {checkingApp && (
          <div className="share-checking" role="status">
            Checking whether KiwiShare is installed…
          </div>
        )}

        <div className="share-actions">
          <button type="button" className="share-primary" onClick={openApp}>
            <span>Open KiwiShare</span>
            <ArrowRight size={18} />
          </button>

          <div className="share-store-grid">
            {(platform === 'ios' || platform === 'desktop') && (
              <a
                href={iosAppUrl}
                target="_blank"
                rel="noreferrer"
                className="share-store-button"
              >
                <Store size={18} />
                <span>
                  <small>Download on the</small>
                  App Store
                </span>
              </a>
            )}
            {(platform === 'android' || platform === 'desktop') && (
              <a
                href={androidAppUrl}
                target="_blank"
                rel="noreferrer"
                className="share-store-button"
              >
                <Store size={18} />
                <span>
                  <small>Get it on</small>
                  Google Play
                </span>
              </a>
            )}
          </div>

          <Link to={webPath} className="share-web-button">
            <span>Continue on web</span>
            <ExternalLink size={16} />
          </Link>
        </div>

        <footer className="share-footer">
          Shared securely via <strong>kiwishare.online</strong>
        </footer>
      </section>
    </main>
  );
};
