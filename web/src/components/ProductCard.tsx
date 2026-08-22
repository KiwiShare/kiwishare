import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { UsedItem } from '../api/client';
import { useWatchlist } from '../context/WatchlistContext';
import { useAuth } from '../context/AuthContext';
import { Heart, MapPin, Sparkles, Tag } from 'lucide-react';

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

  const displayPrice = item.priceNzd 
    ? `$${item.priceNzd}` 
    : typeof item.price === 'number' 
      ? `$${(item.price / 100).toFixed(0)}` 
      : '$0';

  const imageUrl = item.imageUrl || (item.images && item.images.length > 0 ? item.images[0].url : null) || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=500&auto=format&fit=crop&q=60';

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

        {/* Sustainable Badge */}
        {item.isSustainable && (
          <div
            className="badge badge-sustainable"
            style={{ position: 'absolute', bottom: '10px', left: '10px', backdropFilter: 'blur(4px)' }}
          >
            <Sparkles size={12} /> Sustainable
          </div>
        )}
      </div>

      {/* Content Section */}
      <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', flex: 1 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
          <h3
            style={{
              fontSize: '1.05rem',
              fontWeight: 700,
              lineHeight: 1.3,
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
            }}
          >
            {item.title}
          </h3>
        </div>

        {/* Price Tag */}
        <div style={{ fontSize: '1.35rem', fontWeight: 800, color: 'var(--primary-700)', marginBottom: '10px' }}>
          {displayPrice} <span style={{ fontSize: '0.75rem', fontWeight: 600, color: 'var(--text-muted)' }}>NZD</span>
        </div>

        {/* Metadata Footer */}
        <div style={{ marginTop: 'auto', display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '0.8rem', color: 'var(--text-muted)', paddingTop: '10px', borderTop: '1px solid var(--border-subtle)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <MapPin size={14} color="var(--primary-600)" />
            <span>{item.location?.city || 'Auckland'}</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
            <Tag size={13} />
            <span style={{ textTransform: 'capitalize' }}>{item.category || 'General'}</span>
          </div>
        </div>
      </div>
    </Link>
  );
};
