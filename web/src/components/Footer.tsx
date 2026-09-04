import React from 'react';
import { Link } from 'react-router-dom';
import { Sparkles, Globe, Heart, ShieldCheck, Leaf } from 'lucide-react';

export const Footer: React.FC = () => {
  return (
    <footer style={{ marginTop: 'auto', backgroundColor: '#ffffff', borderTop: '1px solid var(--border-subtle)', padding: '48px 0 24px' }}>
      <div className="container">
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '36px', marginBottom: '36px' }}>
          
          {/* Brand Col */}
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '12px' }}>
              <div style={{
                width: '32px',
                height: '32px',
                borderRadius: '8px',
                background: 'linear-gradient(135deg, var(--primary-500), var(--primary-700))',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff'
              }}>
                <Sparkles size={18} />
              </div>
              <span style={{ fontSize: '1.25rem', fontWeight: 800, color: 'var(--primary-700)' }}>
                Kiwi<span style={{ color: 'var(--primary-500)' }}>Share</span>
              </span>
            </div>
            <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)', lineHeight: 1.6, marginBottom: '16px' }}>
              New Zealand's circular community marketplace. Re-home quality items, reduce carbon footprint, and connect locally.
            </p>
            <span className="badge badge-platform">
              <Globe size={13} /> Web Client
            </span>
          </div>

          {/* Explore Links */}
          <div>
            <h4 style={{ fontSize: '0.95rem', fontWeight: 700, marginBottom: '14px', color: 'var(--text-main)' }}>Explore KiwiShare</h4>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '0.9rem', color: 'var(--text-muted)' }}>
              <li><Link to="/" style={{ transition: 'color 0.15s' }}>Browse All Items</Link></li>
              <li><Link to="/?sustainable=true" style={{ transition: 'color 0.15s' }}>Sustainable Picks</Link></li>
              <li><Link to="/watchlist" style={{ transition: 'color 0.15s' }}>Saved Watchlist</Link></li>
            </ul>
          </div>

          {/* Trust & Safety */}
          <div>
            <h4 style={{ fontSize: '0.95rem', fontWeight: 700, marginBottom: '14px', color: 'var(--text-main)' }}>Trust & Community</h4>
            <ul style={{ listStyle: 'none', display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '0.9rem', color: 'var(--text-muted)' }}>
              <li style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <ShieldCheck size={16} color="var(--primary-600)" />
                <span>Verified NZ Locals</span>
              </li>
              <li style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <Leaf size={16} color="var(--primary-600)" />
                <span>Zero-Waste Impact</span>
              </li>
              <li style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <Heart size={16} color="var(--primary-600)" />
                <span>100% Community Powered</span>
              </li>
            </ul>
          </div>

        </div>

        <div style={{ borderTop: '1px solid var(--border-subtle)', paddingTop: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px', fontSize: '0.85rem', color: 'var(--text-light)' }}>
          <div>© {new Date().getFullYear()} KiwiShare Aotearoa NZ. All rights reserved.</div>
          <div style={{ display: 'flex', gap: '20px' }}>
            <span>Privacy Policy</span>
            <span>Terms of Service</span>
            <span>Community Guidelines</span>
          </div>
        </div>
      </div>
    </footer>
  );
};
