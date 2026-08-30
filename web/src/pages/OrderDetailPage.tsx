import React, { useState, useEffect, useCallback } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ordersApi, OrderDetailResponse } from '../api/client';
import { 
  ShieldCheck, 
  MapPin, 
  Calendar, 
  Clock, 
  QrCode as QrIcon, 
  CheckCircle, 
  ArrowLeft, 
  Navigation, 
  Check, 
  X, 
  Loader2, 
  Copy
} from 'lucide-react';

export const OrderDetailPage: React.FC = () => {
  const { orderId } = useParams<{ orderId: string }>();

  const [data, setData] = useState<OrderDetailResponse | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  // Seller Verification Modal States
  const [verifyModalOpen, setVerifyModalOpen] = useState<boolean>(false);
  const [inputCode, setInputCode] = useState<string>('');
  const [verifying, setVerifying] = useState<boolean>(false);
  const [verifyError, setVerifyError] = useState<string | null>(null);
  const [verifySuccess, setVerifySuccess] = useState<boolean>(false);
  const [copiedPin, setCopiedPin] = useState<boolean>(false);

  const fetchOrder = useCallback(() => {
    if (!orderId) return;
    setLoading(true);
    ordersApi
      .getOrderById(orderId)
      .then((res) => {
        setData(res);
      })
      .catch((err) => {
        setError(err.message || 'Order not found.');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [orderId]);

  useEffect(() => {
    fetchOrder();
  }, [fetchOrder]);

  if (loading) {
    return (
      <div className="container" style={{ padding: '80px 20px', textAlign: 'center' }}>
        <Loader2 size={36} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite', margin: '0 auto' }} />
        <p style={{ marginTop: '16px', color: 'var(--text-muted)' }}>Loading escrow order details...</p>
      </div>
    );
  }

  if (error || !data || !data.order) {
    return (
      <div className="container" style={{ padding: '80px 20px', textAlign: 'center' }}>
        <h2 style={{ fontSize: '1.75rem', marginBottom: '12px' }}>Order Not Found</h2>
        <p style={{ color: 'var(--text-muted)', marginBottom: '24px' }}>{error || 'Unable to retrieve order.'}</p>
        <Link to="/orders" className="btn btn-primary">Go to My Orders</Link>
      </div>
    );
  }

  const { order, userRole, handover } = data;
  const isBuyer = userRole === 'buyer';
  const isCompleted = order.status === 'completed' || order.status === 'seller_paid';

  const handleVerifyHandover = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputCode.trim()) return;
    setVerifying(true);
    setVerifyError(null);

    try {
      await ordersApi.verifyHandover(order.id || order._id || '', {
        claimCode: inputCode.trim(),
        qrToken: inputCode.trim()
      });
      setVerifySuccess(true);
      setTimeout(() => {
        setVerifyModalOpen(false);
        fetchOrder();
      }, 1500);
    } catch (err: any) {
      setVerifyError(err.message || 'Invalid handover verification code. Please check with the buyer.');
    } finally {
      setVerifying(false);
    }
  };

  const copyPinToClipboard = (pin: string) => {
    navigator.clipboard.writeText(pin);
    setCopiedPin(true);
    setTimeout(() => setCopiedPin(false), 2000);
  };

  const formattedScheduledDate = order.meeting?.scheduledAt
    ? new Date(order.meeting.scheduledAt).toLocaleDateString('en-NZ', {
        weekday: 'short',
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      })
    : 'Tomorrow';

  const formattedScheduledTime = order.meeting?.scheduledAt
    ? new Date(order.meeting.scheduledAt).toLocaleTimeString('en-NZ', {
        hour: '2-digit',
        minute: '2-digit'
      })
    : '2:00 PM';

  return (
    <div className="container" style={{ padding: '32px 20px 80px', maxWidth: '1000px' }}>
      
      {/* Top Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '24px', flexWrap: 'wrap', gap: '16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
          <Link to="/orders" className="btn btn-secondary" style={{ padding: '8px 14px', borderRadius: 'var(--radius-full)' }}>
            <ArrowLeft size={16} />
            <span>Orders</span>
          </Link>
          <div>
            <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
              Order #{order.orderNumber} • Placed {new Date(order.createdAt).toLocaleDateString()}
            </div>
            <h1 style={{ fontSize: '1.6rem', fontWeight: 800, margin: '2px 0 0', color: 'var(--text-main)' }}>
              {isCompleted ? 'Handover Completed & Escrow Released' : 'Escrow Protected Meetup Hub'}
            </h1>
          </div>
        </div>

        {/* Role Badge */}
        <span
          style={{
            backgroundColor: isBuyer ? '#eff6ff' : '#f0fdf4',
            color: isBuyer ? '#1d4ed8' : '#15803d',
            padding: '6px 14px',
            borderRadius: '20px',
            fontSize: '0.85rem',
            fontWeight: 700
          }}
        >
          {isBuyer ? '🛒 YOU ARE BUYER' : '🏪 YOU ARE SELLER'}
        </span>
      </div>

      {/* Escrow Milestone Tracker */}
      <div
        className="glass-card"
        style={{
          padding: '24px',
          borderRadius: '20px',
          backgroundColor: '#ffffff',
          marginBottom: '28px',
          border: '1px solid var(--border-subtle)'
        }}
      >
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px' }}>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '50%', backgroundColor: '#dcfce7', color: '#16a34a', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800 }}>
              <Check size={18} />
            </div>
            <div>
              <div style={{ fontWeight: 700, fontSize: '0.9rem', color: '#1e293b' }}>1. Escrow Deposited</div>
              <div style={{ fontSize: '0.78rem', color: '#16a34a' }}>Funds safely locked</div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ width: '36px', height: '36px', borderRadius: '50%', backgroundColor: '#dcfce7', color: '#16a34a', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800 }}>
              <Check size={18} />
            </div>
            <div>
              <div style={{ fontWeight: 700, fontSize: '0.9rem', color: '#1e293b' }}>2. Safe Zone Scheduled</div>
              <div style={{ fontSize: '0.78rem', color: '#16a34a' }}>{formattedScheduledDate}</div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div
              style={{
                width: '36px',
                height: '36px',
                borderRadius: '50%',
                backgroundColor: isCompleted ? '#dcfce7' : '#fef3c7',
                color: isCompleted ? '#16a34a' : '#b45309',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontWeight: 800
              }}
            >
              {isCompleted ? <Check size={18} /> : '3'}
            </div>
            <div>
              <div style={{ fontWeight: 700, fontSize: '0.9rem', color: '#1e293b' }}>3. QR Code Handover</div>
              <div style={{ fontSize: '0.78rem', color: isCompleted ? '#16a34a' : '#b45309' }}>
                {isCompleted ? 'Verified On-site' : 'Pending in-person scan'}
              </div>
            </div>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div
              style={{
                width: '36px',
                height: '36px',
                borderRadius: '50%',
                backgroundColor: isCompleted ? '#dcfce7' : '#f1f5f9',
                color: isCompleted ? '#16a34a' : '#94a3b8',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontWeight: 800
              }}
            >
              {isCompleted ? <Check size={18} /> : '4'}
            </div>
            <div>
              <div style={{ fontWeight: 700, fontSize: '0.9rem', color: '#1e293b' }}>4. Escrow Payout</div>
              <div style={{ fontSize: '0.78rem', color: isCompleted ? '#16a34a' : '#64748b' }}>
                {isCompleted ? 'Paid to Seller' : 'Released upon QR scan'}
              </div>
            </div>
          </div>

        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '28px' }}>
        
        {/* Left Column: QR Code Handover Pass (Buyer) or Verification Action (Seller) */}
        <div>
          {isCompleted ? (
            <div
              className="glass-card"
              style={{
                padding: '32px',
                borderRadius: '24px',
                backgroundColor: '#ffffff',
                textAlign: 'center',
                border: '1.5px solid #bbf7d0'
              }}
            >
              <div
                style={{
                  width: '64px',
                  height: '64px',
                  borderRadius: '50%',
                  backgroundColor: '#dcfce7',
                  color: '#16a34a',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  margin: '0 auto 16px'
                }}
              >
                <CheckCircle size={36} />
              </div>
              <h3 style={{ fontSize: '1.4rem', fontWeight: 800, color: '#15803d', marginBottom: '8px' }}>
                Transaction Successfully Completed!
              </h3>
              <p style={{ color: '#64748b', fontSize: '0.92rem', lineHeight: 1.6, marginBottom: '20px' }}>
                {isBuyer
                  ? 'The item handover was verified. Thank you for using KiwiShare secure escrow trading!'
                  : 'Escrow payment of $' + (order.sellerReceiveAmount / 100).toFixed(2) + ' NZD has been released to your seller balance.'}
              </p>
              <Link to="/orders" className="btn btn-secondary" style={{ borderRadius: 'var(--radius-full)', padding: '10px 24px' }}>
                View All Orders
              </Link>
            </div>
          ) : isBuyer ? (
            /* Buyer Handover QR Pass */
            <div
              className="glass-card"
              style={{
                padding: '28px',
                borderRadius: '24px',
                backgroundColor: '#ffffff',
                border: '2px solid #bbf7d0',
                textAlign: 'center',
                position: 'relative',
                overflow: 'hidden'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', color: '#16a34a', fontWeight: 700, fontSize: '0.85rem', marginBottom: '8px' }}>
                <ShieldCheck size={18} /> ESCROW HANDOVER PASS
              </div>

              <h3 style={{ fontSize: '1.3rem', fontWeight: 800, color: '#0f172a', marginBottom: '6px' }}>
                Buyer Claim QR Code
              </h3>
              <p style={{ fontSize: '0.85rem', color: '#64748b', marginBottom: '20px' }}>
                Present this QR code or 6-digit PIN to the seller during in-person meetup after inspecting the goods.
              </p>

              {/* QR Code Container */}
              <div
                style={{
                  display: 'inline-block',
                  padding: '20px',
                  backgroundColor: '#f8fafc',
                  borderRadius: '20px',
                  border: '2px dashed #cbd5e1',
                  marginBottom: '20px'
                }}
              >
                {/* SVG Visual QR Code Matrix Simulation */}
                <div
                  style={{
                    width: '180px',
                    height: '180px',
                    backgroundColor: '#ffffff',
                    padding: '12px',
                    borderRadius: '12px',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    position: 'relative'
                  }}
                >
                  <QrIcon size={150} color="#0f172a" />
                </div>
              </div>

              {/* 6-Digit Backup PIN */}
              <div style={{ backgroundColor: '#f1f5f9', borderRadius: '14px', padding: '14px', marginBottom: '16px' }}>
                <div style={{ fontSize: '0.78rem', color: '#64748b', fontWeight: 600, marginBottom: '4px' }}>
                  6-DIGIT VERIFICATION PIN
                </div>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px' }}>
                  <span style={{ fontSize: '1.8rem', fontWeight: 900, letterSpacing: '4px', color: '#0f172a' }}>
                    {handover?.claimCode || order.orderNumber.slice(-6)}
                  </span>
                  <button
                    onClick={() => copyPinToClipboard(handover?.claimCode || order.orderNumber.slice(-6))}
                    style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}
                    title="Copy PIN"
                  >
                    {copiedPin ? <Check size={18} color="#16a34a" /> : <Copy size={18} />}
                  </button>
                </div>
              </div>

              <div style={{ fontSize: '0.78rem', color: '#94a3b8' }}>
                Expires {handover?.expiresAt ? new Date(handover.expiresAt).toLocaleDateString() : 'in 7 days'}
              </div>
            </div>
          ) : (
            /* Seller View: Verification Action Card */
            <div
              className="glass-card"
              style={{
                padding: '28px',
                borderRadius: '24px',
                backgroundColor: '#ffffff',
                border: '2px solid #bfdbfe'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#2563eb', fontWeight: 700, fontSize: '0.85rem', marginBottom: '8px' }}>
                <ShieldCheck size={18} /> ESCROW VERIFICATION
              </div>

              <h3 style={{ fontSize: '1.3rem', fontWeight: 800, color: '#0f172a', marginBottom: '8px' }}>
                Handover Verification
              </h3>
              <p style={{ fontSize: '0.88rem', color: '#64748b', lineHeight: 1.5, marginBottom: '20px' }}>
                The buyer has deposited <strong>${(order.buyerTotalAmount / 100).toFixed(2)} NZD</strong> into KiwiShare Escrow. Meet the buyer, hand over the item, and scan their QR code or enter their 6-digit PIN to release the funds.
              </p>

              <button
                onClick={() => setVerifyModalOpen(true)}
                className="btn btn-primary"
                style={{
                  width: '100%',
                  padding: '16px',
                  borderRadius: 'var(--radius-full)',
                  fontSize: '1rem',
                  fontWeight: 800,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                  cursor: 'pointer',
                  boxShadow: '0 8px 20px rgba(16, 185, 129, 0.3)'
                }}
              >
                <QrIcon size={20} />
                <span>Verify Buyer's QR Code / PIN</span>
              </button>
            </div>
          )}
        </div>

        {/* Right Column: Meetup Location & Order Receipt */}
        <div>
          
          {/* Meetup Details */}
          <div className="glass-card" style={{ padding: '24px', borderRadius: '20px', backgroundColor: '#ffffff', marginBottom: '24px' }}>
            <h3 style={{ fontSize: '1.15rem', fontWeight: 700, marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <MapPin size={18} color="var(--primary-600)" />
              <span>Meetup Location & Schedule</span>
            </h3>

            <div style={{ backgroundColor: '#f8fafc', borderRadius: '14px', padding: '16px', marginBottom: '16px' }}>
              <div style={{ fontWeight: 700, fontSize: '0.98rem', color: '#0f172a', marginBottom: '4px' }}>
                {order.meeting?.locationName || 'Auckland Safe Trading Zone'}
              </div>
              <div style={{ fontSize: '0.85rem', color: '#64748b', marginBottom: '12px' }}>
                {order.meeting?.locationName?.includes('Police') ? 'Official Police Station Safe Meetup Zone' : 'Verified Public Community Spot'}
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '16px', fontSize: '0.85rem', color: '#334155' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Calendar size={14} color="var(--primary-600)" />
                  <span>{formattedScheduledDate}</span>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <Clock size={14} color="var(--primary-600)" />
                  <span>{formattedScheduledTime}</span>
                </div>
              </div>
            </div>

            <a
              href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(order.meeting?.locationName || 'Auckland')}`}
              target="_blank"
              rel="noopener noreferrer"
              className="btn btn-secondary"
              style={{ width: '100%', padding: '10px', borderRadius: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px', fontSize: '0.88rem' }}
            >
              <Navigation size={16} />
              <span>Open in Google Maps</span>
            </a>
          </div>

          {/* Item & Price Receipt */}
          <div className="glass-card" style={{ padding: '24px', borderRadius: '20px', backgroundColor: '#ffffff' }}>
            <h3 style={{ fontSize: '1.15rem', fontWeight: 700, marginBottom: '16px' }}>
              Item & Escrow Receipt
            </h3>

            <div style={{ display: 'flex', gap: '14px', marginBottom: '16px' }}>
              <img
                src={order.itemSnapshot.imageUrl || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=300'}
                alt={order.itemSnapshot.title}
                style={{ width: '64px', height: '64px', borderRadius: '12px', objectFit: 'cover' }}
              />
              <div>
                <div style={{ fontWeight: 700, fontSize: '0.95rem', color: '#0f172a' }}>
                  {order.itemSnapshot.title}
                </div>
                <div style={{ fontSize: '0.8rem', color: '#64748b', marginTop: '2px' }}>
                  Condition: {order.itemSnapshot.condition || 'Good'}
                </div>
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '0.88rem', borderTop: '1px solid var(--border-subtle)', paddingTop: '14px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: '#64748b' }}>
                <span>Item Price</span>
                <span style={{ fontWeight: 600, color: '#0f172a' }}>${(order.itemAmount / 100).toFixed(2)} NZD</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: '#64748b' }}>
                <span>Platform Service Fee (1.0%)</span>
                <span style={{ textDecoration: 'line-through' }}>+${((order.itemAmount * 0.01) / 100).toFixed(2)}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', color: '#16a34a', fontWeight: 600 }}>
                <span>Launch Special (100% OFF)</span>
                <span>-${((order.itemAmount * 0.01) / 100).toFixed(2)}</span>
              </div>
              <div style={{ height: '1px', backgroundColor: 'var(--border-subtle)', margin: '4px 0' }} />
              <div style={{ display: 'flex', justifyContent: 'space-between', fontWeight: 800, fontSize: '1.05rem', color: '#0f172a' }}>
                <span>Total Escrow Deposit</span>
                <span style={{ color: 'var(--primary-700)' }}>${(order.buyerTotalAmount / 100).toFixed(2)} NZD</span>
              </div>
            </div>

          </div>

        </div>

      </div>

      {/* Seller Handover Verification Modal */}
      {verifyModalOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 9999,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            backgroundColor: 'rgba(15, 23, 42, 0.65)',
            backdropFilter: 'blur(8px)',
            padding: '20px'
          }}
          onClick={() => setVerifyModalOpen(false)}
        >
          <div
            className="glass-card"
            style={{
              width: '100%',
              maxWidth: '460px',
              backgroundColor: '#ffffff',
              borderRadius: '24px',
              padding: '32px',
              position: 'relative'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setVerifyModalOpen(false)}
              style={{
                position: 'absolute',
                top: '20px',
                right: '20px',
                background: '#f1f5f9',
                border: 'none',
                borderRadius: '50%',
                width: '36px',
                height: '36px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer'
              }}
            >
              <X size={18} />
            </button>

            {verifySuccess ? (
              <div style={{ textAlign: 'center', padding: '20px 0' }}>
                <div
                  style={{
                    width: '64px',
                    height: '64px',
                    borderRadius: '50%',
                    backgroundColor: '#dcfce7',
                    color: '#16a34a',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    margin: '0 auto 16px'
                  }}
                >
                  <Check size={32} />
                </div>
                <h3 style={{ fontSize: '1.4rem', fontWeight: 800, color: '#0f172a', marginBottom: '8px' }}>
                  Handover Verified!
                </h3>
                <p style={{ color: '#64748b', fontSize: '0.9rem' }}>
                  ${(order.sellerReceiveAmount / 100).toFixed(2)} NZD has been deposited to your balance.
                </p>
              </div>
            ) : (
              <form onSubmit={handleVerifyHandover}>
                <div style={{ textAlign: 'center', marginBottom: '20px' }}>
                  <div
                    style={{
                      width: '56px',
                      height: '56px',
                      borderRadius: '50%',
                      backgroundColor: '#eff6ff',
                      color: '#2563eb',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      margin: '0 auto 12px'
                    }}
                  >
                    <QrIcon size={28} />
                  </div>
                  <h3 style={{ fontSize: '1.35rem', fontWeight: 800, color: '#0f172a', marginBottom: '6px' }}>
                    Verify Buyer's Handover
                  </h3>
                  <p style={{ fontSize: '0.85rem', color: '#64748b' }}>
                    Ask the buyer for their 6-digit PIN or paste their QR code token.
                  </p>
                </div>

                <div style={{ marginBottom: '20px' }}>
                  <input
                    type="text"
                    placeholder="Enter 6-Digit PIN (e.g., 482910)"
                    value={inputCode}
                    onChange={(e) => setInputCode(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '16px',
                      borderRadius: '14px',
                      border: '2px solid var(--border-subtle)',
                      fontSize: '1.3rem',
                      fontWeight: 800,
                      textAlign: 'center',
                      letterSpacing: '3px'
                    }}
                    autoFocus
                    required
                  />
                </div>

                {verifyError && (
                  <div
                    style={{
                      backgroundColor: '#fef2f2',
                      color: '#b91c1c',
                      padding: '12px',
                      borderRadius: '10px',
                      fontSize: '0.85rem',
                      marginBottom: '16px',
                      textAlign: 'center'
                    }}
                  >
                    {verifyError}
                  </div>
                )}

                <button
                  type="submit"
                  disabled={verifying}
                  className="btn btn-primary"
                  style={{
                    width: '100%',
                    padding: '16px',
                    borderRadius: 'var(--radius-full)',
                    fontWeight: 800,
                    fontSize: '1rem',
                    cursor: 'pointer'
                  }}
                >
                  {verifying ? (
                    <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                      <Loader2 size={18} style={{ animation: 'spin 1s linear infinite' }} />
                      Verifying on Blockchain & Escrow...
                    </span>
                  ) : (
                    'Confirm Handover & Release Funds'
                  )}
                </button>
              </form>
            )}

          </div>
        </div>
      )}

    </div>
  );
};
