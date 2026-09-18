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
  MapPin,
  Calendar,
  MessageCircle,
  Clock,
  CheckCircle2,
  AlertCircle,
  Receipt,
  RotateCcw,
  X,
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
  const [invoiceOrder, setInvoiceOrder] = useState<OrderItem | null>(null);
  const [refundingOrderId, setRefundingOrderId] = useState<string | null>(null);

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

  const handleRefund = async (order: OrderItem) => {
    const isSeller = activeTab === 'selling';
    const confirmText = isSeller
      ? `Are you sure you want to refund Order #${order.orderNumber}? The buyer will receive a full refund and your listing will be automatically relisted back to active.`
      : `Claim a full refund for Order #${order.orderNumber}? Since no meetup was agreed within 2 days, funds will be returned and the item relisted.`;

    if (!window.confirm(confirmText)) return;

    try {
      setRefundingOrderId(order.id);
      const res = await ordersApi.refundOrder(order.id, isSeller ? 'Seller initiated refund' : 'Buyer claimed refund after 48 hours without meetup');
      alert(res.message || 'Refund successfully processed!');
      setOrders((prev) =>
        prev.map((o) => (o.id === order.id ? { ...o, status: 'refunded', isRefunded: true } : o))
      );
    } catch (err: any) {
      alert(err.message || 'Failed to process refund.');
    } finally {
      setRefundingOrderId(null);
    }
  };

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

      {/* Tabs */}
      <div style={{ display: 'flex', gap: '12px', borderBottom: '1px solid var(--border-subtle)', marginBottom: '32px' }}>
        <button
          onClick={() => setActiveTab('listings')}
          className={`tab-btn ${activeTab === 'listings' ? 'active' : ''}`}
          style={{
            padding: '12px 20px',
            fontSize: '1rem',
            fontWeight: 700,
            border: 'none',
            background: 'none',
            borderBottom: activeTab === 'listings' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'listings' ? 'var(--primary-700)' : 'var(--text-muted)',
            cursor: 'pointer',
          }}
        >
          My Listings ({myItems.length})
        </button>

        <button
          onClick={() => setActiveTab('buying')}
          className={`tab-btn ${activeTab === 'buying' ? 'active' : ''}`}
          style={{
            padding: '12px 20px',
            fontSize: '1rem',
            fontWeight: 700,
            border: 'none',
            background: 'none',
            borderBottom: activeTab === 'buying' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'buying' ? 'var(--primary-700)' : 'var(--text-muted)',
            cursor: 'pointer',
          }}
        >
          Purchase Orders
        </button>

        <button
          onClick={() => setActiveTab('selling')}
          className={`tab-btn ${activeTab === 'selling' ? 'active' : ''}`}
          style={{
            padding: '12px 20px',
            fontSize: '1rem',
            fontWeight: 700,
            border: 'none',
            background: 'none',
            borderBottom: activeTab === 'selling' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'selling' ? 'var(--primary-700)' : 'var(--text-muted)',
            cursor: 'pointer',
          }}
        >
          Sales Orders
        </button>
      </div>

      {/* Listings Tab */}
      {activeTab === 'listings' && (
        <div>
          {loadingItems ? (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '60px 0' }}>
              <Loader2 size={32} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
              <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
            </div>
          ) : myItems.length > 0 ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(250px, 1fr))', gap: '24px' }}>
              {myItems.map((item) => (
                <div key={item.id || item._id} style={{ position: 'relative' }}>
                  <ProductCard item={item} />
                  <button
                    onClick={(e) => {
                      e.preventDefault();
                      setEditingItem(item);
                    }}
                    className="btn btn-secondary"
                    style={{
                      position: 'absolute',
                      top: '10px',
                      left: '10px',
                      padding: '6px 12px',
                      fontSize: '0.8rem',
                      zIndex: 10,
                      backgroundColor: 'rgba(255, 255, 255, 0.9)',
                      backdropFilter: 'blur(4px)',
                    }}
                  >
                    <Edit3 size={13} />
                    <span>Edit</span>
                  </button>
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
                You haven't listed any second-hand items. Start decluttering your campus dorm or room today!
              </p>
            </div>
          )}
        </div>
      )}

      {/* Orders Tabs (buying / selling) */}
      {activeTab !== 'listings' && (
        <div>
          {/* Sub Filter */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px', flexWrap: 'wrap', gap: '12px' }}>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 800 }}>
              {activeTab === 'buying' ? 'Your Purchases & Handover Tasks' : 'Your Sales & Delivery Tasks'}
            </h2>

            <div style={{ display: 'flex', gap: '6px', backgroundColor: '#f1f5f9', padding: '4px', borderRadius: '10px' }}>
              {(['all', 'in_progress', 'completed'] as const).map((filter) => (
                <button
                  key={filter}
                  onClick={() => setOrderFilter(filter)}
                  style={{
                    padding: '6px 14px',
                    fontSize: '0.82rem',
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
                  {filter === 'all' ? 'All' : filter === 'in_progress' ? 'In Progress' : 'Completed'}
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
                const isPaid = order.status === 'paid' || order.isPaid;
                const isRefunded = order.status === 'refunded' || order.isRefunded;
                const isInProgress = ['meeting_scheduled', 'meeting_in_progress', 'pending_payment', 'paid', 'transfer_pending'].includes(order.status);

                const hoursElapsed = (Date.now() - new Date(order.createdAt).getTime()) / (1000 * 60 * 60);
                const isOver48hUnmet = isPaid && !order.meeting && hoursElapsed >= 48;

                return (
                  <div
                    key={order.id}
                    className="glass-card"
                    style={{
                      padding: '20px',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: '14px',
                      border: isPaid ? '1.5px solid #10b981' : isInProgress ? '1.5px solid var(--primary-300)' : '1px solid var(--border-subtle)',
                      backgroundColor: isPaid ? '#f0fdf4' : isInProgress ? '#fafdfb' : '#fff',
                    }}
                  >
                    {/* 48-Hour Unconfirmed Meetup Warning */}
                    {isOver48hUnmet && !isRefunded && (
                      <div style={{ backgroundColor: '#fffbeb', border: '1px solid #fde68a', borderRadius: '8px', padding: '10px 14px', display: 'flex', alignItems: 'center', gap: '8px', color: '#b45309', fontSize: '0.82rem' }}>
                        <AlertCircle size={16} color="#d97706" style={{ flexShrink: 0 }} />
                        <span><strong>No meetup agreed after 2 days:</strong> You can claim a full refund or message the other party to arrange meeting time.</span>
                      </div>
                    )}

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
                      {isRefunded ? (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700, backgroundColor: '#fee2e2', color: '#991b1b' }}>
                          <RotateCcw size={13} /> REFUNDED
                        </span>
                      ) : isCompleted ? (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700, backgroundColor: '#dcfce7', color: '#15803d' }}>
                          <CheckCircle2 size={13} /> Completed
                        </span>
                      ) : order.status === 'meeting_scheduled' ? (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700, backgroundColor: '#e0f2fe', color: '#0369a1' }}>
                          <Clock size={13} /> Meetup Scheduled
                        </span>
                      ) : isPaid ? (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700, backgroundColor: '#d1fae5', color: '#065f46', border: '1px solid #10b981' }}>
                          <CheckCircle2 size={13} /> PAID · Awaiting Meetup
                        </span>
                      ) : (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: '5px', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700, backgroundColor: '#fef3c7', color: '#b45309' }}>
                          <Clock size={13} /> To Pay
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

                    {/* Actions Row */}
                    <div style={{ display: 'flex', justifyContent: 'flex-end', alignItems: 'center', gap: '10px', paddingTop: '8px', flexWrap: 'wrap' }}>
                      {/* Invoice button */}
                      <button
                        onClick={() => setInvoiceOrder(order)}
                        className="btn btn-secondary"
                        style={{ padding: '6px 14px', fontSize: '0.85rem', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                      >
                        <Receipt size={14} />
                        <span>Invoice</span>
                      </button>

                      {/* Seller Refund Button */}
                      {activeTab === 'selling' && ['paid', 'meeting_scheduled'].includes(order.status) && !isRefunded && (
                        <button
                          onClick={() => handleRefund(order)}
                          disabled={refundingOrderId === order.id}
                          className="btn btn-secondary"
                          style={{ padding: '6px 14px', fontSize: '0.85rem', display: 'inline-flex', alignItems: 'center', gap: '6px', color: '#dc2626', borderColor: '#fca5a5' }}
                        >
                          <RotateCcw size={14} />
                          <span>{refundingOrderId === order.id ? 'Refunding…' : 'Refund Order'}</span>
                        </button>
                      )}

                      {/* Buyer Claim Refund (48h rule) */}
                      {activeTab === 'buying' && isOver48hUnmet && !isRefunded && (
                        <button
                          onClick={() => handleRefund(order)}
                          disabled={refundingOrderId === order.id}
                          className="btn btn-secondary"
                          style={{ padding: '6px 14px', fontSize: '0.85rem', display: 'inline-flex', alignItems: 'center', gap: '6px', color: '#b45309', borderColor: '#fde68a', backgroundColor: '#fffbeb' }}
                        >
                          <RotateCcw size={14} />
                          <span>{refundingOrderId === order.id ? 'Claiming…' : 'Claim Refund (2d Unmet)'}</span>
                        </button>
                      )}

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

      {/* Tax Invoice Modal */}
      {invoiceOrder && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 42, 0.65)',
            backdropFilter: 'blur(6px)',
            zIndex: 300,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '20px',
          }}
          onClick={() => setInvoiceOrder(null)}
        >
          <div
            className="glass-card animate-fade-in"
            style={{
              width: '100%',
              maxWidth: '520px',
              backgroundColor: '#ffffff',
              borderRadius: 'var(--radius-lg)',
              padding: '28px',
              position: 'relative',
              boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.2)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Close */}
            <button
              onClick={() => setInvoiceOrder(null)}
              style={{ position: 'absolute', top: '18px', right: '18px', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}
            >
              <X size={20} />
            </button>

            {/* Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '20px', paddingBottom: '16px', borderBottom: '1px solid var(--border-subtle)' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <Receipt size={22} color="#059669" />
                  <h3 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800 }}>Payment Invoice</h3>
                </div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                  KiwiShare NZ C2C Marketplace
                </div>
              </div>
              <span
                style={{
                  padding: '4px 10px',
                  borderRadius: '6px',
                  fontSize: '0.75rem',
                  fontWeight: 800,
                  letterSpacing: '0.5px',
                  backgroundColor: invoiceOrder.isRefunded || invoiceOrder.status === 'refunded' ? '#fee2e2' : '#d1fae5',
                  color: invoiceOrder.isRefunded || invoiceOrder.status === 'refunded' ? '#991b1b' : '#065f46',
                  border: `1.2px solid ${invoiceOrder.isRefunded || invoiceOrder.status === 'refunded' ? '#ef4444' : '#10b981'}`,
                }}
              >
                {invoiceOrder.isRefunded || invoiceOrder.status === 'refunded' ? 'REFUNDED' : 'PAID'}
              </span>
            </div>

            {/* Metadata Rows */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: 'var(--text-muted)' }}>Invoice Number</span>
                <span style={{ fontWeight: 600, fontFamily: 'monospace' }}>INV-ORD-{invoiceOrder.orderNumber}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: 'var(--text-muted)' }}>Order ID</span>
                <span style={{ fontWeight: 600, fontFamily: 'monospace' }}>{invoiceOrder.id}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: 'var(--text-muted)' }}>Date</span>
                <span style={{ fontWeight: 600 }}>{new Date(invoiceOrder.createdAt).toLocaleDateString('en-NZ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</span>
              </div>
            </div>

            {/* Item Snapshot */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px', backgroundColor: '#f8fafc', borderRadius: '8px', marginBottom: '18px' }}>
              {invoiceOrder.item.imageUrl ? (
                <img src={invoiceOrder.item.imageUrl} alt="" style={{ width: '48px', height: '48px', borderRadius: '6px', objectFit: 'cover' }} />
              ) : (
                <div style={{ width: '48px', height: '48px', borderRadius: '6px', backgroundColor: '#e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <ShoppingBag size={20} color="var(--primary-600)" />
                </div>
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: '0.9rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {invoiceOrder.item.title}
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                  Counterparty: {invoiceOrder.counterparty.displayName}
                </div>
              </div>
              <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>
                ${invoiceOrder.item.priceNzd} NZD
              </div>
            </div>

            {/* Financial Breakdown with 15% NZ GST */}
            {(() => {
              const priceNum = parseFloat(invoiceOrder.item.priceNzd || '0') || 0;
              const feeNum = invoiceOrder.buyerFeeAmountNzd ? parseFloat(invoiceOrder.buyerFeeAmountNzd) : Math.max(1, Math.round(priceNum * 0.05 * 100) / 100);
              const gstNum = feeNum * (3 / 23); // 15% NZ GST included in fee
              const totalNum = invoiceOrder.buyerTotalAmountNzd ? parseFloat(invoiceOrder.buyerTotalAmountNzd) : priceNum + feeNum;

              return (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '0.85rem', borderTop: '1px solid var(--border-subtle)', paddingTop: '12px', marginBottom: '16px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: 'var(--text-muted)' }}>Item Subtotal (Private Sale)</span>
                    <span style={{ fontWeight: 600 }}>${priceNum.toFixed(2)} NZD</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ color: 'var(--text-muted)' }}>Buyer Escrow & Protection</span>
                    <span style={{ fontWeight: 600 }}>${feeNum.toFixed(2)} NZD</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', paddingLeft: '12px', color: '#64748b', fontSize: '0.78rem' }}>
                    <span>  └ Includes 15% NZ GST on platform fee</span>
                    <span>${gstNum.toFixed(2)} NZD</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '1rem', fontWeight: 800, marginTop: '6px', paddingTop: '8px', borderTop: '1px dashed var(--border-subtle)' }}>
                    <span>Total Paid</span>
                    <span style={{ color: '#059669', fontSize: '1.15rem' }}>
                      ${totalNum.toFixed(2)} NZD
                    </span>
                  </div>
                </div>
              );
            })()}

            {/* Guarantee Note */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 12px', backgroundColor: '#f0fdf4', borderRadius: '8px', border: '1px solid #bbf7d0', color: '#166534', fontSize: '0.78rem', marginBottom: '20px' }}>
              <ShieldCheck size={16} color="#16a34a" style={{ flexShrink: 0 }} />
              <span>KiwiShare Campus Escrow Protection Guarantee: Funds held securely until handover.</span>
            </div>

            <button
              onClick={() => setInvoiceOrder(null)}
              className="btn btn-primary"
              style={{ width: '100%', padding: '10px' }}
            >
              Close Invoice
            </button>
          </div>
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
