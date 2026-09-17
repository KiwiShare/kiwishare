import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { UsedItem } from '../api/client';
import { useWatchlist } from '../context/WatchlistContext';
import { useAuth } from '../context/AuthContext';
import { Heart, MapPin, Sparkles, Tag, GraduationCap, ShieldCheck } from 'lucide-react';

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
      <div style={{ position: 'relative', width: '100%', height: '190px', backgroundColor: '#e2e8f0', overflow: 'hidden' }}>
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

        {/* Watchlist Toggle Heart Button */}
        <button
          onClick={handleWatchClick}
          aria-label="Save to Watchlist"
          style={{
            position: 'absolute',
            top: '10px',
            right: '10px',
            width: '36px',
            height: '36px',
            borderRadius: '50%',
            backgroundColor: 'rgba(255, 255, 255, 0.9)',
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
            size={18}
            color={watched ? '#ef4444' : '#64748b'}
            fill={watched ? '#ef4444' : 'none'}
          />
        </button>

        {/* Badges Container */}
        <div style={{ position: 'absolute', bottom: '10px', left: '10px', display: 'flex', gap: '6px', flexWrap: 'wrap' }}>
          {/* Sustainable Badge */}
          {item.isSustainable && (
            <div
              className="badge badge-sustainable"
              style={{ backdropFilter: 'blur(4px)' }}
            >
              <Sparkles size={11} /> Sustainable
            </div>
          )}

          {/* Student Verified Badge on Photo */}
          {isStudent && (
            <div
              style={{
                backgroundColor: 'rgba(30, 58, 138, 0.85)',
                backdropFilter: 'blur(4px)',
                color: '#ffffff',
                fontSize: '0.7rem',
                fontWeight: 700,
                padding: '3px 8px',
                borderRadius: '12px',
                display: 'flex',
                alignItems: 'center',
                gap: '4px',
                boxShadow: '0 2px 4px rgba(0,0,0,0.15)'
              }}
            >
              <GraduationCap size={12} color="#93c5fd" /> Student Verified
            </div>
          )}
        </div>
      </div>

      {/* Content Section */}
      <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', flex: 1 }}>
        <h3
          style={{
            fontSize: '1.05rem',
            fontWeight: 700,
            lineHeight: 1.3,
            marginBottom: '6px',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            display: '-webkit-box',
            WebkitLineClamp: 2,
            WebkitBoxOrient: 'vertical',
          }}
        >
          {item.title}
        </h3>

        {/* Price Tag */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
          {isFree ? (
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <span
                className="badge"
                style={{
                  backgroundColor: '#059669',
                  color: '#ffffff',
                  fontWeight: 900,
                  fontSize: '0.85rem',
                  padding: '3px 8px',
                  borderRadius: '6px',
                  letterSpacing: '0.5px'
                }}
              >
                FREE
              </span>
              <span style={{ fontSize: '0.9rem', fontWeight: 700, color: '#059669' }}>$0 NZD</span>
            </div>
          ) : (
            <div style={{ fontSize: '1.35rem', fontWeight: 800, color: 'var(--primary-700)' }}>
              {displayPrice} <span style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)' }}>NZD</span>
            </div>
          )}
        </div>

        {/* Seller Info Row */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
          {seller?.avatarUrl ? (
            <img
              src={seller.avatarUrl}
              alt={sellerName}
              style={{ width: '24px', height: '24px', borderRadius: '50%', objectFit: 'cover' }}
            />
          ) : (
            <div
              style={{
                width: '24px',
                height: '24px',
                borderRadius: '50%',
                backgroundColor: 'var(--primary-100)',
                color: 'var(--primary-700)',
                fontSize: '0.75rem',
                fontWeight: 700,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}
            >
              {sellerName.charAt(0).toUpperCase()}
            </div>
          )}
          <span
            style={{
              fontSize: '0.8rem',
              fontWeight: 600,
              color: 'var(--text-main)',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              maxWidth: '140px'
            }}
          >
            {sellerName}
          </span>
          {isStudent && (
            <span title="Verified Student Seller">
              <GraduationCap size={14} color="#2563eb" />
            </span>
          )}
          {seller?.isVerified && !isStudent && (
            <span title="Verified KiwiShare Seller">
              <ShieldCheck size={14} color="var(--primary-600)" />
            </span>
          )}
        </div>

        {/* Metadata Footer */}
        <div style={{ marginTop: 'auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '0.8rem', color: 'var(--text-muted)', paddingTop: '10px', borderTop: '1px solid var(--border-subtle)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <MapPin size={14} color="var(--primary-600)" />
            <span>{typeof item.location === 'string' ? item.location : item.location?.city || 'Auckland'}</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            {(item.watchlistCount ?? item.favouriteCount ?? 0) > 0 && (
              <span style={{ display: 'flex', alignItems: 'center', gap: '3px', color: '#e11d48', fontWeight: 600 }} title="Watchlist count">
                <Heart size={12} fill="#e11d48" /> {item.watchlistCount ?? item.favouriteCount}
              </span>
            )}
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
              <Tag size={13} />
              <span style={{ textTransform: 'capitalize' }}>{item.category || 'General'}</span>
            </div>
          </div>
        </div>
      </div>
    </Link>
  );
};
