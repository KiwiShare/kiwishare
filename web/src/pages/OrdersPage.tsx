import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ordersApi, OrderItem } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { 
  ShoppingBag, 
  Store, 
  ChevronRight, 
  Loader2, 
  Package 
} from 'lucide-react';

export const OrdersPage: React.FC = () => {
  const { isLoggedIn } = useAuth();
  const navigate = useNavigate();

  const [activeTab, setActiveTab] = useState<'buying' | 'selling'>('buying');
  const [orders, setOrders] = useState<OrderItem[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }

    setLoading(true);
    setError(null);
    ordersApi
      .getOrders(activeTab)
      .then((res) => {
        setOrders(res.orders || []);
      })
      .catch((err) => {
        setError(err.message || 'Failed to load orders.');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [activeTab, isLoggedIn, navigate]);

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'completed':
      case 'seller_paid':
        return (
          <span style={{ backgroundColor: '#dcfce7', color: '#16a34a', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700 }}>
            COMPLETED
          </span>
        );
      case 'paid':
      case 'meeting_scheduled':
      case 'meeting_in_progress':
        return (
          <span style={{ backgroundColor: '#eff6ff', color: '#2563eb', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700 }}>
            ESCROW SECURED
          </span>
        );
      case 'pending_payment':
        return (
          <span style={{ backgroundColor: '#fef3c7', color: '#b45309', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700 }}>
            PENDING PAYMENT
          </span>
        );
      default:
        return (
          <span style={{ backgroundColor: '#f1f5f9', color: '#64748b', padding: '4px 10px', borderRadius: '12px', fontSize: '0.75rem', fontWeight: 700 }}>
            {status.toUpperCase()}
          </span>
        );
    }
  };

  return (
    <div className="container" style={{ padding: '32px 20px 80px', maxWidth: '900px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '28px' }}>
        <div>
          <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
            My Orders & Escrow Handover
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', margin: '4px 0 0' }}>
            Track in-person meetups, verify QR handover passes, and view payment receipts.
          </p>
        </div>
      </div>

      {/* Tabs */}
      <div
        style={{
          display: 'flex',
          gap: '8px',
          backgroundColor: '#f1f5f9',
          padding: '6px',
          borderRadius: '16px',
          marginBottom: '24px',
          width: 'fit-content'
        }}
      >
        <button
          onClick={() => setActiveTab('buying')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '10px 20px',
            borderRadius: '12px',
            border: 'none',
            backgroundColor: activeTab === 'buying' ? '#ffffff' : 'transparent',
            color: activeTab === 'buying' ? 'var(--primary-700)' : '#64748b',
            fontWeight: 700,
            fontSize: '0.92rem',
            cursor: 'pointer',
            boxShadow: activeTab === 'buying' ? '0 2px 8px rgba(0,0,0,0.06)' : 'none',
            transition: 'all 0.2s'
          }}
        >
          <ShoppingBag size={18} />
          <span>Purchases (Buying)</span>
        </button>

        <button
          onClick={() => setActiveTab('selling')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '10px 20px',
            borderRadius: '12px',
            border: 'none',
            backgroundColor: activeTab === 'selling' ? '#ffffff' : 'transparent',
            color: activeTab === 'selling' ? 'var(--primary-700)' : '#64748b',
            fontWeight: 700,
            fontSize: '0.92rem',
            cursor: 'pointer',
            boxShadow: activeTab === 'selling' ? '0 2px 8px rgba(0,0,0,0.06)' : 'none',
            transition: 'all 0.2s'
          }}
        >
          <Store size={18} />
          <span>Sales (Selling)</span>
        </button>
      </div>

      {/* Orders List */}
      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px 0' }}>
          <Loader2 size={32} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite', margin: '0 auto' }} />
          <p style={{ marginTop: '12px', color: 'var(--text-muted)' }}>Loading {activeTab} orders...</p>
        </div>
      ) : error ? (
        <div className="glass-card" style={{ padding: '24px', textAlign: 'center', color: '#b91c1c' }}>
          {error}
        </div>
      ) : orders.length === 0 ? (
        <div
          className="glass-card"
          style={{
            padding: '60px 20px',
            textAlign: 'center',
            borderRadius: '24px',
            backgroundColor: '#ffffff'
          }}
        >
          <Package size={48} color="#94a3b8" style={{ margin: '0 auto 16px' }} />
          <h3 style={{ fontSize: '1.25rem', fontWeight: 700, color: '#0f172a', marginBottom: '8px' }}>
            No {activeTab === 'buying' ? 'purchases' : 'sales'} yet
          </h3>
          <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '20px' }}>
            {activeTab === 'buying'
              ? 'Find pre-loved sustainable items and purchase with Escrow protection.'
              : 'List an item to start receiving offers with instant handover payouts.'}
          </p>
          <Link to="/" className="btn btn-primary" style={{ borderRadius: 'var(--radius-full)', padding: '10px 24px' }}>
            Explore KiwiShare Items
          </Link>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {orders.map((order) => {
            const orderId = order.id || order._id || '';
            const isCompleted = order.status === 'completed' || order.status === 'seller_paid';
            const counterParty = activeTab === 'buying' ? order.sellerId : order.buyerId;

            return (
              <div
                key={orderId}
                className="glass-card"
                style={{
                  padding: '20px',
                  borderRadius: '20px',
                  backgroundColor: '#ffffff',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  gap: '16px',
                  flexWrap: 'wrap',
                  border: '1px solid var(--border-subtle)',
                  transition: 'all 0.2s',
                  cursor: 'pointer'
                }}
                onClick={() => navigate(`/orders/${orderId}`)}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '16px', flex: 1, minWidth: '280px' }}>
                  <img
                    src={order.itemSnapshot.imageUrl || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=200'}
                    alt={order.itemSnapshot.title}
                    style={{ width: '72px', height: '72px', borderRadius: '14px', objectFit: 'cover', flexShrink: 0 }}
                  />
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
                      <span style={{ fontSize: '0.8rem', color: '#64748b', fontWeight: 600 }}>
                        #{order.orderNumber}
                      </span>
                      {getStatusBadge(order.status)}
                    </div>
                    <div style={{ fontWeight: 800, fontSize: '1.05rem', color: '#0f172a', marginBottom: '4px' }}>
                      {order.itemSnapshot.title}
                    </div>
                    <div style={{ fontSize: '0.82rem', color: '#64748b' }}>
                      {activeTab === 'buying' ? 'Seller' : 'Buyer'}: {counterParty?.displayName || 'Community Member'} • {order.meeting?.locationName || 'Safe Zone'}
                    </div>
                  </div>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '20px', textAlign: 'right' }}>
                  <div>
                    <div style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--primary-700)' }}>
                      ${(activeTab === 'buying' ? order.buyerTotalAmount / 100 : order.sellerReceiveAmount / 100).toFixed(2)} NZD
                    </div>
                    <div style={{ fontSize: '0.78rem', color: '#64748b' }}>
                      {isCompleted ? 'Escrow Released' : 'Held in Escrow'}
                    </div>
                  </div>

                  <Link
                    to={`/orders/${orderId}`}
                    className="btn btn-secondary"
                    style={{ borderRadius: 'var(--radius-full)', padding: '10px 16px', display: 'flex', alignItems: 'center', gap: '4px' }}
                    onClick={(e) => e.stopPropagation()}
                  >
                    <span>View Hub</span>
                    <ChevronRight size={16} />
                  </Link>
                </div>
              </div>
            );
          })}
        </div>
      )}

    </div>
  );
};
