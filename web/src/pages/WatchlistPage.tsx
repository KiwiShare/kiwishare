import React from 'react';
import { Link } from 'react-router-dom';
import { useWatchlist } from '../context/WatchlistContext';
import { useAuth } from '../context/AuthContext';
import { ProductCard } from '../components/ProductCard';
import { Heart, Sparkles, ArrowRight, Loader2, LogIn } from 'lucide-react';

export const WatchlistPage: React.FC = () => {
  const { isLoggedIn } = useAuth();
  const { watchlistItems, isLoading } = useWatchlist();

  if (!isLoggedIn) {
    return (
      <div className="container" style={{ padding: '80px 20px', textAlign: 'center' }}>
        <div className="empty-state animate-fade-in">
          <div className="empty-state-icon" style={{ backgroundColor: '#fee2e2', color: '#ef4444' }}>
            <Heart size={32} />
          </div>
          <h2 style={{ fontSize: '1.75rem', marginBottom: '8px' }}>Sign in to view your Watchlist</h2>
          <p style={{ color: 'var(--text-muted)', maxWidth: '420px', margin: '0 auto 24px' }}>
            Keep track of all the pre-loved items you love across both your web browser and mobile app in real-time.
          </p>
          <Link to="/login" className="btn btn-primary" style={{ padding: '12px 28px' }}>
            <LogIn size={18} />
            <span>Sign In to KiwiShare</span>
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="container" style={{ padding: '32px 20px 80px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '28px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{
              width: '36px',
              height: '36px',
              borderRadius: '10px',
              backgroundColor: '#fee2e2',
              color: '#ef4444',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}>
              <Heart size={20} fill="#ef4444" />
            </div>
            <h1 style={{ fontSize: '2rem', fontWeight: 800 }}>Saved Watchlist</h1>
          </div>
          <p style={{ color: 'var(--text-muted)', marginTop: '4px', fontSize: '0.95rem' }}>
            {watchlistItems.length} {watchlistItems.length === 1 ? 'item' : 'items'} saved in your community list
          </p>
        </div>

        {watchlistItems.length > 0 && (
          <Link to="/" className="btn btn-secondary">
            <span>Discover More</span>
            <ArrowRight size={16} />
          </Link>
        )}
      </div>

      {isLoading ? (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '80px 0' }}>
          <Loader2 size={36} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
          <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
          <p style={{ marginTop: '16px', color: 'var(--text-muted)' }}>Updating your saved watchlist...</p>
        </div>
      ) : watchlistItems.length > 0 ? (
        <div className="product-grid animate-fade-in">
          {watchlistItems.map((item) => (
            <ProductCard key={item.id || item._id} item={item} />
          ))}
        </div>
      ) : (
        <div className="empty-state animate-fade-in">
          <div className="empty-state-icon" style={{ backgroundColor: '#fee2e2', color: '#ef4444' }}>
            <Heart size={32} />
          </div>
          <h2 style={{ fontSize: '1.4rem', marginBottom: '8px' }}>Your Watchlist is empty</h2>
          <p style={{ color: 'var(--text-muted)', maxWidth: '420px', margin: '0 auto 24px', fontSize: '0.95rem' }}>
            Click the heart icon on any item you're interested in to easily keep tabs on it here!
          </p>
          <Link to="/" className="btn btn-primary">
            <Sparkles size={18} />
            <span>Explore Pre-Loved Items</span>
          </Link>
        </div>
      )}
    </div>
  );
};
