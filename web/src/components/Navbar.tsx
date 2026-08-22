import React, { useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useWatchlist } from '../context/WatchlistContext';
import { PostItemModal } from './PostItemModal';
import { 
  Heart, 
  Search, 
  User as UserIcon, 
  LogOut, 
  PlusCircle, 
  Sparkles,
  Compass,
  ShieldCheck,
  LayoutDashboard
} from 'lucide-react';

export const Navbar: React.FC = () => {
  const { user, isLoggedIn, logout } = useAuth();
  const { watchlistIds } = useWatchlist();
  const navigate = useNavigate();
  const location = useLocation();
  const [searchTerm, setSearchTerm] = useState('');
  const [showDropdown, setShowDropdown] = useState(false);
  const [isPostModalOpen, setIsPostModalOpen] = useState(false);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (searchTerm.trim()) {
      navigate(`/?search=${encodeURIComponent(searchTerm.trim())}`);
    } else {
      navigate('/');
    }
  };

  const handlePostClick = () => {
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }
    setIsPostModalOpen(true);
  };

  const isAdmin = user?.role === 'admin';

  return (
    <>
      <header className="glass-header" style={{ position: 'sticky', top: 0, zIndex: 100 }}>
        <div className="container" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', height: 'var(--header-height)' }}>
          
          {/* Brand Logo */}
          <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: '10px', textDecoration: 'none' }}>
            <div style={{
              width: '42px',
              height: '42px',
              borderRadius: '12px',
              background: 'linear-gradient(135deg, var(--primary-500), var(--primary-700))',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
              boxShadow: 'var(--shadow-primary)'
            }}>
              <Sparkles size={24} />
            </div>
            <div>
              <span style={{ fontSize: '1.4rem', fontWeight: 800, letterSpacing: '-0.5px', color: 'var(--primary-700)' }}>
                Kiwi<span style={{ color: 'var(--primary-500)' }}>Share</span>
              </span>
              <div style={{ fontSize: '0.65rem', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '1px' }}>
                Sustainable NZ
              </div>
            </div>
          </Link>

          {/* Global Search Bar */}
          <form onSubmit={handleSearch} style={{ flex: '1', maxWidth: '400px', margin: '0 20px', position: 'relative' }}>
            <Search size={18} style={{ position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
            <input
              type="text"
              placeholder="Search items, furniture, tech..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="form-input"
              style={{ paddingLeft: '44px', borderRadius: 'var(--radius-full)', backgroundColor: '#f1f5f9', border: '1px solid transparent' }}
            />
          </form>

          {/* Navigation Actions */}
          <nav style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <Link to="/" className="btn btn-secondary" style={{ padding: '8px 14px', borderRadius: 'var(--radius-full)', border: location.pathname === '/' ? '1.5px solid var(--primary-500)' : undefined }}>
              <Compass size={18} color="var(--primary-600)" />
              <span>Explore</span>
            </Link>

            <Link to="/watchlist" className="btn btn-secondary" style={{ position: 'relative', padding: '8px 14px', borderRadius: 'var(--radius-full)' }}>
              <Heart size={18} color={watchlistIds.size > 0 ? '#ef4444' : 'var(--text-muted)'} fill={watchlistIds.size > 0 ? '#ef4444' : 'none'} />
              <span>Watchlist</span>
              {watchlistIds.size > 0 && (
                <span style={{
                  position: 'absolute',
                  top: '-4px',
                  right: '-4px',
                  backgroundColor: '#ef4444',
                  color: '#fff',
                  fontSize: '0.7rem',
                  fontWeight: 700,
                  width: '18px',
                  height: '18px',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  boxShadow: 'var(--shadow-sm)'
                }}>
                  {watchlistIds.size}
                </span>
              )}
            </Link>

            {/* Post Item Action */}
            <button
              onClick={handlePostClick}
              className="btn btn-outline"
              style={{ padding: '8px 14px', borderRadius: 'var(--radius-full)' }}
            >
              <PlusCircle size={18} />
              <span>Post Item</span>
            </button>

            {/* Admin Dashboard Button if role is admin */}
            {isAdmin && (
              <Link
                to="/admin"
                className="btn btn-secondary"
                style={{
                  padding: '8px 14px',
                  borderRadius: 'var(--radius-full)',
                  backgroundColor: '#ecfdf5',
                  borderColor: '#a7f3d0',
                  color: '#047857',
                  fontWeight: 700,
                }}
              >
                <LayoutDashboard size={18} />
                <span>Admin Board</span>
              </Link>
            )}

            {/* User Auth Section */}
            {isLoggedIn && user ? (
              <div style={{ position: 'relative' }}>
                <button
                  onClick={() => setShowDropdown(!showDropdown)}
                  className="btn btn-secondary"
                  style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '6px 14px', borderRadius: 'var(--radius-full)' }}
                >
                  <div style={{
                    width: '28px',
                    height: '28px',
                    borderRadius: '50%',
                    backgroundColor: isAdmin ? '#0f172a' : 'var(--primary-100)',
                    color: isAdmin ? '#34d399' : 'var(--primary-700)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: 700,
                    fontSize: '0.85rem'
                  }}>
                    {user.displayName.charAt(0).toUpperCase()}
                  </div>
                  <span style={{ maxWidth: '100px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {user.displayName}
                  </span>
                </button>

                {/* Dropdown Menu */}
                {showDropdown && (
                  <div
                    className="glass-card animate-fade-in"
                    style={{
                      position: 'absolute',
                      top: 'calc(100% + 8px)',
                      right: 0,
                      width: '210px',
                      padding: '8px',
                      zIndex: 110,
                    }}
                    onMouseLeave={() => setShowDropdown(false)}
                  >
                    <Link
                      to="/profile"
                      onClick={() => setShowDropdown(false)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '10px',
                        padding: '10px 12px',
                        borderRadius: 'var(--radius-sm)',
                        color: 'var(--text-main)',
                        fontWeight: 500,
                        transition: 'background 0.15s'
                      }}
                      onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = 'var(--bg-card-hover)')}
                      onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
                    >
                      <UserIcon size={16} />
                      <span>My Profile</span>
                    </Link>

                    {isAdmin && (
                      <Link
                        to="/admin"
                        onClick={() => setShowDropdown(false)}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '10px',
                          padding: '10px 12px',
                          borderRadius: 'var(--radius-sm)',
                          color: '#047857',
                          fontWeight: 700,
                          backgroundColor: '#ecfdf5',
                          marginBottom: '4px',
                        }}
                      >
                        <ShieldCheck size={16} />
                        <span>Admin Board</span>
                      </Link>
                    )}

                    <button
                      onClick={() => {
                        logout();
                        setShowDropdown(false);
                      }}
                      style={{
                        width: '100%',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '10px',
                        padding: '10px 12px',
                        borderRadius: 'var(--radius-sm)',
                        color: '#ef4444',
                        fontWeight: 500,
                        textAlign: 'left',
                        transition: 'background 0.15s'
                      }}
                      onMouseEnter={(e) => (e.currentTarget.style.backgroundColor = '#fef2f2')}
                      onMouseLeave={(e) => (e.currentTarget.style.backgroundColor = 'transparent')}
                    >
                      <LogOut size={16} />
                      <span>Sign Out</span>
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Link to="/login" className="btn btn-secondary" style={{ padding: '8px 16px', borderRadius: 'var(--radius-full)' }}>
                  Sign In
                </Link>
                <Link to="/register" className="btn btn-primary" style={{ padding: '8px 16px', borderRadius: 'var(--radius-full)' }}>
                  Get Started
                </Link>
              </div>
            )}
          </nav>
        </div>
      </header>

      {/* Global Post Item Modal */}
      <PostItemModal
        isOpen={isPostModalOpen}
        onClose={() => setIsPostModalOpen(false)}
        onItemCreated={() => {
          navigate('/');
          window.location.reload();
        }}
      />
    </>
  );
};
