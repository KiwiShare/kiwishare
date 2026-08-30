import React, { useState } from 'react';
import { ordersApi } from '../api/client';
import { 
  Rocket, 
  Check, 
  Sparkles, 
  ShieldCheck, 
  Zap, 
  TrendingUp, 
  X, 
  Loader2 
} from 'lucide-react';

interface TurboBoostModalProps {
  isOpen: boolean;
  onClose: () => void;
  onActivated?: () => void;
}

export const TurboBoostModal: React.FC<TurboBoostModalProps> = ({
  isOpen,
  onClose,
  onActivated
}) => {
  const [selectedPlan, setSelectedPlan] = useState<'monthly' | 'yearly'>('monthly');
  const [loading, setLoading] = useState<boolean>(false);
  const [success, setSuccess] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleActivate = async () => {
    setLoading(true);
    setError(null);
    try {
      await ordersApi.activateTurboBoost(selectedPlan);
      setSuccess(true);
      setTimeout(() => {
        if (onActivated) onActivated();
      }, 1500);
    } catch (err: any) {
      setError(err.message || 'Failed to activate Turbo Boost membership.');
    } finally {
      setLoading(false);
    }
  };

  return (
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
      onClick={onClose}
    >
      <div
        className="glass-card"
        style={{
          width: '100%',
          maxWidth: '520px',
          backgroundColor: '#ffffff',
          borderRadius: '24px',
          padding: '32px',
          boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
          position: 'relative',
          overflow: 'hidden',
          border: '1px solid rgba(226, 232, 240, 0.8)'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Background Ambient Glow */}
        <div
          style={{
            position: 'absolute',
            top: '-100px',
            right: '-100px',
            width: '240px',
            height: '240px',
            background: 'radial-gradient(circle, rgba(16, 185, 129, 0.2) 0%, rgba(255,255,255,0) 70%)',
            pointerEvents: 'none'
          }}
        />

        {/* Close Button */}
        <button
          onClick={onClose}
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
            cursor: 'pointer',
            color: '#64748b'
          }}
        >
          <X size={18} />
        </button>

        {success ? (
          <div style={{ textAlign: 'center', padding: '24px 0' }}>
            <div
              style={{
                width: '72px',
                height: '72px',
                borderRadius: '50%',
                backgroundColor: '#dcfce7',
                color: '#16a34a',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                margin: '0 auto 20px',
                boxShadow: '0 10px 25px rgba(22, 163, 74, 0.2)'
              }}
            >
              <Check size={36} />
            </div>
            <h3 style={{ fontSize: '1.6rem', fontWeight: 800, color: '#0f172a', marginBottom: '8px' }}>
              Turbo Boost Activated!
            </h3>
            <p style={{ color: '#64748b', fontSize: '0.95rem', lineHeight: 1.6 }}>
              Your listings have been boosted to the top of homepage discovery with 0% platform seller fee!
            </p>
          </div>
        ) : (
          <>
            {/* Header Badge */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
              <span
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  backgroundColor: '#fef3c7',
                  color: '#b45309',
                  padding: '4px 12px',
                  borderRadius: '20px',
                  fontSize: '0.8rem',
                  fontWeight: 700
                }}
              >
                <Zap size={14} /> SELLER ACCELERATION
              </span>
            </div>

            <h2 style={{ fontSize: '1.75rem', fontWeight: 800, color: '#0f172a', marginBottom: '8px' }}>
              KiwiShare Turbo Boost
            </h2>
            <p style={{ color: '#64748b', fontSize: '0.95rem', marginBottom: '24px', lineHeight: 1.5 }}>
              Accelerate your sales with priority recommendation algorithm, homepage spotlight, and 0% seller fees.
            </p>

            {/* Feature Perks */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginBottom: '24px' }}>
              <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
                <div style={{ backgroundColor: '#ecfdf5', color: '#059669', padding: '8px', borderRadius: '10px' }}>
                  <TrendingUp size={18} />
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '0.95rem', color: '#1e293b' }}>
                    Top Homepage & Search Ranking
                  </div>
                  <div style={{ fontSize: '0.85rem', color: '#64748b' }}>
                    Items get up to 3.8x more buyer views with top discovery placement.
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
                <div style={{ backgroundColor: '#eff6ff', color: '#2563eb', padding: '8px', borderRadius: '10px' }}>
                  <Sparkles size={18} />
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '0.95rem', color: '#1e293b' }}>
                    Featured Boost Glow Badge
                  </div>
                  <div style={{ fontSize: '0.85rem', color: '#64748b' }}>
                    Distinguish your listings with verified high-priority badges.
                  </div>
                </div>
              </div>

              <div style={{ display: 'flex', gap: '12px', alignItems: 'flex-start' }}>
                <div style={{ backgroundColor: '#fef2f2', color: '#dc2626', padding: '8px', borderRadius: '10px' }}>
                  <ShieldCheck size={18} />
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '0.95rem', color: '#1e293b' }}>
                    0% Platform Seller Fee
                  </div>
                  <div style={{ fontSize: '0.85rem', color: '#64748b' }}>
                    Keep 100% of your earnings upon escrow handover completion.
                  </div>
                </div>
              </div>
            </div>

            {/* Plan Picker */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '24px' }}>
              <div
                onClick={() => setSelectedPlan('monthly')}
                style={{
                  border: selectedPlan === 'monthly' ? '2px solid #10b981' : '1px solid #e2e8f0',
                  backgroundColor: selectedPlan === 'monthly' ? '#f0fdf4' : '#ffffff',
                  padding: '16px',
                  borderRadius: '16px',
                  cursor: 'pointer',
                  transition: 'all 0.2s'
                }}
              >
                <div style={{ fontSize: '0.8rem', fontWeight: 600, color: '#64748b' }}>Monthly Pass</div>
                <div style={{ fontSize: '1.25rem', fontWeight: 800, color: '#0f172a', margin: '4px 0' }}>
                  $9.99 <span style={{ fontSize: '0.75rem', fontWeight: 500 }}>/ mo</span>
                </div>
                <div style={{ fontSize: '0.75rem', color: '#059669', fontWeight: 600 }}>Launch Free Trial</div>
              </div>

              <div
                onClick={() => setSelectedPlan('yearly')}
                style={{
                  border: selectedPlan === 'yearly' ? '2px solid #10b981' : '1px solid #e2e8f0',
                  backgroundColor: selectedPlan === 'yearly' ? '#f0fdf4' : '#ffffff',
                  padding: '16px',
                  borderRadius: '16px',
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                  position: 'relative'
                }}
              >
                <span
                  style={{
                    position: 'absolute',
                    top: '-10px',
                    right: '10px',
                    backgroundColor: '#10b981',
                    color: '#ffffff',
                    fontSize: '0.65rem',
                    fontWeight: 700,
                    padding: '2px 8px',
                    borderRadius: '10px'
                  }}
                >
                  SAVE 40%
                </span>
                <div style={{ fontSize: '0.8rem', fontWeight: 600, color: '#64748b' }}>Annual VIP</div>
                <div style={{ fontSize: '1.25rem', fontWeight: 800, color: '#0f172a', margin: '4px 0' }}>
                  $5.99 <span style={{ fontSize: '0.75rem', fontWeight: 500 }}>/ mo</span>
                </div>
                <div style={{ fontSize: '0.75rem', color: '#059669', fontWeight: 600 }}>Billed $71.88/yr</div>
              </div>
            </div>

            {error && (
              <div
                style={{
                  backgroundColor: '#fef2f2',
                  color: '#b91c1c',
                  padding: '12px',
                  borderRadius: '12px',
                  fontSize: '0.85rem',
                  marginBottom: '16px'
                }}
              >
                {error}
              </div>
            )}

            {/* Action CTA */}
            <button
              onClick={handleActivate}
              disabled={loading}
              className="btn btn-primary"
              style={{
                width: '100%',
                padding: '16px',
                borderRadius: 'var(--radius-full)',
                fontSize: '1rem',
                fontWeight: 700,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                background: 'linear-gradient(135deg, #10b981 0%, #047857 100%)',
                boxShadow: '0 8px 20px rgba(16, 185, 129, 0.35)',
                border: 'none',
                color: '#ffffff',
                cursor: 'pointer'
              }}
            >
              {loading ? (
                <>
                  <Loader2 size={18} style={{ animation: 'spin 1s linear infinite' }} />
                  <span>Activating Boost...</span>
                </>
              ) : (
                <>
                  <Rocket size={18} />
                  <span>Activate Turbo Boost (Free Trial)</span>
                </>
              )}
            </button>
          </>
        )}
      </div>
    </div>
  );
};
