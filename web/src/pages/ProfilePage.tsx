import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiRequest, UsedItem } from '../api/client';
import { ProductCard } from '../components/ProductCard';
import { 
  User, 
  ShieldCheck, 
  Globe, 
  Smartphone, 
  Clock, 
  LogOut, 
  Package, 
  PlusCircle, 
  Loader2 
} from 'lucide-react';

export const ProfilePage: React.FC = () => {
  const { user, isLoggedIn, logout } = useAuth();
  const navigate = useNavigate();
  const [myItems, setMyItems] = useState<UsedItem[]>([]);
  const [loadingItems, setLoadingItems] = useState<boolean>(true);

  useEffect(() => {
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }

    apiRequest<{ status: string; items: UsedItem[] }>('/users/me/usedItems')
      .then((res) => {
        setMyItems(res.items || []);
      })
      .catch(() => {})
      .finally(() => {
        setLoadingItems(false);
      });
  }, [isLoggedIn, navigate]);

  if (!user) {
    return null;
  }

  const formatPlatformName = (platform?: string) => {
    switch (platform) {
      case 'web':
        return { label: 'Web Browser (React)', icon: Globe };
      case 'mobile_ios':
        return { label: 'iOS App (Flutter)', icon: Smartphone };
      case 'mobile_android':
        return { label: 'Android App (Flutter)', icon: Smartphone };
      case 'mobile':
        return { label: 'Mobile App', icon: Smartphone };
      default:
        return { label: 'Web Platform', icon: Globe };
    }
  };

  const regPlatform = formatPlatformName(user.registrationPlatform);
  const lastPlatform = formatPlatformName(user.lastUsedPlatform);
  const RegIcon = regPlatform.icon;
  const LastIcon = lastPlatform.icon;

  return (
    <div className="container" style={{ padding: '32px 20px 80px' }}>
      
      {/* Profile Overview Card */}
      <div className="glass-card animate-fade-in" style={{ padding: '36px', marginBottom: '40px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '20px' }}>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
            <div
              style={{
                width: '72px',
                height: '72px',
                borderRadius: '50%',
                background: 'linear-gradient(135deg, var(--primary-500), var(--primary-700))',
                color: '#fff',
                fontSize: '1.8rem',
                fontWeight: 800,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                boxShadow: 'var(--shadow-primary)',
              }}
            >
              {user.displayName.charAt(0).toUpperCase()}
            </div>

            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <h1 style={{ fontSize: '1.8rem', fontWeight: 800 }}>{user.displayName}</h1>
                <ShieldCheck size={20} color="var(--primary-600)" />
              </div>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>{user.email}</p>
            </div>
          </div>

          <button
            onClick={() => {
              logout();
              navigate('/login');
            }}
            className="btn btn-secondary"
            style={{ color: '#ef4444', borderColor: '#fca5a5' }}
          >
            <LogOut size={16} />
            <span>Sign Out</span>
          </button>

        </div>

        {/* User Badges & Platform Metadata */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', marginTop: '28px', paddingTop: '24px', borderTop: '1px solid var(--border-subtle)' }}>
          
          {/* Trust Score */}
          <div style={{ backgroundColor: 'var(--primary-50)', padding: '16px', borderRadius: 'var(--radius-md)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--primary-800)', fontWeight: 700, textTransform: 'uppercase' }}>
              Trust Score
            </div>
            <div style={{ fontSize: '1.4rem', fontWeight: 800, color: 'var(--primary-700)', marginTop: '4px' }}>
              {user.trustScore}% <span style={{ fontSize: '0.85rem', fontWeight: 600 }}>Verified</span>
            </div>
          </div>

          {/* Registration Platform */}
          <div style={{ backgroundColor: '#f1f5f9', padding: '16px', borderRadius: 'var(--radius-md)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>
              Registered Platform
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '1rem', fontWeight: 700, color: 'var(--text-main)', marginTop: '6px' }}>
              <RegIcon size={16} color="var(--primary-600)" />
              <span>{regPlatform.label}</span>
            </div>
          </div>

          {/* Last Used Platform */}
          <div style={{ backgroundColor: '#f1f5f9', padding: '16px', borderRadius: 'var(--radius-md)' }}>
            <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>
              Last Active Platform
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '1rem', fontWeight: 700, color: 'var(--text-main)', marginTop: '6px' }}>
              <LastIcon size={16} color="var(--primary-600)" />
              <span>{lastPlatform.label}</span>
            </div>
          </div>

        </div>

      </div>

      {/* User's Listed Items */}
      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
          <div>
            <h2 style={{ fontSize: '1.6rem', fontWeight: 800 }}>My Listed Items</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>Items you've shared with the NZ community</p>
          </div>
        </div>

        {loadingItems ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '60px 0' }}>
            <Loader2 size={32} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
            <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
          </div>
        ) : myItems.length > 0 ? (
          <div className="product-grid animate-fade-in">
            {myItems.map((item) => (
              <ProductCard key={item.id || item._id} item={item} />
            ))}
          </div>
        ) : (
          <div className="empty-state animate-fade-in">
            <div className="empty-state-icon">
              <Package size={32} />
            </div>
            <h3 style={{ fontSize: '1.25rem', marginBottom: '6px' }}>No items listed yet</h3>
            <p style={{ color: 'var(--text-muted)', maxWidth: '380px', margin: '0 auto 20px', fontSize: '0.9rem' }}>
              Have furniture, tech, or gear you no longer use? List them to declutter and help a neighbor.
            </p>
            <Link to="/" className="btn btn-primary">
              <span>Explore Marketplace</span>
            </Link>
          </div>
        )}
      </div>

    </div>
  );
};
