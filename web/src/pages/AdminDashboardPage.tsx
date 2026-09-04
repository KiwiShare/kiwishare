import React, { useState, useEffect, useCallback } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate, Link } from 'react-router-dom';
import { 
  adminApi, 
  categoriesApi, 
  AdminStats, 
  CategoryItem, 
  UsedItem,
  UserProfile 
} from '../api/client';
import { PostItemModal } from '../components/PostItemModal';
import { 
  ShieldCheck, 
  LayoutDashboard, 
  Tag, 
  Package, 
  Users, 
  Globe, 
  Smartphone, 
  Plus, 
  Trash2, 
  EyeOff, 
  CheckCircle, 
  Loader2, 
  TrendingUp,
  Search,
  GraduationCap,
  Ban,
  UserCheck,
  PlusCircle,
  MinusCircle,
  ShoppingCart,
  DollarSign,
  CreditCard,
  Percent,
  ArrowRightLeft,
  UserPlus,
  CheckCircle2,
  Clock,
  AlertCircle,
  X
} from 'lucide-react';

export const AdminDashboardPage: React.FC = () => {
  const { user, isLoggedIn } = useAuth();
  const navigate = useNavigate();

  const [activeTab, setActiveTab] = useState<'overview' | 'categories' | 'items' | 'users'>('overview');
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [categories, setCategories] = useState<CategoryItem[]>([]);
  const [items, setItems] = useState<UsedItem[]>([]);
  const [usersList, setUsersList] = useState<UserProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [isPostModalOpen, setIsPostModalOpen] = useState(false);

  // Reassign / Transfer Modal State
  const [reassignModalItem, setReassignModalItem] = useState<UsedItem | null>(null);
  const [reassignTargetEmail, setReassignTargetEmail] = useState('');
  const [reassignLoading, setReassignLoading] = useState(false);
  const [reassignError, setReassignError] = useState<string | null>(null);
  const [reassignSuccess, setReassignSuccess] = useState<string | null>(null);

  // New Category Form State
  const [newCatName, setNewCatName] = useState('');
  const [newCatIcon, setNewCatIcon] = useState('Package');
  const [newCatDesc, setNewCatDesc] = useState('');
  const [catActionLoading, setCatActionLoading] = useState(false);

  // Item Filter State
  const [itemStatusFilter, setItemStatusFilter] = useState('all');
  const [itemSearch, setItemSearch] = useState('');

  // User Filter State
  const [userSearch, setUserSearch] = useState('');
  const [userStatusFilter, setUserStatusFilter] = useState('all');

  const checkAdminAndFetch = useCallback(async () => {
    if (!isLoggedIn) {
      navigate('/login');
      return;
    }
    if (user && user.role !== 'admin') {
      navigate('/');
      return;
    }

    try {
      setLoading(true);
      const [statsRes, catsRes, itemsRes, usersRes] = await Promise.all([
        adminApi.getStats().catch(() => ({ stats: null })),
        categoriesApi.getCategories(true).catch(() => ({ categories: [] })),
        adminApi.getItems({ status: itemStatusFilter, search: itemSearch }).catch(() => ({ items: [] })),
        adminApi.getUsers({ status: userStatusFilter, search: userSearch }).catch(() => ({ users: [] })),
      ]);

      if (statsRes.stats) setStats(statsRes.stats);
      if (catsRes.categories) setCategories(catsRes.categories);
      if (itemsRes.items) setItems(itemsRes.items);
      if (usersRes.users) setUsersList(usersRes.users);
    } catch (err) {
      console.error('Failed to load admin dashboard data:', err);
    } finally {
      setLoading(false);
    }
  }, [isLoggedIn, user, navigate, itemStatusFilter, itemSearch, userStatusFilter, userSearch]);

  useEffect(() => {
    checkAdminAndFetch();
  }, [checkAdminAndFetch]);

  useEffect(() => {
    if (activeTab === 'items') {
      adminApi.getItems({ status: itemStatusFilter, search: itemSearch }).then((res) => {
        if (res.items) setItems(res.items);
      });
    } else if (activeTab === 'users') {
      adminApi.getUsers({ status: userStatusFilter, search: userSearch }).then((res) => {
        if (res.users) setUsersList(res.users);
      });
    }
  }, [itemStatusFilter, itemSearch, userStatusFilter, userSearch, activeTab]);

  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newCatName.trim()) return;

    try {
      setCatActionLoading(true);
      await categoriesApi.createCategory({
        name: newCatName.trim(),
        icon: newCatIcon,
        description: newCatDesc.trim(),
        sortOrder: categories.length + 1,
      });

      setNewCatName('');
      setNewCatDesc('');
      const res = await categoriesApi.getCategories(true);
      if (res.categories) setCategories(res.categories);
    } catch (err: any) {
      alert(err.message || 'Failed to create category.');
    } finally {
      setCatActionLoading(false);
    }
  };

  const handleToggleCategory = async (cat: CategoryItem) => {
    const catId = cat.id || cat._id;
    if (!catId) return;

    try {
      await categoriesApi.updateCategory(catId, { isActive: !cat.isActive });
      const res = await categoriesApi.getCategories(true);
      if (res.categories) setCategories(res.categories);
    } catch (err: any) {
      alert(err.message || 'Failed to update category status.');
    }
  };

  const handleDeleteCategory = async (cat: CategoryItem) => {
    const catId = cat.id || cat._id;
    if (!catId) return;

    if (!window.confirm(`Are you sure you want to delete category "${cat.name}"?`)) return;

    try {
      await categoriesApi.deleteCategory(catId);
      const res = await categoriesApi.getCategories(true);
      if (res.categories) setCategories(res.categories);
    } catch (err: any) {
      alert(err.message || 'Failed to delete category.');
    }
  };

  const handleUpdateItemStatus = async (itemId: string, status: 'active' | 'revoked' | 'sold' | 'deleted') => {
    try {
      await adminApi.updateItemStatus(itemId, status);
      const res = await adminApi.getItems({ status: itemStatusFilter, search: itemSearch });
      if (res.items) setItems(res.items);
    } catch (err: any) {
      alert(err.message || 'Failed to update item status.');
    }
  };

  const handleReassignItem = async (e: React.FormEvent) => {
    e.preventDefault();
    const itemId = reassignModalItem?.id || (reassignModalItem as any)?._id;
    if (!itemId || !reassignTargetEmail.trim()) return;

    try {
      setReassignLoading(true);
      setReassignError(null);
      const res = await adminApi.reassignItem(itemId, {
        targetUserEmail: reassignTargetEmail.trim(),
      });
      setReassignSuccess(res.message || 'Item successfully reassigned.');

      // Refresh items list and overview stats
      const [itemsRes, statsRes] = await Promise.all([
        adminApi.getItems({ status: itemStatusFilter, search: itemSearch }).catch(() => ({ items: [] })),
        adminApi.getStats().catch(() => ({ stats: null })),
      ]);
      if (itemsRes.items) setItems(itemsRes.items);
      if (statsRes.stats) setStats(statsRes.stats);

      setTimeout(() => {
        setReassignModalItem(null);
        setReassignTargetEmail('');
        setReassignSuccess(null);
      }, 1200);
    } catch (err: any) {
      setReassignError(err.message || 'Failed to reassign item.');
    } finally {
      setReassignLoading(false);
    }
  };

  const handleToggleStudent = async (u: UserProfile) => {
    const userId = u.id || u._id;
    if (!userId) return;
    const newStatus = !u.isStudentVerified;

    try {
      await adminApi.updateUserTrustScore(userId, {
        isStudentVerified: newStatus,
        studentInstitution: u.studentInstitution || 'University of Auckland',
      });
      const res = await adminApi.getUsers({ status: userStatusFilter, search: userSearch });
      if (res.users) setUsersList(res.users);
    } catch (err: any) {
      alert(err.message || 'Failed to update student verification status.');
    }
  };

  const handleAdjustScore = async (u: UserProfile, delta: number) => {
    const userId = u.id || u._id;
    if (!userId) return;
    const newScore = Math.max(0, Math.min(100, (u.trustScore ?? 100) + delta));

    try {
      await adminApi.updateUserTrustScore(userId, { trustScore: newScore });
      const res = await adminApi.getUsers({ status: userStatusFilter, search: userSearch });
      if (res.users) setUsersList(res.users);
    } catch (err: any) {
      alert(err.message || 'Failed to update trust score.');
    }
  };

  const handleToggleBan = async (u: UserProfile) => {
    const userId = u.id || u._id;
    if (!userId) return;
    const currentlyBanned = Boolean(u.isBanned || u.status === 'banned');
    const confirmMsg = currentlyBanned
      ? `Are you sure you want to unban user "${u.displayName || u.email}"?`
      : `Are you sure you want to ban user "${u.displayName || u.email}"?`;

    if (!window.confirm(confirmMsg)) return;

    try {
      await adminApi.updateUserStatus(userId, {
        isBanned: !currentlyBanned,
        status: currentlyBanned ? 'active' : 'banned',
      });
      const res = await adminApi.getUsers({ status: userStatusFilter, search: userSearch });
      if (res.users) setUsersList(res.users);
    } catch (err: any) {
      alert(err.message || 'Failed to update user ban status.');
    }
  };

  if (loading) {
    return (
      <div className="container" style={{ padding: '80px 20px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <Loader2 size={36} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
        <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
        <p style={{ marginTop: '16px', color: 'var(--text-muted)' }}>Loading KiwiShare Admin Dashboard...</p>
      </div>
    );
  }

  return (
    <div className="container" style={{ padding: '32px 20px 80px' }}>
      
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '28px', flexWrap: 'wrap', gap: '16px' }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
            <ShieldCheck size={28} color="var(--primary-600)" />
            <h1 style={{ fontSize: '1.8rem', fontWeight: 800 }}>KiwiShare Administration</h1>
          </div>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem' }}>
            Global platform overview, category management, product moderation, and user governance
          </p>
        </div>

        <button
          onClick={() => setIsPostModalOpen(true)}
          className="btn btn-primary"
          style={{ padding: '10px 20px', borderRadius: 'var(--radius-full)' }}
        >
          <Plus size={18} />
          <span>Publish New Product</span>
        </button>
      </div>

      {/* Navigation Tabs */}
      <div style={{ display: 'flex', gap: '8px', borderBottom: '1px solid var(--border-subtle)', marginBottom: '32px' }}>
        <button
          onClick={() => setActiveTab('overview')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '12px 20px',
            fontWeight: 700,
            fontSize: '0.95rem',
            color: activeTab === 'overview' ? 'var(--primary-700)' : 'var(--text-muted)',
            borderBottom: activeTab === 'overview' ? '3px solid var(--primary-600)' : '3px solid transparent',
            background: 'none',
            cursor: 'pointer',
            transition: 'all 0.2s',
          }}
        >
          <LayoutDashboard size={18} />
          <span>Global Overview</span>
        </button>

        <button
          onClick={() => setActiveTab('users')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '12px 20px',
            fontWeight: 700,
            fontSize: '0.95rem',
            color: activeTab === 'users' ? 'var(--primary-700)' : 'var(--text-muted)',
            borderBottom: activeTab === 'users' ? '3px solid var(--primary-600)' : '3px solid transparent',
            background: 'none',
            cursor: 'pointer',
            transition: 'all 0.2s',
          }}
        >
          <Users size={18} />
          <span>User Management ({usersList.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('items')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '12px 20px',
            fontWeight: 700,
            fontSize: '0.95rem',
            color: activeTab === 'items' ? 'var(--primary-700)' : 'var(--text-muted)',
            borderBottom: activeTab === 'items' ? '3px solid var(--primary-600)' : '3px solid transparent',
            background: 'none',
            cursor: 'pointer',
            transition: 'all 0.2s',
          }}
        >
          <Package size={18} />
          <span>Product Moderation ({items.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('categories')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            padding: '12px 20px',
            fontWeight: 700,
            fontSize: '0.95rem',
            color: activeTab === 'categories' ? 'var(--primary-700)' : 'var(--text-muted)',
            borderBottom: activeTab === 'categories' ? '3px solid var(--primary-600)' : '3px solid transparent',
            background: 'none',
            cursor: 'pointer',
            transition: 'all 0.2s',
          }}
        >
          <Tag size={18} />
          <span>Category Governance ({categories.length})</span>
        </button>
      </div>

      {/* TAB 1: Global Overview */}
      {activeTab === 'overview' && stats && (
        <div className="animate-fade-in">
          {/* Section Header: Transaction & Financial Intelligence */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
            <h2 style={{ fontSize: '1.2rem', fontWeight: 800, display: 'flex', alignItems: 'center', gap: '8px' }}>
              <DollarSign size={20} color="var(--primary-600)" />
              <span>Platform Flow & Transaction Economics</span>
            </h2>
            <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Real-time aggregated escrow & fee data</span>
          </div>

          {/* Top Row: Financial & Order Metric Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '20px', marginBottom: '24px' }}>
            
            {/* Total Orders */}
            <div className="glass-card" style={{ padding: '24px', borderLeft: '4px solid #10b981' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>Total Orders</span>
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: '#ecfdf5', color: '#059669', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <ShoppingCart size={18} />
                </div>
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--text-main)' }}>
                {stats.orderStats?.totalOrders ?? 0}
              </div>
              <div style={{ fontSize: '0.8rem', color: '#059669', marginTop: '4px', fontWeight: 600 }}>
                {stats.orderStats?.completedOrders ?? 0} completed · {stats.orderStats?.activeOrders ?? 0} in progress
              </div>
            </div>

            {/* Total GMV / Turnover */}
            <div className="glass-card" style={{ padding: '24px', borderLeft: '4px solid #3b82f6' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>Gross Turnover / GMV</span>
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: '#eff6ff', color: '#2563eb', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <DollarSign size={18} />
                </div>
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 800, color: '#1d4ed8' }}>
                ${stats.orderStats?.totalGmvNzd ?? '0.00'} <span style={{ fontSize: '1rem', fontWeight: 600 }}>NZD</span>
              </div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                Total transacted escrow volume
              </div>
            </div>

            {/* KiwiShare Platform Fees */}
            <div className="glass-card" style={{ padding: '24px', borderLeft: '4px solid #f59e0b' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>KiwiShare Fees</span>
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: '#fef3c7', color: '#d97706', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Percent size={18} />
                </div>
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 800, color: '#b45309' }}>
                ${stats.orderStats?.totalPlatformFeesNzd ?? '0.00'} <span style={{ fontSize: '1rem', fontWeight: 600 }}>NZD</span>
              </div>
              <div style={{ fontSize: '0.8rem', color: '#b45309', marginTop: '4px', fontWeight: 600 }}>
                Buyer & seller service fee revenue
              </div>
            </div>

            {/* Seller Payouts */}
            <div className="glass-card" style={{ padding: '24px', borderLeft: '4px solid #8b5cf6' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>Seller Payouts</span>
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: '#f3e8ff', color: '#7c3aed', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <CreditCard size={18} />
                </div>
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 800, color: '#6d28d9' }}>
                ${stats.orderStats?.totalSellerPayoutsNzd ?? '0.00'} <span style={{ fontSize: '1rem', fontWeight: 600 }}>NZD</span>
              </div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                Net received / payable to Kiwi sellers
              </div>
            </div>

          </div>

          {/* Section: Transaction Status & Financial Breakdown Grid */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: '24px', marginBottom: '32px' }}>
            
            {/* Transaction Situation / Status Breakdown */}
            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Transaction Status</h3>
                <span className="badge" style={{ backgroundColor: '#ecfdf5', color: '#047857' }}>
                  Live Status Tracking
                </span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                {/* Completed / Settled */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', backgroundColor: '#f0fdf4', borderRadius: 'var(--radius-md)', border: '1px solid #bbf7d0' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <CheckCircle2 size={16} color="#16a34a" />
                    <div>
                      <span style={{ fontWeight: 700, fontSize: '0.9rem', color: '#15803d' }}>Completed & Handed Over</span>
                      <div style={{ fontSize: '0.75rem', color: '#166534' }}>QR code scanned and payouts released</div>
                    </div>
                  </div>
                  <strong style={{ fontSize: '1.1rem', color: '#15803d' }}>
                    {(stats.orderStats?.statusBreakdown?.completed || 0) + (stats.orderStats?.statusBreakdown?.seller_paid || 0)}
                  </strong>
                </div>

                {/* In Handover / Meeting */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', backgroundColor: '#eff6ff', borderRadius: 'var(--radius-md)', border: '1px solid #bfdbfe' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Clock size={16} color="#2563eb" />
                    <div>
                      <span style={{ fontWeight: 700, fontSize: '0.9rem', color: '#1d4ed8' }}>Meeting & Handover in Progress</span>
                      <div style={{ fontSize: '0.75rem', color: '#1e40af' }}>Meeting scheduled, arriving, or scanned</div>
                    </div>
                  </div>
                  <strong style={{ fontSize: '1.1rem', color: '#1d4ed8' }}>
                    {(stats.orderStats?.statusBreakdown?.meeting_scheduled || 0) + 
                     (stats.orderStats?.statusBreakdown?.meeting_in_progress || 0) + 
                     (stats.orderStats?.statusBreakdown?.qr_scanned || 0)}
                  </strong>
                </div>

                {/* Paid in Escrow */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', backgroundColor: '#faf5ff', borderRadius: 'var(--radius-md)', border: '1px solid #e9d5ff' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <DollarSign size={16} color="#7c3aed" />
                    <div>
                      <span style={{ fontWeight: 700, fontSize: '0.9rem', color: '#6d28d9' }}>Escrow Secured / Pending</span>
                      <div style={{ fontSize: '0.75rem', color: '#5b21b6' }}>Payment verified by Stripe, awaiting meetup</div>
                    </div>
                  </div>
                  <strong style={{ fontSize: '1.1rem', color: '#6d28d9' }}>
                    {(stats.orderStats?.statusBreakdown?.paid || 0) + (stats.orderStats?.statusBreakdown?.transfer_pending || 0)}
                  </strong>
                </div>

                {/* Cancelled / Refunded */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', backgroundColor: '#fef2f2', borderRadius: 'var(--radius-md)', border: '1px solid #fecaca' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <AlertCircle size={16} color="#dc2626" />
                    <div>
                      <span style={{ fontWeight: 700, fontSize: '0.9rem', color: '#b91c1c' }}>Cancelled / Refunded</span>
                      <div style={{ fontSize: '0.75rem', color: '#991b1b' }}>Mutually cancelled or dispute refunds</div>
                    </div>
                  </div>
                  <strong style={{ fontSize: '1.1rem', color: '#b91c1c' }}>
                    {(stats.orderStats?.statusBreakdown?.cancelled || 0) + 
                     (stats.orderStats?.statusBreakdown?.refunded || 0) + 
                     (stats.orderStats?.statusBreakdown?.refund_pending || 0)}
                  </strong>
                </div>
              </div>
            </div>

            {/* Financial Flow & KiwiShare Fee Economics */}
            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Fee & Revenue Flow</h3>
                <span className="badge" style={{ backgroundColor: '#fef3c7', color: '#b45309' }}>
                  NZD Currency
                </span>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '8px', borderBottom: '1px solid var(--border-subtle)' }}>
                  <div>
                    <span style={{ fontWeight: 600, fontSize: '0.9rem' }}>Gross Merchandise Value (GMV)</span>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Total transacted sum paid by buyers</div>
                  </div>
                  <strong style={{ fontSize: '1rem', color: 'var(--text-main)' }}>
                    ${stats.orderStats?.totalGmvNzd ?? '0.00'} NZD
                  </strong>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '8px', borderBottom: '1px solid var(--border-subtle)' }}>
                  <div>
                    <span style={{ fontWeight: 600, fontSize: '0.9rem', color: '#b45309' }}>KiwiShare Total Platform Fees</span>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Buyer platform fee + Seller commission</div>
                  </div>
                  <strong style={{ fontSize: '1.05rem', color: '#b45309' }}>
                    +${stats.orderStats?.totalPlatformFeesNzd ?? '0.00'} NZD
                  </strong>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingBottom: '8px', borderBottom: '1px solid var(--border-subtle)' }}>
                  <div>
                    <span style={{ fontWeight: 600, fontSize: '0.9rem', color: '#047857' }}>Net Seller Disbursements</span>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Transferred to community student sellers</div>
                  </div>
                  <strong style={{ fontSize: '1rem', color: '#047857' }}>
                    ${stats.orderStats?.totalSellerPayoutsNzd ?? '0.00'} NZD
                  </strong>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 14px', backgroundColor: '#f8fafc', borderRadius: 'var(--radius-md)' }}>
                  <div>
                    <span style={{ fontWeight: 600, fontSize: '0.85rem' }}>Average Order Value (AOV)</span>
                    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Average price per transaction</div>
                  </div>
                  <strong style={{ fontSize: '0.95rem' }}>
                    {stats.orderStats && stats.orderStats.totalOrders > 0
                      ? `$${(parseFloat(stats.orderStats.totalGmvNzd || '0') / stats.orderStats.totalOrders).toFixed(2)} NZD`
                      : '$0.00 NZD'}
                  </strong>
                </div>
              </div>
            </div>

          </div>

          {/* Section: Recent Orders & Escrow Transactions */}
          <div className="glass-card" style={{ padding: '0', overflow: 'hidden', marginBottom: '32px' }}>
            <div style={{ padding: '18px 24px', borderBottom: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 700 }}>Recent KiwiShare Orders</h3>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '2px' }}>Latest transactions facilitated through KiwiShare escrow</p>
              </div>
              <span className="badge" style={{ backgroundColor: 'var(--primary-100)', color: 'var(--primary-800)' }}>
                {stats.orderStats?.recentOrders?.length || 0} Recent Deals
              </span>
            </div>

            {stats.orderStats?.recentOrders && stats.orderStats.recentOrders.length > 0 ? (
              <div style={{ overflowX: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.85rem' }}>
                  <thead style={{ backgroundColor: '#f8fafc', borderBottom: '1px solid var(--border-subtle)', color: 'var(--text-muted)' }}>
                    <tr>
                      <th style={{ padding: '12px 16px' }}>Order / Item</th>
                      <th style={{ padding: '12px 16px' }}>Buyer</th>
                      <th style={{ padding: '12px 16px' }}>Seller</th>
                      <th style={{ padding: '12px 16px' }}>Gross Total</th>
                      <th style={{ padding: '12px 16px' }}>KiwiShare Fee</th>
                      <th style={{ padding: '12px 16px' }}>Status</th>
                      <th style={{ padding: '12px 16px', textAlign: 'right' }}>Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {stats.orderStats.recentOrders.map((ord) => {
                      const isCompleted = ord.status === 'completed' || ord.status === 'seller_paid';
                      const isCancelled = ord.status === 'cancelled' || ord.status === 'refunded';
                      return (
                        <tr key={ord.id} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                          <td style={{ padding: '12px 16px' }}>
                            <div style={{ fontWeight: 700, color: 'var(--text-main)' }}>{ord.itemTitle}</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>{ord.orderNumber}</div>
                          </td>
                          <td style={{ padding: '12px 16px' }}>
                            <div style={{ fontWeight: 600 }}>{ord.buyerName}</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{ord.buyerEmail}</div>
                          </td>
                          <td style={{ padding: '12px 16px' }}>
                            <div style={{ fontWeight: 600 }}>{ord.sellerName}</div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{ord.sellerEmail}</div>
                          </td>
                          <td style={{ padding: '12px 16px', fontWeight: 700, color: 'var(--primary-700)' }}>
                            ${ord.buyerTotalNzd} NZD
                          </td>
                          <td style={{ padding: '12px 16px', fontWeight: 600, color: '#b45309' }}>
                            ${ord.platformFeeNzd} NZD
                          </td>
                          <td style={{ padding: '12px 16px' }}>
                            <span
                              className="badge"
                              style={{
                                backgroundColor: isCompleted ? '#ecfdf5' : isCancelled ? '#fef2f2' : '#eff6ff',
                                color: isCompleted ? '#047857' : isCancelled ? '#b91c1c' : '#1d4ed8',
                              }}
                            >
                              {ord.status.replace(/_/g, ' ')}
                            </span>
                          </td>
                          <td style={{ padding: '12px 16px', textAlign: 'right', color: 'var(--text-muted)', fontSize: '0.8rem' }}>
                            {new Date(ord.createdAt).toLocaleDateString()}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            ) : (
              <div style={{ padding: '32px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <ShoppingCart size={32} color="var(--primary-300)" style={{ margin: '0 auto 8px' }} />
                <p style={{ fontWeight: 600, fontSize: '0.9rem' }}>No orders placed yet</p>
                <p style={{ fontSize: '0.8rem' }}>When users buy products via KiwiShare Escrow, their transaction and fee status will stream here live.</p>
              </div>
            )}
          </div>

          {/* Section Header: Community & Platform Health */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
            <h2 style={{ fontSize: '1.2rem', fontWeight: 800, display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Users size={20} color="var(--primary-600)" />
              <span>Community & User Engagement</span>
            </h2>
          </div>

          {/* Secondary Metric Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '20px', marginBottom: '32px' }}>
            
            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>Total Users</span>
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: '#e0f2fe', color: '#0284c7', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Users size={18} />
                </div>
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--text-main)' }}>{stats.totalUsers}</div>
              <div style={{ fontSize: '0.8rem', color: 'var(--primary-600)', marginTop: '4px' }}>Registered Kiwi accounts</div>
            </div>

            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>Active Items</span>
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: 'var(--primary-100)', color: 'var(--primary-700)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Package size={18} />
                </div>
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--primary-700)' }}>{stats.activeItems}</div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>Out of {stats.totalItems} total listings</div>
            </div>

            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>Watchlist Saves</span>
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: '#fef3c7', color: '#d97706', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <TrendingUp size={18} />
                </div>
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 800, color: '#b45309' }}>{stats.totalWatchlistEntries}</div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>Active item bookmarks</div>
            </div>

            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                <span style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text-muted)' }}>Platform Traffic</span>
                <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: '#f3e8ff', color: '#9333ea', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <Globe size={18} />
                </div>
              </div>
              <div style={{ fontSize: '1.2rem', fontWeight: 700, color: 'var(--text-main)', marginTop: '4px' }}>
                Web: {stats.platformStats.web || 0} · App: {(stats.platformStats.mobile_ios || 0) + (stats.platformStats.mobile_android || 0) + (stats.platformStats.mobile || 0)}
              </div>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '6px' }}>Multi-platform distribution</div>
            </div>

          </div>

          {/* Aggregation Insights */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: '24px' }}>
            
            {/* Category Breakdown */}
            <div className="glass-card" style={{ padding: '24px' }}>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '16px' }}>Item Category Breakdown</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                {stats.categoryDistribution.map((c) => (
                  <div key={c.category} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.9rem' }}>
                    <span style={{ fontWeight: 600 }}>{c.category}</span>
                    <span className="badge" style={{ backgroundColor: 'var(--primary-100)', color: 'var(--primary-800)' }}>
                      {c.count} items
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Platform Metrics */}
            <div className="glass-card" style={{ padding: '24px' }}>
              <h3 style={{ fontSize: '1.1rem', fontWeight: 700, marginBottom: '16px' }}>Client Access Origins</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Globe size={16} color="var(--primary-600)" /> React Web Client
                  </span>
                  <strong>{stats.platformStats.web || 0}</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Smartphone size={16} color="#0284c7" /> iOS Mobile App
                  </span>
                  <strong>{stats.platformStats.mobile_ios || 0}</strong>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Smartphone size={16} color="#16a34a" /> Android Mobile App
                  </span>
                  <strong>{stats.platformStats.mobile_android || 0}</strong>
                </div>
              </div>
            </div>

          </div>
        </div>
      )}

      {/* TAB 2: User Governance */}
      {activeTab === 'users' && (
        <div className="animate-fade-in">
          
          {/* User Controls & Filters */}
          <div className="glass-card" style={{ padding: '20px', marginBottom: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
            <div style={{ position: 'relative', flex: '1', maxWidth: '400px' }}>
              <Search size={16} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
              <input
                type="text"
                placeholder="Search user name, email, university..."
                value={userSearch}
                onChange={(e) => setUserSearch(e.target.value)}
                className="form-input"
                style={{ paddingLeft: '40px' }}
              />
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <select
                value={userStatusFilter}
                onChange={(e) => setUserStatusFilter(e.target.value)}
                className="form-input"
                style={{ width: 'auto' }}
              >
                <option value="all">All Users</option>
                <option value="active">Active Accounts</option>
                <option value="banned">Banned Accounts</option>
              </select>
            </div>
          </div>

          {/* Users Table */}
          <div className="glass-card" style={{ padding: '0', overflow: 'hidden' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.9rem' }}>
              <thead style={{ backgroundColor: '#f8fafc', borderBottom: '1px solid var(--border-subtle)', color: 'var(--text-muted)' }}>
                <tr>
                  <th style={{ padding: '16px' }}>User</th>
                  <th style={{ padding: '16px' }}>Role</th>
                  <th style={{ padding: '16px' }}>Student Status</th>
                  <th style={{ padding: '16px' }}>Trust Score</th>
                  <th style={{ padding: '16px' }}>Status</th>
                  <th style={{ padding: '16px' }}>Items</th>
                  <th style={{ padding: '16px', textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {usersList.length > 0 ? (
                  usersList.map((u) => {
                    const userId = u.id || u._id || '';
                    const isBanned = Boolean(u.isBanned || u.status === 'banned');
                    const isStudent = Boolean(u.isStudentVerified);

                    return (
                      <tr key={userId} style={{ borderBottom: '1px solid var(--border-subtle)', backgroundColor: isBanned ? '#fff5f5' : 'transparent' }}>
                        <td style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                          {u.avatarUrl ? (
                            <img
                              src={u.avatarUrl}
                              alt=""
                              style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover' }}
                            />
                          ) : (
                            <div
                              style={{
                                width: '40px',
                                height: '40px',
                                borderRadius: '50%',
                                backgroundColor: isStudent ? '#dbeafe' : 'var(--primary-100)',
                                color: isStudent ? '#1d4ed8' : 'var(--primary-700)',
                                fontWeight: 700,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center'
                              }}
                            >
                              {(u.displayName || u.email || 'U').charAt(0).toUpperCase()}
                            </div>
                          )}
                          <div>
                            <div style={{ fontWeight: 700, color: 'var(--text-main)' }}>
                              {u.displayName || 'Kiwi User'}
                            </div>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{u.email}</div>
                          </div>
                        </td>

                        <td style={{ padding: '14px 16px' }}>
                          <span
                            className="badge"
                            style={{
                              backgroundColor: u.role === 'admin' ? '#fef3c7' : '#f1f5f9',
                              color: u.role === 'admin' ? '#b45309' : '#475569',
                              textTransform: 'capitalize'
                            }}
                          >
                            {u.role || 'user'}
                          </span>
                        </td>

                        <td style={{ padding: '14px 16px' }}>
                          {isStudent ? (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                              <span
                                className="badge"
                                style={{ backgroundColor: '#dbeafe', color: '#1e40af', display: 'flex', alignItems: 'center', gap: '4px' }}
                              >
                                <GraduationCap size={12} /> Verified Student
                              </span>
                            </div>
                          ) : (
                            <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Standard</span>
                          )}
                        </td>

                        <td style={{ padding: '14px 16px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                            <strong style={{ color: (u.trustScore ?? 100) < 50 ? '#dc2626' : 'var(--primary-700)' }}>
                              {u.trustScore ?? 100}
                            </strong>
                            <div style={{ display: 'inline-flex', gap: '2px' }}>
                              <button
                                onClick={() => handleAdjustScore(u, 5)}
                                style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--primary-600)', padding: '2px' }}
                                title="Add 5 points"
                              >
                                <PlusCircle size={15} />
                              </button>
                              <button
                                onClick={() => handleAdjustScore(u, -5)}
                                style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#dc2626', padding: '2px' }}
                                title="Deduct 5 points"
                              >
                                <MinusCircle size={15} />
                              </button>
                            </div>
                          </div>
                        </td>

                        <td style={{ padding: '14px 16px' }}>
                          <span
                            className="badge"
                            style={{
                              backgroundColor: isBanned ? '#fef2f2' : '#ecfdf5',
                              color: isBanned ? '#b91c1c' : '#047857'
                            }}
                          >
                            {isBanned ? 'Banned' : 'Active'}
                          </span>
                        </td>

                        <td style={{ padding: '14px 16px', color: 'var(--text-muted)' }}>
                          {u.itemsCount || 0}
                        </td>

                        <td style={{ padding: '14px 16px', textAlign: 'right' }}>
                          <div style={{ display: 'inline-flex', gap: '8px' }}>
                            {/* Toggle Student Button */}
                            <button
                              onClick={() => handleToggleStudent(u)}
                              className="btn btn-secondary"
                              style={{ padding: '6px 10px', fontSize: '0.75rem' }}
                              title={isStudent ? 'Revoke Student Verification' : 'Verify Student Status'}
                            >
                              <GraduationCap size={14} />
                              <span>{isStudent ? 'Unverify' : 'Verify Student'}</span>
                            </button>

                            {/* Ban / Unban Button */}
                            <button
                              onClick={() => handleToggleBan(u)}
                              className="btn btn-secondary"
                              style={{
                                padding: '6px 10px',
                                fontSize: '0.75rem',
                                color: isBanned ? '#047857' : '#b91c1c',
                                borderColor: isBanned ? '#a7f3d0' : '#fca5a5'
                              }}
                              title={isBanned ? 'Restore Active User' : 'Ban User'}
                            >
                              {isBanned ? <UserCheck size={14} /> : <Ban size={14} />}
                              <span>{isBanned ? 'Unban' : 'Ban'}</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={7} style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                      No registered users found matching the filter.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

        </div>
      )}

      {/* TAB 3: Product Moderation */}
      {activeTab === 'items' && (
        <div className="animate-fade-in">
          
          {/* Filter Row */}
          <div className="glass-card" style={{ padding: '20px', marginBottom: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flex: '1', maxWidth: '400px' }}>
              <div style={{ position: 'relative', width: '100%' }}>
                <Search size={16} style={{ position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                <input
                  type="text"
                  placeholder="Search item title or city..."
                  value={itemSearch}
                  onChange={(e) => setItemSearch(e.target.value)}
                  className="form-input"
                  style={{ paddingLeft: '40px' }}
                />
              </div>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <select
                value={itemStatusFilter}
                onChange={(e) => setItemStatusFilter(e.target.value)}
                className="form-input"
                style={{ width: 'auto' }}
              >
                <option value="all">All Statuses</option>
                <option value="active">Active Only</option>
                <option value="revoked">Revoked / Taken Down</option>
                <option value="sold">Sold / Handed Over</option>
                <option value="deleted">Deleted</option>
              </select>

              <button
                onClick={() => setIsPostModalOpen(true)}
                className="btn btn-primary"
              >
                <Plus size={16} />
                <span>Post Product</span>
              </button>
            </div>
          </div>

          {/* Items Table */}
          <div className="glass-card" style={{ padding: '0', overflow: 'hidden' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.9rem' }}>
              <thead style={{ backgroundColor: '#f8fafc', borderBottom: '1px solid var(--border-subtle)', color: 'var(--text-muted)' }}>
                <tr>
                  <th style={{ padding: '16px' }}>Item</th>
                  <th style={{ padding: '16px' }}>Seller</th>
                  <th style={{ padding: '16px' }}>Category</th>
                  <th style={{ padding: '16px' }}>Price</th>
                  <th style={{ padding: '16px' }}>Status</th>
                  <th style={{ padding: '16px', textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {items.length > 0 ? (
                  items.map((it) => {
                    const itemId = it.id || it._id || '';
                    const price = it.priceNzd ? `$${it.priceNzd}` : `$${(it.price / 100).toFixed(0)}`;
                    const img = it.imageUrl || (it.images && it.images[0]?.url) || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=100';

                    return (
                      <tr key={itemId} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                        <td style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: '12px' }}>
                          <img
                            src={img}
                            alt=""
                            style={{ width: '48px', height: '48px', objectFit: 'cover', borderRadius: '8px' }}
                          />
                          <div>
                            <Link to={`/products/${itemId}`} style={{ fontWeight: 700, color: 'var(--text-main)' }}>
                              {it.title}
                            </Link>
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{it.location?.city || 'Auckland'}</div>
                          </div>
                        </td>

                        <td style={{ padding: '14px 16px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                            <span style={{ fontWeight: 600, fontSize: '0.85rem' }}>{it.seller?.displayName || 'Kiwi Seller'}</span>
                            {it.seller?.isStudentVerified && (
                              <span title="Student Verified">
                                <GraduationCap size={14} color="#2563eb" />
                              </span>
                            )}
                          </div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{it.seller?.email}</div>
                        </td>

                        <td style={{ padding: '14px 16px' }}>
                          <span className="badge" style={{ backgroundColor: '#f1f5f9', color: '#475569' }}>
                            {it.category}
                          </span>
                        </td>

                        <td style={{ padding: '14px 16px', fontWeight: 700, color: 'var(--primary-700)' }}>
                          {price} NZD
                        </td>

                        <td style={{ padding: '14px 16px' }}>
                          <span
                            className="badge"
                            style={{
                              backgroundColor:
                                it.status === 'active'
                                  ? '#ecfdf5'
                                  : it.status === 'revoked'
                                  ? '#fef2f2'
                                  : '#f1f5f9',
                              color:
                                it.status === 'active'
                                  ? '#047857'
                                  : it.status === 'revoked'
                                  ? '#b91c1c'
                                  : '#64748b',
                            }}
                          >
                            {it.status === 'active' ? 'Active' : it.status === 'revoked' ? 'Revoked' : it.status}
                          </span>
                        </td>

                        <td style={{ padding: '14px 16px', textAlign: 'right' }}>
                          <div style={{ display: 'inline-flex', gap: '8px' }}>
                            {it.status === 'active' ? (
                              <button
                                onClick={() => handleUpdateItemStatus(itemId, 'revoked')}
                                className="btn btn-secondary"
                                style={{ padding: '6px 12px', fontSize: '0.8rem', color: '#b91c1c', borderColor: '#fca5a5' }}
                                title="Revoke / Take Down Item"
                              >
                                <EyeOff size={14} />
                                <span>Take Down</span>
                              </button>
                            ) : (
                              <button
                                onClick={() => handleUpdateItemStatus(itemId, 'active')}
                                className="btn btn-secondary"
                                style={{ padding: '6px 12px', fontSize: '0.8rem', color: 'var(--primary-700)', borderColor: 'var(--primary-300)' }}
                                title="Reactivate Item"
                              >
                                <CheckCircle size={14} />
                                <span>Reactivate</span>
                              </button>
                            )}

                            {/* Reassign / Transfer Button */}
                            <button
                              onClick={() => {
                                setReassignModalItem(it);
                                setReassignTargetEmail(it.seller?.email || '');
                                setReassignError(null);
                                setReassignSuccess(null);
                              }}
                              className="btn btn-secondary"
                              style={{ padding: '6px 12px', fontSize: '0.8rem', color: '#2563eb', borderColor: '#bfdbfe' }}
                              title="Transfer / Reassign Listing to User Account"
                            >
                              <ArrowRightLeft size={14} />
                              <span>Transfer</span>
                            </button>

                            <button
                              onClick={() => handleUpdateItemStatus(itemId, 'deleted')}
                              className="btn btn-secondary"
                              style={{ padding: '6px 10px', fontSize: '0.8rem', color: '#ef4444' }}
                              title="Delete Item"
                            >
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={6} style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                      No items found matching the current moderation filter.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

        </div>
      )}

      {/* TAB 4: Category Governance */}
      {activeTab === 'categories' && (
        <div className="animate-fade-in">
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '32px' }}>
            
            {/* Create Category Form */}
            <div className="glass-card" style={{ padding: '24px', height: 'fit-content' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 700, marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Plus size={18} color="var(--primary-600)" />
                <span>Create New Category</span>
              </h3>

              <form onSubmit={handleCreateCategory} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Category Name *</label>
                  <input
                    type="text"
                    placeholder="e.g. Vintage Audio / Pet Supplies"
                    value={newCatName}
                    onChange={(e) => setNewCatName(e.target.value)}
                    className="form-input"
                    required
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Icon</label>
                  <select
                    value={newCatIcon}
                    onChange={(e) => setNewCatIcon(e.target.value)}
                    className="form-input"
                  >
                    <option value="Package">Package (Default)</option>
                    <option value="Armchair">Armchair / Furniture</option>
                    <option value="Tv">Tv / Tech</option>
                    <option value="Tent">Tent / Outdoor</option>
                    <option value="Shirt">Shirt / Apparel</option>
                    <option value="Wrench">Wrench / Tools</option>
                    <option value="Utensils">Utensils / Kitchen</option>
                    <option value="Flower2">Flower / Plants</option>
                    <option value="Trophy">Trophy / Sports</option>
                    <option value="BookOpen">Book / Media</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Description (Optional)</label>
                  <textarea
                    rows={2}
                    placeholder="Brief description for category tags..."
                    value={newCatDesc}
                    onChange={(e) => setNewCatDesc(e.target.value)}
                    className="form-input"
                  />
                </div>

                <button
                  type="submit"
                  disabled={catActionLoading}
                  className="btn btn-primary"
                  style={{ width: '100%', padding: '12px' }}
                >
                  {catActionLoading ? 'Saving...' : 'Add Category'}
                </button>
              </form>
            </div>

            {/* Existing Categories Table */}
            <div className="glass-card" style={{ padding: '0', overflow: 'hidden' }}>
              <div style={{ padding: '20px 24px', borderBottom: '1px solid var(--border-subtle)', fontWeight: 700, fontSize: '1.05rem' }}>
                Existing Categories ({categories.length})
              </div>
              <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left', fontSize: '0.9rem' }}>
                <thead style={{ backgroundColor: '#f8fafc', borderBottom: '1px solid var(--border-subtle)', color: 'var(--text-muted)' }}>
                  <tr>
                    <th style={{ padding: '14px 20px' }}>Name</th>
                    <th style={{ padding: '14px 20px' }}>Status</th>
                    <th style={{ padding: '14px 20px', textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {categories.map((c) => (
                    <tr key={c.id || c._id} style={{ borderBottom: '1px solid var(--border-subtle)' }}>
                      <td style={{ padding: '14px 20px', fontWeight: 600 }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <Tag size={15} color="var(--primary-600)" />
                          <span>{c.name}</span>
                        </div>
                        {c.description && <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{c.description}</div>}
                      </td>

                      <td style={{ padding: '14px 20px' }}>
                        <span
                          className="badge"
                          style={{
                            backgroundColor: c.isActive ? '#ecfdf5' : '#fef2f2',
                            color: c.isActive ? '#047857' : '#b91c1c',
                          }}
                        >
                          {c.isActive ? 'Active' : 'Disabled'}
                        </span>
                      </td>

                      <td style={{ padding: '14px 20px', textAlign: 'right' }}>
                        <div style={{ display: 'inline-flex', gap: '8px' }}>
                          <button
                            onClick={() => handleToggleCategory(c)}
                            className="btn btn-secondary"
                            style={{ padding: '4px 8px', fontSize: '0.75rem' }}
                            title={c.isActive ? 'Disable Category' : 'Enable Category'}
                          >
                            {c.isActive ? 'Disable' : 'Enable'}
                          </button>
                          <button
                            onClick={() => handleDeleteCategory(c)}
                            className="btn btn-secondary"
                            style={{ padding: '4px 8px', fontSize: '0.75rem', color: '#ef4444' }}
                            title="Delete Category"
                          >
                            <Trash2 size={13} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

          </div>
        </div>
      )}

      {/* Post New Item Modal */}
      <PostItemModal
        isOpen={isPostModalOpen}
        onClose={() => setIsPostModalOpen(false)}
        onItemCreated={() => {
          checkAdminAndFetch();
        }}
      />

      {/* Transfer / Reassign Listing Modal */}
      {reassignModalItem && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 42, 0.65)',
            backdropFilter: 'blur(6px)',
            zIndex: 250,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '20px',
          }}
          onClick={() => setReassignModalItem(null)}
        >
          <div
            className="glass-card animate-fade-in"
            style={{
              width: '100%',
              maxWidth: '480px',
              backgroundColor: '#ffffff',
              padding: '28px',
              position: 'relative',
              boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setReassignModalItem(null)}
              style={{ position: 'absolute', top: '16px', right: '16px', color: 'var(--text-muted)', cursor: 'pointer', background: 'none', border: 'none' }}
            >
              <X size={20} />
            </button>

            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
              <div style={{ width: '40px', height: '40px', borderRadius: '10px', backgroundColor: '#eff6ff', color: '#2563eb', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <ArrowRightLeft size={20} />
              </div>
              <div>
                <h3 style={{ fontSize: '1.2rem', fontWeight: 800 }}>Transfer Listing Ownership</h3>
                <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Reassign this item to another registered member</p>
              </div>
            </div>

            {/* Item Preview */}
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px', backgroundColor: '#f8fafc', borderRadius: 'var(--radius-md)', marginBottom: '18px', border: '1px solid var(--border-subtle)' }}>
              <img
                src={reassignModalItem.imageUrl || (reassignModalItem.images && reassignModalItem.images[0]?.url) || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=100'}
                alt=""
                style={{ width: '44px', height: '44px', objectFit: 'cover', borderRadius: '8px' }}
              />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: '0.9rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{reassignModalItem.title}</div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                  Current Seller: <strong>{reassignModalItem.seller?.displayName || 'Kiwi Member'}</strong> ({reassignModalItem.seller?.email || reassignModalItem.ownerId || 'N/A'})
                </div>
              </div>
            </div>

            {reassignError && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 14px', backgroundColor: '#fef2f2', border: '1px solid #fecaca', color: '#b91c1c', borderRadius: 'var(--radius-md)', fontSize: '0.85rem', marginBottom: '16px' }}>
                <AlertCircle size={16} />
                <span>{reassignError}</span>
              </div>
            )}

            {reassignSuccess && (
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 14px', backgroundColor: '#f0fdf4', border: '1px solid #bbf7d0', color: '#166534', borderRadius: 'var(--radius-md)', fontSize: '0.85rem', marginBottom: '16px' }}>
                <CheckCircle2 size={16} />
                <span>{reassignSuccess}</span>
              </div>
            )}

            <form onSubmit={handleReassignItem}>
              <div style={{ marginBottom: '20px' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>
                  Target User Account Email *
                </label>
                <input
                  type="email"
                  placeholder="e.g. demo@example.com"
                  value={reassignTargetEmail}
                  onChange={(e) => setReassignTargetEmail(e.target.value)}
                  className="form-input"
                  list="registered-users-list"
                  required
                />
                <datalist id="registered-users-list">
                  {usersList.map((u) => (
                    <option key={u.id || u._id} value={u.email}>
                      {u.displayName} ({u.email})
                    </option>
                  ))}
                </datalist>
                <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '4px', display: 'block' }}>
                  Select an existing registered KiwiShare member from the suggestions or type their email.
                </span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                <button
                  type="button"
                  onClick={() => setReassignModalItem(null)}
                  className="btn btn-secondary"
                  disabled={reassignLoading}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn-primary"
                  disabled={reassignLoading || !reassignTargetEmail.trim()}
                >
                  {reassignLoading ? <Loader2 size={16} style={{ animation: 'spin 1s linear infinite' }} /> : <UserPlus size={16} />}
                  <span>Confirm Transfer</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
};
