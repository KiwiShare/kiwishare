import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { UsedItem } from '../api/client';
import { useWatchlist } from '../context/WatchlistContext';
import { useAuth } from '../context/AuthContext';
import { Heart, MapPin, Sparkles, GraduationCap } from 'lucide-react';

interface ProductCardProps {
  item: UsedItem;
}

export const ProductCard: React.FC<ProductCardProps> = ({ item }) => {
  const itemId = item.id || item._id || '';
  const { isWatched, toggleWatch } = useWatchlist();
  const { isLoggedIn } = useAuth();
  const navigate = useNavigate();
  const watched = isWatched(itemId);

  const handleWatchClick = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }
    toggleWatch(item);
  };

  const isFree = item.isFree || item.price === 0 || item.priceNzd === '0' || Number(item.priceNzd) === 0;

  const displayPrice = isFree
    ? 'FREE'
    : item.priceNzd 
      ? `$${item.priceNzd}` 
      : typeof item.price === 'number' 
        ? `$${(item.price / 100).toFixed(0)}` 
        : '$0';

  const imageUrl = item.imageUrl || (item.images && item.images.length > 0 ? item.images[0].url : null) || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=500&auto=format&fit=crop&q=60';

  const seller = item.seller;
  const sellerName = seller?.displayName || 'Kiwi Community Member';
  const isStudent = seller?.isStudentVerified;

  return (
    <Link
      to={`/products/${itemId}`}
      className="glass-card card-hover"
      style={{
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        position: 'relative',
        textDecoration: 'none',
        color: 'inherit',
      }}
    >
      {/* Thumbnail Container */}
      <div style={{ position: 'relative', width: '100%', height: '160px', backgroundColor: '#e2e8f0', overflow: 'hidden' }}>
        <img
          src={imageUrl}
          alt={item.title}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            transition: 'transform 0.3s ease',
          }}
          onError={(e) => {
            (e.currentTarget as HTMLImageElement).src = 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=500&auto=format&fit=crop&q=60';
          }}
        />

        {/* Status Overlay: SOLD / RESERVED */}
        {(item.status === 'sold' || item.status === 'reserved') && (
          <div
            style={{
              position: 'absolute',
              top: '8px',
              left: '8px',
              backgroundColor: 'rgba(15, 23, 42, 0.88)',
              color: '#ffffff',
              fontSize: '0.7rem',
              fontWeight: 800,
              padding: '2px 8px',
              borderRadius: '5px',
              letterSpacing: '0.4px',
              zIndex: 4,
            }}
          >
            {item.status.toUpperCase()}
          </div>
        )}

        {/* Watchlist Toggle Heart Button */}
        <button
          onClick={handleWatchClick}
          aria-label="Save to Watchlist"
          style={{
            position: 'absolute',
            top: '8px',
            right: '8px',
            width: '32px',
            height: '32px',
            borderRadius: '50%',
            backgroundColor: 'rgba(255, 255, 255, 0.92)',
            backdropFilter: 'blur(4px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: 'var(--shadow-md)',
            transition: 'transform 0.15s ease',
            zIndex: 5,
          }}
          onMouseDown={(e) => (e.currentTarget.style.transform = 'scale(0.88)')}
          onMouseUp={(e) => (e.currentTarget.style.transform = 'scale(1)')}
        >
          <Heart
            size={16}
            color={watched ? '#ef4444' : '#64748b'}
            fill={watched ? '#ef4444' : 'none'}
          />
        </button>

        {/* Badges Container */}
        <div style={{ position: 'absolute', bottom: '8px', left: '8px', display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
          {item.isSustainable && (
            <div
              className="badge badge-sustainable"
              style={{ backdropFilter: 'blur(4px)', padding: '2px 6px', fontSize: '0.68rem' }}
            >
              <Sparkles size={10} /> Sustainable
            </div>
          )}

          {isStudent && (
            <div
              style={{
                backgroundColor: 'rgba(30, 58, 138, 0.88)',
                backdropFilter: 'blur(4px)',
                color: '#ffffff',
                fontSize: '0.68rem',
                fontWeight: 700,
                padding: '2px 6px',
                borderRadius: '10px',
                display: 'flex',
                alignItems: 'center',
                gap: '3px',
              }}
            >
              <GraduationCap size={11} color="#93c5fd" /> Student
            </div>
          )}
        </div>
      </div>

      {/* Content Section */}
      <div style={{ padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: '8px', flex: 1 }}>
        <h3
          style={{
            fontSize: '0.96rem',
            fontWeight: 700,
            lineHeight: 1.25,
            margin: 0,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            display: '-webkit-box',
            WebkitLineClamp: 1,
            WebkitBoxOrient: 'vertical',
          }}
        >
          {item.title}
        </h3>

        {/* Price & Condition Horizontal Row */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
          <div>
            {isFree ? (
              <span
                style={{
                  backgroundColor: '#059669',
                  color: '#ffffff',
                  fontWeight: 900,
                  fontSize: '0.8rem',
                  padding: '2px 8px',
                  borderRadius: '4px',
                }}
              >
                FREE
              </span>
            ) : (
              <span style={{ fontSize: '1.22rem', fontWeight: 800, color: 'var(--primary-700)' }}>
                {displayPrice} <span style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)' }}>NZD</span>
              </span>
            )}
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
            {item.condition && (
              <span
                style={{
                  fontSize: '0.72rem',
                  padding: '2px 6px',
                  borderRadius: '4px',
                  backgroundColor: '#f1f5f9',
                  color: '#475569',
                  fontWeight: 600,
                  textTransform: 'capitalize',
                }}
              >
                {item.condition.replace('_', ' ')}
              </span>
            )}
            {(item.watchlistCount ?? item.favouriteCount ?? 0) > 0 && (
              <span style={{ display: 'flex', alignItems: 'center', gap: '2px', color: '#e11d48', fontSize: '0.75rem', fontWeight: 700 }}>
                <Heart size={11} fill="#e11d48" /> {item.watchlistCount ?? item.favouriteCount}
              </span>
            )}
          </div>
        </div>

        {/* Location & Seller Footer Row */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '0.78rem', color: 'var(--text-muted)', paddingTop: '6px', borderTop: '1px solid var(--border-subtle)', marginTop: 'auto' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px', overflow: 'hidden', maxWidth: '58%' }}>
            <MapPin size={12} color="var(--primary-600)" style={{ flexShrink: 0 }} />
            <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {typeof item.location === 'string' ? item.location : item.location?.suburb || item.location?.city || 'Auckland'}
            </span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '5px', flexShrink: 0 }}>
            {seller?.avatarUrl ? (
              <img
                src={seller.avatarUrl}
                alt={sellerName}
                style={{ width: '18px', height: '18px', borderRadius: '50%', objectFit: 'cover' }}
              />
            ) : (
              <div
                style={{
                  width: '18px',
                  height: '18px',
                  borderRadius: '50%',
                  backgroundColor: 'var(--primary-100)',
                  color: 'var(--primary-700)',
                  fontSize: '0.68rem',
                  fontWeight: 700,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                {sellerName.charAt(0).toUpperCase()}
              </div>
            )}
            <span style={{ fontWeight: 600, maxWidth: '75px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
              {sellerName}
            </span>
            {isStudent && (
              <span title="Student Verified" style={{ display: 'inline-flex', alignItems: 'center' }}>
                <GraduationCap size={12} color="#2563eb" />
              </span>
            )}
          </div>
        </div>
      </div>
    </Link>
  );
};
