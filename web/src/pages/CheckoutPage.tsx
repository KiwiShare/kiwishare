import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { itemsApi, ordersApi, UsedItem, SafeZone } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { 
  ShieldCheck, 
  MapPin, 
  Calendar, 
  Clock, 
  CreditCard, 
  Lock, 
  ArrowLeft, 
  Sparkles, 
  Loader2, 
  Info
} from 'lucide-react';

export const CheckoutPage: React.FC = () => {
  const { itemId } = useParams<{ itemId: string }>();
  const navigate = useNavigate();
  const { user, isLoggedIn } = useAuth();

  const [item, setItem] = useState<UsedItem | null>(null);
  const [safeZones, setSafeZones] = useState<SafeZone[]>([]);
  const [selectedSafeZoneId, setSelectedSafeZoneId] = useState<string>('safe-zone-akl-police');
  const [customAddress, setCustomAddress] = useState<string>('');
  const [isCustomLocation, setIsCustomLocation] = useState<boolean>(false);
  const [scheduledDate, setScheduledDate] = useState<string>(() => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    return tomorrow.toISOString().split('T')[0];
  });
  const [scheduledTime, setScheduledTime] = useState<string>('14:00');

  // Payment Form States
  const [cardNumber, setCardNumber] = useState<string>('•••• •••• •••• 4242');
  const [cardExpiry, setCardExpiry] = useState<string>('12/28');
  const [cardCvc, setCardCvc] = useState<string>('123');
  const [nameOnCard, setNameOnCard] = useState<string>(user?.displayName || 'Kiwi Member');

  const [loading, setLoading] = useState<boolean>(true);
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }
    if (!itemId) return;

    setLoading(true);
    Promise.all([
      itemsApi.getItemById(itemId),
      ordersApi.getSafeZones().catch(() => ({ data: [] }))
    ])
      .then(([itemRes, safeZonesRes]: [any, any]) => {
        const product = itemRes.item || itemRes;
        setItem(product);
        const zones = safeZonesRes.data || [];
        setSafeZones(zones);
        if (zones.length > 0) {
          setSelectedSafeZoneId(zones[0].id);
        }
      })
      .catch((err) => {
        setError(err.message || 'Failed to load checkout details.');
      })
      .finally(() => {
        setLoading(false);
      });
  }, [itemId, isLoggedIn, navigate]);

  if (loading) {
    return (
      <div className="container" style={{ padding: '80px 20px', textAlign: 'center' }}>
        <Loader2 size={36} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite', margin: '0 auto' }} />
        <p style={{ marginTop: '16px', color: 'var(--text-muted)' }}>Preparing secure checkout...</p>
      </div>
    );
  }

  if (error || !item) {
    return (
      <div className="container" style={{ padding: '80px 20px', textAlign: 'center' }}>
        <h2 style={{ fontSize: '1.75rem', marginBottom: '12px' }}>Checkout Unavailable</h2>
        <p style={{ color: 'var(--text-muted)', marginBottom: '24px' }}>{error || 'Item not found.'}</p>
        <Link to="/" className="btn btn-primary">Back to Explore</Link>
      </div>
    );
  }

  const rawItemPrice = typeof item.price === 'number' && item.price > 0
    ? item.price / 100
    : parseFloat(item.priceNzd || '0');

  const standardFee = +(rawItemPrice * 0.01).toFixed(2);
  const feeDiscount = standardFee; // 100% Launch Early-Bird Waiver
  const buyerTotal = rawItemPrice;

  const selectedZone = safeZones.find((z) => z.id === selectedSafeZoneId);

  const handleSubmitOrder = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      const meetingLocation = isCustomLocation
        ? {
            name: customAddress || 'Custom Meetup Address',
            address: customAddress,
          }
        : {
            name: selectedZone?.name || 'Auckland Central Police Station Safe Trading Zone',
            address: selectedZone?.address,
            latitude: selectedZone?.latitude,
            longitude: selectedZone?.longitude,
          };

      const scheduledAt = `${scheduledDate}T${scheduledTime}:00`;

      // 1. Create Checkout Order
      const checkoutRes = await ordersApi.checkout({
        itemId: item.id || item._id || '',
        meetingLocation,
        scheduledAt,
      });

      const orderId = (checkoutRes.order?.id || checkoutRes.order?._id || '') as string;
      if (!orderId) {
        throw new Error('Failed to create order ID.');
      }

      // 2. Authorize & Escrow Payment via Stripe.js Escrow Service
      await ordersApi.payOrder(orderId, {
        stripePaymentIntentId: checkoutRes.clientSecret,
      });

      // 3. Navigate to Order Detail Page
      navigate(`/orders/${orderId}`);
    } catch (err: any) {
      setError(err.message || 'Payment authorization failed. Please try again.');
      setSubmitting(false);
    }
  };

  return (
    <div className="container" style={{ padding: '32px 20px 80px', maxWidth: '1100px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '28px' }}>
        <button
          onClick={() => navigate(-1)}
          className="btn btn-secondary"
          style={{ padding: '8px 16px', borderRadius: 'var(--radius-full)' }}
        >
          <ArrowLeft size={16} />
          <span>Back</span>
        </button>
        <div>
          <h1 style={{ fontSize: '1.85rem', fontWeight: 800, margin: 0, color: 'var(--text-main)' }}>
            Secure Escrow Checkout
          </h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', margin: '4px 0 0' }}>
            Funds are locked in KiwiShare Escrow until in-person QR handover verification.
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmitOrder}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))', gap: '32px' }}>
          
          {/* Left Column: Meetup Location & Scheduling */}
          <div>
            
            {/* Step 1: Safe Meetup Zone */}
            <div className="glass-card" style={{ padding: '24px', borderRadius: '20px', marginBottom: '24px', backgroundColor: '#ffffff' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
                <div style={{ width: '28px', height: '28px', borderRadius: '50%', backgroundColor: 'var(--primary-600)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: '0.85rem' }}>
                  1
                </div>
                <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0 }}>
                  Select Meetup Location
                </h3>
              </div>

              <p style={{ fontSize: '0.88rem', color: 'var(--text-muted)', marginBottom: '16px' }}>
                Choose an official Safe Trading Zone (24/7 CCTV & Security Monitored) or specify a custom spot.
              </p>

              {/* Safe Zone Cards */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginBottom: '16px' }}>
                {safeZones.map((zone) => {
                  const isSelected = !isCustomLocation && selectedSafeZoneId === zone.id;
                  return (
                    <div
                      key={zone.id}
                      onClick={() => {
                        setIsCustomLocation(false);
                        setSelectedSafeZoneId(zone.id);
                      }}
                      style={{
                        padding: '16px',
                        borderRadius: '16px',
                        border: isSelected ? '2px solid var(--primary-600)' : '1px solid var(--border-subtle)',
                        backgroundColor: isSelected ? '#f0fdf4' : '#fafafa',
                        cursor: 'pointer',
                        transition: 'all 0.2s'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '6px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <ShieldCheck size={18} color={isSelected ? '#16a34a' : 'var(--primary-600)'} />
                          <span style={{ fontWeight: 700, fontSize: '0.95rem', color: 'var(--text-main)' }}>
                            {zone.name}
                          </span>
                        </div>
                        {isSelected && (
                          <span style={{ backgroundColor: '#dcfce7', color: '#16a34a', fontSize: '0.75rem', fontWeight: 700, padding: '2px 8px', borderRadius: '10px' }}>
                            SELECTED
                          </span>
                        )}
                      </div>
                      <div style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginBottom: '8px', paddingLeft: '26px' }}>
                        {zone.address}
                      </div>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px', paddingLeft: '26px' }}>
                        {zone.features.slice(0, 2).map((feat, idx) => (
                          <span key={idx} style={{ backgroundColor: '#f1f5f9', color: '#475569', fontSize: '0.72rem', padding: '2px 8px', borderRadius: '6px' }}>
                            ✓ {feat}
                          </span>
                        ))}
                      </div>
                    </div>
                  );
                })}

                {/* Custom Address Option */}
                <div
                  onClick={() => setIsCustomLocation(true)}
                  style={{
                    padding: '16px',
                    borderRadius: '16px',
                    border: isCustomLocation ? '2px solid var(--primary-600)' : '1px solid var(--border-subtle)',
                    backgroundColor: isCustomLocation ? '#f0fdf4' : '#fafafa',
                    cursor: 'pointer',
                    transition: 'all 0.2s'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '8px' }}>
                    <MapPin size={18} color={isCustomLocation ? '#16a34a' : '#64748b'} />
                    <span style={{ fontWeight: 700, fontSize: '0.95rem' }}>Custom Public Meetup Spot</span>
                  </div>
                  {isCustomLocation && (
                    <input
                      type="text"
                      placeholder="e.g., Starbucks Queen Street or Auckland Domain Cafe"
                      value={customAddress}
                      onChange={(e) => setCustomAddress(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '10px 14px',
                        borderRadius: '10px',
                        border: '1px solid var(--border-subtle)',
                        fontSize: '0.9rem',
                        marginTop: '8px'
                      }}
                      onClick={(e) => e.stopPropagation()}
                    />
                  )}
                </div>
              </div>

            </div>

            {/* Step 2: Date & Time */}
            <div className="glass-card" style={{ padding: '24px', borderRadius: '20px', backgroundColor: '#ffffff' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
                <div style={{ width: '28px', height: '28px', borderRadius: '50%', backgroundColor: 'var(--primary-600)', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: '0.85rem' }}>
                  2
                </div>
                <h3 style={{ fontSize: '1.2rem', fontWeight: 700, margin: 0 }}>
                  Meetup Schedule
                </h3>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '6px' }}>
                    <Calendar size={14} /> Meetup Date
                  </label>
                  <input
                    type="date"
                    value={scheduledDate}
                    onChange={(e) => setScheduledDate(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '10px',
                      border: '1px solid var(--border-subtle)',
                      fontSize: '0.9rem'
                    }}
                  />
                </div>
                <div>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '6px' }}>
                    <Clock size={14} /> Estimated Time
                  </label>
                  <input
                    type="time"
                    value={scheduledTime}
                    onChange={(e) => setScheduledTime(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '10px 14px',
                      borderRadius: '10px',
                      border: '1px solid var(--border-subtle)',
                      fontSize: '0.9rem'
                    }}
                  />
                </div>
              </div>
            </div>

          </div>

          {/* Right Column: Order Summary & Stripe.js Escrow Payment */}
          <div>
            
            <div className="glass-card" style={{ padding: '24px', borderRadius: '24px', backgroundColor: '#ffffff', border: '1px solid var(--border-subtle)', position: 'sticky', top: '24px' }}>
              
              <h3 style={{ fontSize: '1.25rem', fontWeight: 800, marginBottom: '20px' }}>
                Order Summary & Payment
              </h3>

              {/* Item Snapshot Card */}
              <div style={{ display: 'flex', gap: '14px', paddingBottom: '20px', borderBottom: '1px solid var(--border-subtle)', marginBottom: '20px' }}>
                <img
                  src={item.imageUrl || (item.images && item.images[0]?.url) || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=300'}
                  alt={item.title}
                  style={{ width: '80px', height: '80px', borderRadius: '12px', objectFit: 'cover' }}
                />
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-main)', marginBottom: '4px' }}>
                    {item.title}
                  </div>
                  <div style={{ fontSize: '0.82rem', color: 'var(--text-muted)', marginBottom: '6px' }}>
                    Seller: {item.seller?.displayName || 'Community Member'}
                  </div>
                  <div style={{ fontSize: '1.1rem', fontWeight: 800, color: 'var(--primary-700)' }}>
                    ${rawItemPrice.toFixed(2)} NZD
                  </div>
                </div>
              </div>

              {/* Fee Breakdown Engine */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginBottom: '20px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.92rem', color: 'var(--text-muted)' }}>
                  <span>Item Subtotal</span>
                  <span style={{ fontWeight: 600, color: 'var(--text-main)' }}>${rawItemPrice.toFixed(2)} NZD</span>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.92rem', color: 'var(--text-muted)' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                    Buyer Platform Service Fee (1.0%)
                    <Info size={13} color="#94a3b8" />
                  </span>
                  <span style={{ textDecoration: 'line-through', color: '#94a3b8' }}>+${standardFee.toFixed(2)}</span>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.92rem', color: '#16a34a' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '4px', fontWeight: 600 }}>
                    <Sparkles size={14} /> Early-Bird Launch Special (100% OFF)
                  </span>
                  <span style={{ fontWeight: 700 }}>-${feeDiscount.toFixed(2)}</span>
                </div>

                <div style={{ height: '1px', backgroundColor: 'var(--border-subtle)', margin: '6px 0' }} />

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
                  <span style={{ fontWeight: 800, fontSize: '1.1rem', color: 'var(--text-main)' }}>Total Escrow Deposit</span>
                  <span style={{ fontWeight: 900, fontSize: '1.6rem', color: 'var(--primary-700)' }}>
                    ${buyerTotal.toFixed(2)} <span style={{ fontSize: '0.85rem', fontWeight: 600 }}>NZD</span>
                  </span>
                </div>

                {/* Seller Payout Guarantee Notice */}
                <div style={{ backgroundColor: '#f8fafc', borderRadius: '10px', padding: '10px 12px', fontSize: '0.78rem', color: '#475569', marginTop: '4px' }}>
                  💡 <strong>Seller Net Payout:</strong> ${rawItemPrice.toFixed(2)} NZD (0% seller fee with Launch Waiver / Turbo Boost guarantee).
                </div>
              </div>

              {/* Escrow Shield Guarantee Banner */}
              <div
                style={{
                  backgroundColor: '#f0fdf4',
                  border: '1.5px solid #bbf7d0',
                  borderRadius: '14px',
                  padding: '14px',
                  display: 'flex',
                  gap: '12px',
                  alignItems: 'flex-start',
                  marginBottom: '24px'
                }}
              >
                <ShieldCheck size={24} color="#16a34a" style={{ flexShrink: 0, marginTop: '2px' }} />
                <div style={{ fontSize: '0.82rem', color: '#15803d', lineHeight: 1.5 }}>
                  <strong>KiwiShare Escrow Protection:</strong> Funds are safely escrowed. The seller receives payment only after you inspect the item and scan the Handover QR Code on-site.
                </div>
              </div>

              {/* Stripe.js Card Elements Form */}
              <div style={{ marginBottom: '20px' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '12px' }}>
                  <label style={{ fontSize: '0.88rem', fontWeight: 700, color: 'var(--text-main)' }}>
                    Stripe Payment Method
                  </label>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '0.75rem', color: '#64748b' }}>
                    <Lock size={12} /> 256-bit Encrypted
                  </span>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  <input
                    type="text"
                    placeholder="Name on card"
                    value={nameOnCard}
                    onChange={(e) => setNameOnCard(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '12px 14px',
                      borderRadius: '10px',
                      border: '1px solid var(--border-subtle)',
                      fontSize: '0.9rem'
                    }}
                    required
                  />

                  <div style={{ position: 'relative' }}>
                    <input
                      type="text"
                      placeholder="Card Number"
                      value={cardNumber}
                      onChange={(e) => setCardNumber(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px 14px 12px 40px',
                        borderRadius: '10px',
                        border: '1px solid var(--border-subtle)',
                        fontSize: '0.9rem'
                      }}
                      required
                    />
                    <CreditCard size={18} color="#94a3b8" style={{ position: 'absolute', left: '14px', top: '13px' }} />
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
                    <input
                      type="text"
                      placeholder="MM / YY"
                      value={cardExpiry}
                      onChange={(e) => setCardExpiry(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px 14px',
                        borderRadius: '10px',
                        border: '1px solid var(--border-subtle)',
                        fontSize: '0.9rem'
                      }}
                      required
                    />
                    <input
                      type="text"
                      placeholder="CVC"
                      value={cardCvc}
                      onChange={(e) => setCardCvc(e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px 14px',
                        borderRadius: '10px',
                        border: '1px solid var(--border-subtle)',
                        fontSize: '0.9rem'
                      }}
                      required
                    />
                  </div>
                </div>
              </div>

              {error && (
                <div
                  style={{
                    backgroundColor: '#fef2f2',
                    color: '#b91c1c',
                    padding: '12px',
                    borderRadius: '10px',
                    fontSize: '0.85rem',
                    marginBottom: '16px'
                  }}
                >
                  {error}
                </div>
              )}

              {/* Submit Button */}
              <button
                type="submit"
                disabled={submitting}
                className="btn btn-primary"
                style={{
                  width: '100%',
                  padding: '16px',
                  borderRadius: 'var(--radius-full)',
                  fontSize: '1.05rem',
                  fontWeight: 800,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '8px',
                  boxShadow: '0 8px 24px rgba(16, 185, 129, 0.35)',
                  cursor: 'pointer'
                }}
              >
                {submitting ? (
                  <>
                    <Loader2 size={20} style={{ animation: 'spin 1s linear infinite' }} />
                    <span>Securing Escrow Deposit...</span>
                  </>
                ) : (
                  <>
                    <Lock size={18} />
                    <span>Pay ${buyerTotal.toFixed(2)} NZD & Hold in Escrow</span>
                  </>
                )}
              </button>

            </div>

          </div>

        </div>
      </form>

    </div>
  );
};
