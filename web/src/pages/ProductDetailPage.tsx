import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { itemsApi, UsedItem } from '../api/client';
import { useWatchlist } from '../context/WatchlistContext';
import { useAuth } from '../context/AuthContext';
import { 
  Heart, 
  MapPin, 
  Sparkles, 
  ShieldCheck, 
  ArrowLeft, 
  Tag, 
  Share2, 
  CheckCircle,
  MessageCircle,
  Loader2,
  ChevronLeft,
  ChevronRight
} from 'lucide-react';

export const ProductDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { isWatched, toggleWatch } = useWatchlist();
  const { isLoggedIn } = useAuth();

  const [item, setItem] = useState<UsedItem | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedImgIndex, setSelectedImgIndex] = useState<number>(0);
  const [claimed, setClaimed] = useState<boolean>(false);

  // Swipe handling state
  const touchStartX = useRef<number | null>(null);
  const touchEndX = useRef<number | null>(null);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    itemsApi
      .getItemById(id)
      .then((res: any) => {
        const product = res.item || res;
        setItem(product);
      })
      .catch((err) => {
        setError(err.message || 'Item not found');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [id]);

  if (loading) {
    return (
      <div className="container" style={{ padding: '80px 20px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <Loader2 size={36} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
        <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
        <p style={{ marginTop: '16px', color: 'var(--text-muted)' }}>Loading item details...</p>
      </div>
    );
  }

  if (error || !item) {
    return (
      <div className="container" style={{ padding: '80px 20px', textAlign: 'center' }}>
        <h2 style={{ fontSize: '1.75rem', marginBottom: '12px' }}>Item Not Found</h2>
        <p style={{ color: 'var(--text-muted)', marginBottom: '24px' }}>The item you are looking for does not exist or has been removed.</p>
        <Link to="/" className="btn btn-primary">
          <ArrowLeft size={18} />
          <span>Back to Explore</span>
        </Link>
      </div>
    );
  }

  const itemId = item.id || item._id || '';
  const watched = isWatched(itemId);

  const imagesList = (item.images && item.images.length > 0)
    ? item.images.map((im) => im.url)
    : [item.imageUrl || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=1000&auto=format&fit=crop&q=80'];

  const displayPrice = item.priceNzd 
    ? `$${item.priceNzd}` 
    : typeof item.price === 'number' 
      ? `$${(item.price / 100).toFixed(0)}` 
      : '$0';

  const handlePrevImage = (e?: React.MouseEvent) => {
    e?.stopPropagation();
    setSelectedImgIndex((prev) => (prev > 0 ? prev - 1 : imagesList.length - 1));
  };

  const handleNextImage = (e?: React.MouseEvent) => {
    e?.stopPropagation();
    setSelectedImgIndex((prev) => (prev < imagesList.length - 1 ? prev + 1 : 0));
  };

  // Touch swipe gestures
  const handleTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.targetTouches[0].clientX;
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    touchEndX.current = e.targetTouches[0].clientX;
  };

  const handleTouchEnd = () => {
    if (!touchStartX.current || !touchEndX.current) return;
    const diff = touchStartX.current - touchEndX.current;
    const minSwipeDistance = 40;

    if (diff > minSwipeDistance) {
      // Swiped Left -> Next Image
      handleNextImage();
    } else if (diff < -minSwipeDistance) {
      // Swiped Right -> Prev Image
      handlePrevImage();
    }

    touchStartX.current = null;
    touchEndX.current = null;
  };

  const handleWatch = () => {
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }
    toggleWatch(item);
  };

  const handleClaim = () => {
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }
    setClaimed(true);
  };

  return (
    <div className="container" style={{ padding: '24px 20px 80px' }}>
      
      {/* Back link */}
      <button
        onClick={() => navigate(-1)}
        className="btn btn-secondary"
        style={{ padding: '8px 16px', borderRadius: 'var(--radius-full)', marginBottom: '24px' }}
      >
        <ArrowLeft size={16} />
        <span>Back to items</span>
      </button>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '48px', alignItems: 'start' }}>
        
        {/* Left Column: Swipeable Multi-Image Gallery */}
        <div>
          {/* Main Image View with Swiping & Controls */}
          <div
            className="glass-card"
            onTouchStart={handleTouchStart}
            onTouchMove={handleTouchMove}
            onTouchEnd={handleTouchEnd}
            style={{
              height: '420px',
              borderRadius: 'var(--radius-xl)',
              overflow: 'hidden',
              position: 'relative',
              marginBottom: '16px',
              backgroundColor: '#e2e8f0',
              userSelect: 'none',
              cursor: imagesList.length > 1 ? 'grab' : 'default',
            }}
          >
            <img
              key={selectedImgIndex}
              src={imagesList[selectedImgIndex] || imagesList[0]}
              alt={`${item.title} photo ${selectedImgIndex + 1}`}
              style={{ width: '100%', height: '100%', objectFit: 'cover', transition: 'opacity 0.25s ease' }}
              onError={(e) => {
                (e.currentTarget as HTMLImageElement).src = 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=1000&auto=format&fit=crop&q=80';
              }}
            />

            {/* Sustainable Badge */}
            {item.isSustainable && (
              <div
                className="badge badge-sustainable"
                style={{ position: 'absolute', top: '16px', left: '16px', backdropFilter: 'blur(8px)' }}
              >
                <Sparkles size={13} /> Sustainable Choice
              </div>
            )}

            {/* Photo Counter Pill */}
            {imagesList.length > 1 && (
              <div
                style={{
                  position: 'absolute',
                  bottom: '16px',
                  right: '16px',
                  backgroundColor: 'rgba(15, 23, 42, 0.75)',
                  backdropFilter: 'blur(6px)',
                  color: '#fff',
                  fontSize: '0.75rem',
                  fontWeight: 700,
                  padding: '4px 10px',
                  borderRadius: '12px',
                }}
              >
                {selectedImgIndex + 1} / {imagesList.length}
              </div>
            )}

            {/* Left & Right Arrow Buttons */}
            {imagesList.length > 1 && (
              <>
                <button
                  type="button"
                  onClick={handlePrevImage}
                  style={{
                    position: 'absolute',
                    top: '50%',
                    left: '12px',
                    transform: 'translateY(-50%)',
                    width: '36px',
                    height: '36px',
                    borderRadius: '50%',
                    backgroundColor: 'rgba(255, 255, 255, 0.85)',
                    backdropFilter: 'blur(4px)',
                    color: 'var(--text-main)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                    boxShadow: '0 2px 6px rgba(0,0,0,0.15)',
                    border: 'none',
                    transition: 'all 0.2s',
                  }}
                  title="Previous image"
                >
                  <ChevronLeft size={20} />
                </button>
                <button
                  type="button"
                  onClick={handleNextImage}
                  style={{
                    position: 'absolute',
                    top: '50%',
                    right: '12px',
                    transform: 'translateY(-50%)',
                    width: '36px',
                    height: '36px',
                    borderRadius: '50%',
                    backgroundColor: 'rgba(255, 255, 255, 0.85)',
                    backdropFilter: 'blur(4px)',
                    color: 'var(--text-main)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                    boxShadow: '0 2px 6px rgba(0,0,0,0.15)',
                    border: 'none',
                    transition: 'all 0.2s',
                  }}
                  title="Next image"
                >
                  <ChevronRight size={20} />
                </button>
              </>
            )}
          </div>

          {/* Thumbnail Strip */}
          {imagesList.length > 1 && (
            <div style={{ display: 'flex', gap: '12px', overflowX: 'auto', paddingBottom: '4px' }}>
              {imagesList.map((url, idx) => (
                <button
                  key={idx}
                  onClick={() => setSelectedImgIndex(idx)}
                  style={{
                    width: '72px',
                    height: '72px',
                    flexShrink: 0,
                    borderRadius: 'var(--radius-md)',
                    overflow: 'hidden',
                    border: selectedImgIndex === idx ? '2px solid var(--primary-600)' : '2px solid transparent',
                    opacity: selectedImgIndex === idx ? 1 : 0.6,
                    transform: selectedImgIndex === idx ? 'scale(1.04)' : 'none',
                    transition: 'all 0.2s ease',
                    cursor: 'pointer',
                  }}
                >
                  <img src={url} alt={`Thumbnail ${idx + 1}`} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Right Column: Information & Actions */}
        <div>
          <div style={{ display: 'flex', gap: '8px', marginBottom: '12px' }}>
            <span className="badge badge-condition" style={{ textTransform: 'capitalize' }}>
              Condition: {item.condition || 'Pre-loved'}
            </span>
            <span className="badge" style={{ backgroundColor: '#e0f2fe', color: '#0369a1' }}>
              <Tag size={12} /> {item.category || 'General'}
            </span>
          </div>

          <h1 style={{ fontSize: '2rem', fontWeight: 800, lineHeight: 1.25, marginBottom: '16px' }}>
            {item.title}
          </h1>

          <div style={{ display: 'flex', alignItems: 'baseline', gap: '12px', marginBottom: '24px' }}>
            <span style={{ fontSize: '2.2rem', fontWeight: 900, color: 'var(--primary-700)' }}>
              {displayPrice}
            </span>
            <span style={{ fontSize: '1rem', color: 'var(--text-muted)' }}>NZD</span>
          </div>

          {/* Location & Trust info */}
          <div
            className="glass-card"
            style={{
              padding: '16px 20px',
              display: 'flex',
              flexDirection: 'column',
              gap: '12px',
              marginBottom: '28px',
              backgroundColor: '#f8fafc',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>
              <MapPin size={18} color="var(--primary-600)" />
              <span>
                Location: <strong style={{ color: 'var(--text-main)' }}>{typeof item.location === 'string' ? item.location : item.location?.city || 'Auckland, New Zealand'}</strong>
              </span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', color: 'var(--text-muted)', fontSize: '0.9rem' }}>
              <ShieldCheck size={18} color="var(--primary-600)" />
              <span>Community verified listing on KiwiShare</span>
            </div>
          </div>

          {/* Description */}
          <div style={{ marginBottom: '32px' }}>
            <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '10px' }}>Description</h3>
            <p style={{ color: 'var(--text-muted)', lineHeight: 1.7, fontSize: '0.95rem' }}>
              {item.description || 'No detailed description provided by the seller.'}
            </p>
          </div>

          {/* Action Buttons */}
          <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
            {claimed ? (
              <div
                className="glass-card"
                style={{
                  flex: 1,
                  padding: '16px',
                  backgroundColor: '#f0fdf4',
                  borderColor: '#bbf7d0',
                  color: '#15803d',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  fontWeight: 600,
                  fontSize: '0.95rem',
                }}
              >
                <CheckCircle size={20} />
                <span>Claim request sent! The seller has been notified.</span>
              </div>
            ) : (
              <button
                onClick={handleClaim}
                className="btn btn-primary"
                style={{ flex: 1, padding: '16px 24px', borderRadius: 'var(--radius-full)', fontSize: '1rem' }}
              >
                <MessageCircle size={18} />
                <span>Contact Seller / Claim</span>
              </button>
            )}

            <button
              onClick={handleWatch}
              className={`btn ${watched ? 'btn-primary' : 'btn-secondary'}`}
              style={{ padding: '16px 24px', borderRadius: 'var(--radius-full)' }}
              title={watched ? 'Remove from Watchlist' : 'Add to Watchlist'}
            >
              <Heart size={20} fill={watched ? 'currentColor' : 'none'} />
              <span>{watched ? 'Watched' : 'Watch'}</span>
            </button>

            <button
              onClick={() => {
                if (navigator.share) {
                  navigator.share({ title: item.title, url: window.location.href });
                } else {
                  navigator.clipboard.writeText(window.location.href);
                  alert('Item link copied to clipboard!');
                }
              }}
              className="btn btn-secondary"
              style={{ padding: '16px', borderRadius: 'var(--radius-full)' }}
              title="Share item"
            >
              <Share2 size={18} />
            </button>
          </div>

        </div>

      </div>

    </div>
  );
};
