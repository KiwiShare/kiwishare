import React, { useState, useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiRequest, UsedItem, ordersApi, OrderItem } from '../api/client';
import { formatPublicTrustScore } from '../utils/trustScore';
import { ProductCard } from '../components/ProductCard';
import { EditItemModal } from '../components/EditItemModal';
import { 
  ShieldCheck, 
  Globe, 
  Smartphone, 
  LogOut, 
  Package, 
  Loader2,
  Edit3,
  ShoppingBag,
  ArrowDownLeft,
  ArrowUpRight,
  MapPin,
  Calendar,
  MessageCircle,
  Clock,
  CheckCircle2,
  AlertCircle
} from 'lucide-react';

export const ProfilePage: React.FC = () => {
  const { user, isLoggedIn, logout } = useAuth();
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<'listings' | 'buying' | 'selling'>('listings');
  const [myItems, setMyItems] = useState<UsedItem[]>([]);
  const [loadingItems, setLoadingItems] = useState<boolean>(true);
  const [editingItem, setEditingItem] = useState<UsedItem | null>(null);

  const [orders, setOrders] = useState<OrderItem[]>([]);
  const [loadingOrders, setLoadingOrders] = useState<boolean>(false);
  const [orderFilter, setOrderFilter] = useState<'all' | 'in_progress' | 'completed'>('all');

  useEffect(() => {
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }

    apiRequest<UsedItem[] | { items?: UsedItem[]; data?: UsedItem[] }>('/users/me/usedItems')
      .then((res) => {
        if (Array.isArray(res)) {
          setMyItems(res);
        } else if (res && Array.isArray(res.items)) {
          setMyItems(res.items);
        } else if (res && Array.isArray(res.data)) {
          setMyItems(res.data);
        } else {
          setMyItems([]);
        }
      })
      .catch(() => {})
      .finally(() => {
        setLoadingItems(false);
      });
  }, [isLoggedIn, navigate]);

  useEffect(() => {
    if (!isLoggedIn || activeTab === 'listings') return;

    setLoadingOrders(true);
    ordersApi.getMyOrders({
      type: activeTab === 'buying' ? 'buying' : 'selling',
      status: orderFilter,
    })
      .then((res) => {
        if (res && res.orders) {
          setOrders(res.orders);
        } else {
          setOrders([]);
        }
      })
      .catch(() => setOrders([]))
      .finally(() => setLoadingOrders(false));
  }, [isLoggedIn, activeTab, orderFilter]);

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
              {formatPublicTrustScore(user.trustScore)}
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

      {/* Marketplace & Orders Tabs */}
      <div style={{ display: 'flex', gap: '12px', borderBottom: '2px solid var(--border-subtle)', marginBottom: '28px', flexWrap: 'wrap' }}>
        <button
          onClick={() => setActiveTab('listings')}
          style={{
            padding: '12px 18px',
            fontSize: '1rem',
            fontWeight: 700,
            border: 'none',
            background: 'none',
            cursor: 'pointer',
            borderBottom: activeTab === 'listings' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'listings' ? 'var(--primary-700)' : 'var(--text-muted)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            marginBottom: '-2px',
          }}
        >
          <Package size={18} />
          <span>My Listed Items</span>
          {myItems.length > 0 && (
            <span style={{ fontSize: '0.75rem', backgroundColor: activeTab === 'listings' ? 'var(--primary-100)' : '#f1f5f9', color: activeTab === 'listings' ? 'var(--primary-800)' : 'var(--text-muted)', padding: '2px 8px', borderRadius: '10px' }}>
              {myItems.length}
            </span>
          )}
        </button>

        <button
          onClick={() => setActiveTab('buying')}
          style={{
            padding: '12px 18px',
            fontSize: '1rem',
            fontWeight: 700,
            border: 'none',
            background: 'none',
            cursor: 'pointer',
            borderBottom: activeTab === 'buying' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'buying' ? 'var(--primary-700)' : 'var(--text-muted)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            marginBottom: '-2px',
          }}
        >
          <ArrowDownLeft size={18} />
          <span>Purchases / Buying (我买过的)</span>
        </button>

        <button
          onClick={() => setActiveTab('selling')}
          style={{
            padding: '12px 18px',
            fontSize: '1rem',
            fontWeight: 700,
            border: 'none',
            background: 'none',
            cursor: 'pointer',
            borderBottom: activeTab === 'selling' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'selling' ? 'var(--primary-700)' : 'var(--text-muted)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            marginBottom: '-2px',
          }}
        >
          <ArrowUpRight size={18} />
          <span>Sales / Selling (我卖出的)</span>
        </button>
      </div>

      {activeTab === 'listings' && (
        <div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
            <div>
              <h2 style={{ fontSize: '1.5rem', fontWeight: 800 }}>My Listed Items</h2>
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
                <div key={item.id || item._id} style={{ display: 'flex', flexDirection: 'column' }}>
                  <ProductCard item={item} />
                  <div style={{ marginTop: '8px', display: 'flex', gap: '8px' }}>
                    <button
                      onClick={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        setEditingItem(item);
                      }}
                      className="btn btn-secondary"
                      style={{
                        flex: 1,
                        padding: '8px 12px',
                        fontSize: '0.85rem',
                        fontWeight: 600,
                        borderRadius: 'var(--radius-md)',
                        backgroundColor: '#fff',
                        boxShadow: 'var(--shadow-sm)'
                      }}
                    >
                      <Edit3 size={15} color="var(--primary-600)" />
                      <span>Edit Listing</span>
                    </button>
                  </div>
                </div>
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
      )}

      {activeTab !== 'listings' && (
        <div className="animate-fade-in">
          {/* Header & Filter Chips */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px', flexWrap: 'wrap', gap: '16px' }}>
            <div>
              <h2 style={{ fontSize: '1.5rem', fontWeight: 800 }}>
                {activeTab === 'buying' ? 'My Purchase Orders (我买过的商品)' : 'My Sales Orders (我卖出的订单)'}
              </h2>
              <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>
                {activeTab === 'buying' ? 'Track ongoing purchases and historical orders' : 'Manage your sales and completed buyer handovers'}
              </p>
            </div>

            {/* Status Filter Chips */}
            <div style={{ display: 'flex', gap: '8px', backgroundColor: '#f1f5f9', padding: '4px', borderRadius: '10px' }}>
              {(['all', 'in_progress', 'completed'] as const).map((filter) => (
                <button
                  key={filter}
                  onClick={() => setOrderFilter(filter)}
                  style={{
                    padding: '6px 14px',
                    fontSize: '0.85rem',
                    fontWeight: 600,
                    border: 'none',
                    borderRadius: '8px',
                    cursor: 'pointer',
                    backgroundColor: orderFilter === filter ? '#fff' : 'transparent',
                    color: orderFilter === filter ? 'var(--primary-700)' : 'var(--text-muted)',
                    boxShadow: orderFilter === filter ? 'var(--shadow-sm)' : 'none',
                    transition: 'all 0.15s ease',
                  }}
                >
                  {filter === 'all' ? 'All Orders' : filter === 'in_progress' ? 'In Progress' : 'Completed'}
                </button>
              ))}
            </div>
          </div>

          {loadingOrders ? (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '60px 0' }}>
              <Loader2 size={32} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
              <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
            </div>
          ) : orders.length > 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              {orders.map((order) => {
                const isCompleted = ['completed', 'qr_scanned', 'seller_paid'].includes(order.status);
                const isInProgress = ['meeting_scheduled', 'meeting_in_progress', 'pending_payment', 'paid', 'transfer_pending'].includes(order.status);

                return (
                  <div
                    key={order.id}
                    className="glass-card"
                    style={{
                      padding: '20px',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: '16px',
                      border: isInProgress ? '1.5px solid var(--primary-300)' : '1px solid var(--border-subtle)',
                      backgroundColor: isInProgress ? '#fafdfb' : '#fff',
                    }}
                  >
                    {/* Top Row: Order Number, Date, Status */}
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px', borderBottom: '1px solid var(--border-subtle)', paddingBottom: '12px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-muted)' }}>
                          Order #{order.orderNumber}
                        </span>
                        <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                          • {new Date(order.createdAt).toLocaleDateString('en-NZ', { month: 'short', day: 'numeric', year: 'numeric' })}
                        </span>
                      </div>

                      {/* Status Badge */}
                      {isCompleted ? (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700, backgroundColor: '#dcfce7', color: '#15803d' }}>
                          <CheckCircle2 size={13} /> Completed
                        </span>
                      ) : isInProgress ? (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700, backgroundColor: '#e0f2fe', color: '#0369a1' }}>
                          <Clock size={13} /> {order.meeting ? 'Meetup Scheduled' : 'In Progress'}
                        </span>
                      ) : (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700, backgroundColor: '#fee2e2', color: '#b91c1c' }}>
                          <AlertCircle size={13} /> {order.status}
                        </span>
                      )}
                    </div>

                    {/* Middle: Item Details & Counterparty */}
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '20px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                        <div
                          style={{
                            width: '64px',
                            height: '64px',
                            borderRadius: '10px',
                            backgroundColor: '#f1f5f9',
                            overflow: 'hidden',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            flexShrink: 0,
                          }}
                        >
                          {order.item.imageUrl ? (
                            <img src={order.item.imageUrl} alt={order.item.title} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                          ) : (
                            <ShoppingBag size={24} color="var(--primary-600)" />
                          )}
                        </div>

                        <div>
                          <Link
                            to={`/products/${order.itemId}`}
                            style={{ fontSize: '1.05rem', fontWeight: 700, color: 'var(--text-main)', textDecoration: 'none' }}
                          >
                            {order.item.title}
                          </Link>
                          <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--primary-700)', marginTop: '4px' }}>
                            ${order.item.priceNzd} NZD
                          </div>
                        </div>
                      </div>

                      {/* Counterparty info */}
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px', backgroundColor: '#f8fafc', padding: '8px 14px', borderRadius: '10px' }}>
                        <div
                          style={{
                            width: '32px',
                            height: '32px',
                            borderRadius: '50%',
                            backgroundColor: 'var(--primary-600)',
                            color: '#fff',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: '0.85rem',
                            fontWeight: 700,
                          }}
                        >
                          {order.counterparty.displayName.charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>
                            {activeTab === 'buying' ? 'Seller' : 'Buyer'}
                          </div>
                          <div style={{ fontSize: '0.9rem', fontWeight: 600, color: 'var(--text-main)' }}>
                            {order.counterparty.displayName}
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* Meetup Information if Scheduled */}
                    {order.meeting && (
                      <div
                        style={{
                          backgroundColor: '#f0fdf4',
                          border: '1px solid #bbf7d0',
                          borderRadius: '10px',
                          padding: '10px 14px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          flexWrap: 'wrap',
                          gap: '10px',
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '16px', flexWrap: 'wrap' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem', color: '#166534', fontWeight: 600 }}>
                            <Calendar size={15} />
                            <span>{new Date(order.meeting.scheduledAt).toLocaleString('en-NZ', { dateStyle: 'medium', timeStyle: 'short' })}</span>
                          </div>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem', color: '#166534', fontWeight: 600 }}>
                            <MapPin size={15} />
                            <span>{order.meeting.locationName}</span>
                          </div>
                        </div>

                        {/* Navigation link */}
                        <a
                          href={
                            order.meeting.latitude && order.meeting.longitude
                              ? `https://www.google.com/maps/dir/?api=1&destination=${order.meeting.latitude},${order.meeting.longitude}`
                              : `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(order.meeting.locationName)}`
                          }
                          target="_blank"
                          rel="noreferrer"
                          style={{
                            fontSize: '0.8rem',
                            fontWeight: 700,
                            color: 'var(--primary-700)',
                            textDecoration: 'none',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '4px',
                          }}
                        >
                          <MapPin size={13} />
                          <span>Google Maps Directions</span>
                        </a>
                      </div>
                    )}

                    {/* Actions */}
                    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', paddingTop: '8px' }}>
                      <Link
                        to="/chat"
                        className="btn btn-secondary"
                        style={{ padding: '6px 14px', fontSize: '0.85rem', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                      >
                        <MessageCircle size={15} />
                        <span>Chat</span>
                      </Link>
                      <Link
                        to={`/products/${order.itemId}`}
                        className="btn btn-primary"
                        style={{ padding: '6px 14px', fontSize: '0.85rem' }}
                      >
                        <span>View Item</span>
                      </Link>
                    </div>
                  </div>
                );
              })}
            </div>
          ) : (
            <div className="empty-state animate-fade-in">
              <div className="empty-state-icon">
                <ShoppingBag size={32} />
              </div>
              <h3 style={{ fontSize: '1.25rem', marginBottom: '6px' }}>
                {activeTab === 'buying' ? 'No purchase records found' : 'No sales orders found'}
              </h3>
              <p style={{ color: 'var(--text-muted)', maxWidth: '380px', margin: '0 auto 20px', fontSize: '0.9rem' }}>
                {activeTab === 'buying'
                  ? 'Items you agreed to purchase and your order history will appear here.'
                  : 'Items that buyers have purchased or scheduled for handover will appear here.'}
              </p>
              <Link to="/" className="btn btn-primary">
                <span>Browse Marketplace</span>
              </Link>
            </div>
          )}
        </div>
      )}

      {editingItem && (
        <EditItemModal
          item={editingItem}
          onClose={() => setEditingItem(null)}
          onUpdated={(updated: UsedItem) => {
            setMyItems((prev) =>
              prev.map((it) => ((it.id || it._id) === (updated.id || updated._id) ? updated : it))
            );
            setEditingItem(null);
          }}
        />
      )}

    </div>
  );
};
