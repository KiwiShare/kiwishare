import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { authApi } from '../api/client';
import { Sparkles, Mail, Lock, KeyRound, Smartphone, AlertCircle, Loader2, User, ArrowLeft } from 'lucide-react';

export const LoginPage: React.FC = () => {
  const { login, loginWithOtp, loginWithPhone } = useAuth();
  const navigate = useNavigate();

  // Primary modes: 'email_otp' | 'phone_otp'; Secondary backup: 'password'
  const [mode, setMode] = useState<'email_otp' | 'phone_otp' | 'password'>('email_otp');

  // Input states
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('+64 ');
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');

  // OTP states
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState('');
  const [devCode, setDevCode] = useState<string | null>(null);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // 1. Password Login (Username or Email)
  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!identifier || !password) {
      setError('Please enter both username/email and password.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await login(identifier, password);
      navigate('/');
    } catch (err: any) {
      setError(err.message || 'Login failed. Please check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  // 2. Email OTP Send
  const handleSendEmailOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !email.includes('@')) {
      setError('Please enter a valid email address.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const res = await authApi.sendOtp(email);
      setOtpSent(true);
      if (res.devCode) {
        setDevCode(res.devCode);
        setOtpCode(res.devCode);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to send email verification code.');
    } finally {
      setLoading(false);
    }
  };

  // 3. Email OTP Verify
  const handleVerifyEmailOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !otpCode) {
      setError('Please enter your 6-digit verification code.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await loginWithOtp(email, otpCode);
      navigate('/');
    } catch (err: any) {
      setError(err.message || 'Invalid or expired verification code.');
    } finally {
      setLoading(false);
    }
  };

  // 4. Phone OTP Send (Firebase SMS)
  const handleSendPhoneOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanPhone = phone.trim();
    if (cleanPhone.length < 8) {
      setError('Please enter a valid mobile phone number.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const res = await authApi.sendPhoneOtp(cleanPhone);
      setOtpSent(true);
      if (res.devCode) {
        setDevCode(res.devCode);
        setOtpCode(res.devCode);
      }
    } catch (err: any) {
      setError(err.message || 'Failed to send SMS verification code.');
    } finally {
      setLoading(false);
    }
  };

  // 5. Phone OTP Verify
  const handleVerifyPhoneOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanPhone = phone.trim();
    if (!cleanPhone || !otpCode) {
      setError('Please enter the 6-digit SMS verification code.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await loginWithPhone({ phone: cleanPhone, code: otpCode });
      navigate('/');
    } catch (err: any) {
      setError(err.message || 'Invalid or expired SMS verification code.');
    } finally {
      setLoading(false);
    }
  };

  const handleQuickFill = (userIdentifier: string, userPass: string) => {
    setIdentifier(userIdentifier);
    setPassword(userPass);
    setMode('password');
    setError(null);
  };

  const resetOtpState = () => {
    setOtpSent(false);
    setOtpCode('');
    setDevCode(null);
    setError(null);
  };

  return (
    <div className="container" style={{ padding: '60px 20px', maxWidth: '520px' }}>
      <div className="glass-card animate-fade-in" style={{ padding: '40px 32px' }}>
        
        {/* Header */}
        <div style={{ textAlign: 'center', marginBottom: '24px' }}>
          <div style={{
            width: '50px',
            height: '50px',
            borderRadius: '16px',
            background: 'linear-gradient(135deg, var(--primary-500), var(--primary-700))',
            color: '#fff',
            display: 'inline-flex',
            alignItems: 'center',
            justifyContent: 'center',
            marginBottom: '12px',
            boxShadow: 'var(--shadow-primary)'
          }}>
            <Sparkles size={26} />
          </div>
          <h1 style={{ fontSize: '1.8rem', fontWeight: 800 }}>Welcome Back</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginTop: '4px' }}>
            Sign in to KiwiShare New Zealand Web
          </p>
        </div>

        {/* Error Alert */}
        {error && (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              padding: '12px 16px',
              borderRadius: 'var(--radius-md)',
              backgroundColor: '#fef2f2',
              border: '1px solid #fecaca',
              color: '#b91c1c',
              fontSize: '0.85rem',
              marginBottom: '20px',
            }}
          >
            <AlertCircle size={18} />
            <span>{error}</span>
          </div>
        )}

        {/* Primary View: OTP Tabs (Email OTP & Phone OTP) */}
        {mode !== 'password' ? (
          <div>
            {/* Primary Segmented Tabs */}
            <div style={{ display: 'flex', backgroundColor: '#f1f5f9', borderRadius: 'var(--radius-full)', padding: '4px', marginBottom: '24px' }}>
              <button
                type="button"
                onClick={() => { setMode('email_otp'); resetOtpState(); }}
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '6px',
                  padding: '9px 12px',
                  borderRadius: 'var(--radius-full)',
                  fontSize: '0.88rem',
                  fontWeight: 600,
                  backgroundColor: mode === 'email_otp' ? '#ffffff' : 'transparent',
                  color: mode === 'email_otp' ? 'var(--text-main)' : 'var(--text-muted)',
                  boxShadow: mode === 'email_otp' ? 'var(--shadow-sm)' : 'none',
                  transition: 'all 0.2s',
                  cursor: 'pointer',
                  border: 'none'
                }}
              >
                <Mail size={16} />
                Email Code
              </button>
              <button
                type="button"
                onClick={() => { setMode('phone_otp'); resetOtpState(); }}
                style={{
                  flex: 1,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '6px',
                  padding: '9px 12px',
                  borderRadius: 'var(--radius-full)',
                  fontSize: '0.88rem',
                  fontWeight: 600,
                  backgroundColor: mode === 'phone_otp' ? '#ffffff' : 'transparent',
                  color: mode === 'phone_otp' ? 'var(--text-main)' : 'var(--text-muted)',
                  boxShadow: mode === 'phone_otp' ? 'var(--shadow-sm)' : 'none',
                  transition: 'all 0.2s',
                  cursor: 'pointer',
                  border: 'none'
                }}
              >
                <Smartphone size={16} />
                Phone SMS
              </button>
            </div>

            {/* Email OTP Flow */}
            {mode === 'email_otp' && (
              <form onSubmit={otpSent ? handleVerifyEmailOtp : handleSendEmailOtp} style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>
                    Email Address
                  </label>
                  <div style={{ position: 'relative' }}>
                    <Mail size={18} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                    <input
                      type="email"
                      placeholder="name@example.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className="form-input"
                      style={{ paddingLeft: '42px' }}
                      disabled={otpSent}
                      required
                    />
                  </div>
                </div>

                {otpSent && (
                  <div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                      <label style={{ fontSize: '0.85rem', fontWeight: 600 }}>6-Digit Verification Code</label>
                      {devCode && (
                        <span style={{ fontSize: '0.75rem', color: 'var(--primary-700)', fontWeight: 700 }}>
                          Dev Code: {devCode}
                        </span>
                      )}
                    </div>
                    <div style={{ position: 'relative' }}>
                      <KeyRound size={18} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                      <input
                        type="text"
                        placeholder="123456"
                        maxLength={6}
                        value={otpCode}
                        onChange={(e) => setOtpCode(e.target.value)}
                        className="form-input"
                        style={{ paddingLeft: '42px', letterSpacing: '4px', fontWeight: 700 }}
                        required
                      />
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={loading}
                  className="btn btn-primary"
                  style={{ width: '100%', padding: '12px', marginTop: '4px' }}
                >
                  {loading ? (
                    <Loader2 size={20} style={{ animation: 'spin 1s linear infinite' }} />
                  ) : otpSent ? (
                    'Verify & Sign In'
                  ) : (
                    'Send Verification Code'
                  )}
                </button>

                {otpSent && (
                  <button
                    type="button"
                    onClick={resetOtpState}
                    style={{ fontSize: '0.85rem', color: 'var(--primary-600)', textAlign: 'center', cursor: 'pointer', background: 'none', border: 'none' }}
                  >
                    Change email address
                  </button>
                )}
              </form>
            )}

            {/* Phone OTP Flow */}
            {mode === 'phone_otp' && (
              <form onSubmit={otpSent ? handleVerifyPhoneOtp : handleSendPhoneOtp} style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>
                    Phone Number
                  </label>
                  <div style={{ position: 'relative' }}>
                    <Smartphone size={18} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                    <input
                      type="tel"
                      placeholder="+64 21 123 4567"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      className="form-input"
                      style={{ paddingLeft: '42px' }}
                      disabled={otpSent}
                      required
                    />
                  </div>
                </div>

                {otpSent && (
                  <div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px' }}>
                      <label style={{ fontSize: '0.85rem', fontWeight: 600 }}>6-Digit SMS Code</label>
                      {devCode && (
                        <span style={{ fontSize: '0.75rem', color: 'var(--primary-700)', fontWeight: 700 }}>
                          Dev Code: {devCode}
                        </span>
                      )}
                    </div>
                    <div style={{ position: 'relative' }}>
                      <KeyRound size={18} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                      <input
                        type="text"
                        placeholder="123456"
                        maxLength={6}
                        value={otpCode}
                        onChange={(e) => setOtpCode(e.target.value)}
                        className="form-input"
                        style={{ paddingLeft: '42px', letterSpacing: '4px', fontWeight: 700 }}
                        required
                      />
                    </div>
                  </div>
                )}

                <button
                  type="submit"
                  disabled={loading}
                  className="btn btn-primary"
                  style={{ width: '100%', padding: '12px', marginTop: '4px' }}
                >
                  {loading ? (
                    <Loader2 size={20} style={{ animation: 'spin 1s linear infinite' }} />
                  ) : otpSent ? (
                    'Verify & Sign In'
                  ) : (
                    'Send Verification Code'
                  )}
                </button>

                {otpSent && (
                  <button
                    type="button"
                    onClick={resetOtpState}
                    style={{ fontSize: '0.85rem', color: 'var(--primary-600)', textAlign: 'center', cursor: 'pointer', background: 'none', border: 'none' }}
                  >
                    Change phone number
                  </button>
                )}
              </form>
            )}

            {/* Secondary / Backup Login Access */}
            <div style={{ marginTop: '28px', paddingTop: '20px', borderTop: '1px solid var(--border-subtle)', textAlign: 'center' }}>
              <button
                type="button"
                onClick={() => { setMode('password'); setError(null); }}
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '8px',
                  fontSize: '0.88rem',
                  fontWeight: 600,
                  color: 'var(--primary-700)',
                  backgroundColor: 'var(--primary-50)',
                  border: '1px solid var(--primary-200)',
                  padding: '9px 18px',
                  borderRadius: 'var(--radius-full)',
                  cursor: 'pointer',
                  transition: 'all 0.2s',
                }}
              >
                <Lock size={15} />
                Use Username & Password Login
              </button>
            </div>
          </div>
        ) : (
          /* Secondary Backup View: Password Login (Username or Email) */
          <div>
            <div style={{ marginBottom: '18px' }}>
              <button
                type="button"
                onClick={() => { setMode('email_otp'); resetOtpState(); }}
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '6px',
                  fontSize: '0.85rem',
                  color: 'var(--primary-600)',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  fontWeight: 600,
                  padding: 0,
                  marginBottom: '12px'
                }}
              >
                <ArrowLeft size={16} />
                Back to OTP Verification
              </button>
              <h2 style={{ fontSize: '1.2rem', fontWeight: 700 }}>Account & Password Sign In</h2>
              <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                Use your registered username or email with your password.
              </p>
            </div>

            <form onSubmit={handlePasswordLogin} style={{ display: 'flex', flexDirection: 'column', gap: '18px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>
                  Username or Email
                </label>
                <div style={{ position: 'relative' }}>
                  <User size={18} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="text"
                    placeholder="Username or name@example.com"
                    value={identifier}
                    onChange={(e) => setIdentifier(e.target.value)}
                    className="form-input"
                    style={{ paddingLeft: '42px' }}
                    required
                  />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>
                  Password
                </label>
                <div style={{ position: 'relative' }}>
                  <Lock size={18} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                  <input
                    type="password"
                    placeholder="••••••••"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="form-input"
                    style={{ paddingLeft: '42px' }}
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading}
                className="btn btn-primary"
                style={{ width: '100%', padding: '12px', marginTop: '6px' }}
              >
                {loading ? <Loader2 size={20} style={{ animation: 'spin 1s linear infinite' }} /> : 'Sign In with Password'}
              </button>
            </form>
          </div>
        )}

        {/* Quick Fill Testing Helper */}
        <div style={{ marginTop: '28px', paddingTop: '20px', borderTop: '1px solid var(--border-subtle)', textAlign: 'center' }}>
          <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginBottom: '8px' }}>
            Quick Demo Accounts:
          </div>
          <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', flexWrap: 'wrap' }}>
            <button
              type="button"
              onClick={() => handleQuickFill('admin@kiwishare.online', 'password123')}
              style={{
                fontSize: '0.75rem',
                color: '#047857',
                backgroundColor: '#ecfdf5',
                padding: '5px 12px',
                borderRadius: 'var(--radius-full)',
                border: '1px solid #a7f3d0',
                fontWeight: 700,
                cursor: 'pointer',
              }}
            >
              👑 Admin: admin@kiwishare.online
            </button>
            <button
              type="button"
              onClick={() => handleQuickFill('sam@kiwishare.co.nz', 'password123')}
              style={{
                fontSize: '0.75rem',
                color: 'var(--primary-700)',
                backgroundColor: 'var(--primary-50)',
                padding: '5px 12px',
                borderRadius: 'var(--radius-full)',
                border: '1px solid var(--primary-200)',
                cursor: 'pointer',
              }}
            >
              👤 User: sam@kiwishare.co.nz
            </button>
          </div>
        </div>

        {/* Footer */}
        <div style={{ textAlign: 'center', marginTop: '20px', fontSize: '0.9rem', color: 'var(--text-muted)' }}>
          Don't have an account?{' '}
          <Link to="/register" style={{ color: 'var(--primary-600)', fontWeight: 600 }}>
            Sign up
          </Link>
        </div>

      </div>
    </div>
  );
};

