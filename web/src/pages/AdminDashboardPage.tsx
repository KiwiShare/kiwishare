import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate, Link } from 'react-router-dom';
import { 
  adminApi, 
  categoriesApi, 
  AdminStats, 
  CategoryItem, 
  UsedItem 
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
  Edit3, 
  EyeOff, 
  CheckCircle, 
  AlertTriangle, 
  Loader2, 
  TrendingUp,
  Search
} from 'lucide-react';

export const AdminDashboardPage: React.FC = () => {
  const { user, isLoggedIn } = useAuth();
  const navigate = useNavigate();

  const [activeTab, setActiveTab] = useState<'overview' | 'categories' | 'items'>('overview');
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [categories, setCategories] = useState<CategoryItem[]>([]);
  const [items, setItems] = useState<UsedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [isPostModalOpen, setIsPostModalOpen] = useState(false);

  // New Category Form State
  const [newCatName, setNewCatName] = useState('');
  const [newCatIcon, setNewCatIcon] = useState('Package');
  const [newCatDesc, setNewCatDesc] = useState('');
  const [catActionLoading, setCatActionLoading] = useState(false);

  // Item Filter State
  const [itemStatusFilter, setItemStatusFilter] = useState('all');
  const [itemSearch, setItemSearch] = useState('');

  const checkAdminAndFetch = async () => {
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
      const [statsRes, catsRes, itemsRes] = await Promise.all([
        adminApi.getStats().catch(() => ({ stats: null })),
        categoriesApi.getCategories(true).catch(() => ({ categories: [] })),
        adminApi.getItems({ status: itemStatusFilter, search: itemSearch }).catch(() => ({ items: [] })),
      ]);

      if (statsRes.stats) setStats(statsRes.stats);
      if (catsRes.categories) setCategories(catsRes.categories);
      if (itemsRes.items) setItems(itemsRes.items);
    } catch (err) {
      console.error('Failed to load admin dashboard data:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    checkAdminAndFetch();
  }, [isLoggedIn, user]);

  useEffect(() => {
    if (activeTab === 'items') {
      adminApi.getItems({ status: itemStatusFilter, search: itemSearch }).then((res) => {
        if (res.items) setItems(res.items);
      });
    }
  }, [itemStatusFilter, itemSearch, activeTab]);

  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newCatName.trim()) return;

    try {
      setCatActionLoading(true);
      await categoriesApi.createCategory({
        name: newCatName.trim(),
        icon: newCatIcon,
        description: newCatDesc.trim(),
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

  const handleDeleteCategory = async (catId: string) => {
    if (!confirm('Are you sure you want to delete this category?')) return;
    try {
      await categoriesApi.deleteCategory(catId);
      setCategories((prev) => prev.filter((c) => (c.id || c._id) !== catId));
    } catch (err: any) {
      alert(err.message || 'Failed to delete category.');
    }
  };

  const handleUpdateItemStatus = async (itemId: string, newStatus: 'active' | 'revoked' | 'sold' | 'deleted') => {
    try {
      await adminApi.updateItemStatus(itemId, newStatus);
      setItems((prev) =>
        prev.map((it) => ((it.id || it._id) === itemId ? { ...it, status: newStatus } : it))
      );
      // Refresh stats in background
      adminApi.getStats().then((res) => { if (res.stats) setStats(res.stats); });
    } catch (err: any) {
      alert(err.message || 'Failed to update item status.');
    }
  };

  if (loading && !stats) {
    return (
      <div className="container" style={{ padding: '80px 20px', textAlign: 'center' }}>
        <Loader2 size={36} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
        <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
        <p style={{ marginTop: '16px', color: 'var(--text-muted)' }}>Loading Admin Portal...</p>
      </div>
    );
  }

  return (
    <div className="container" style={{ padding: '32px 20px 80px' }}>
      
      {/* Header Banner */}
      <div className="glass-card" style={{ padding: '28px', marginBottom: '32px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <div
            style={{
              width: '52px',
              height: '52px',
              borderRadius: '16px',
              background: 'linear-gradient(135deg, #0f172a, #334155)',
              color: '#fff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: 'var(--shadow-lg)',
            }}
          >
            <ShieldCheck size={28} color="#34d399" />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <h1 style={{ fontSize: '1.8rem', fontWeight: 800 }}>KiwiShare Global Control Board</h1>
              <span className="badge" style={{ backgroundColor: '#ecfdf5', color: '#047857' }}>
                ADMIN LEVEL
              </span>
            </div>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginTop: '2px' }}>
              Logged in as {user?.email} • Real-time Multi-Platform Management
            </p>
          </div>
        </div>

        {/* Global Action: Post Item */}
        <button
          onClick={() => setIsPostModalOpen(true)}
          className="btn btn-primary"
          style={{ padding: '12px 22px' }}
        >
          <Plus size={18} />
          <span>Publish New Product</span>
        </button>
      </div>

      {/* Tabs Bar */}
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
            borderBottom: activeTab === 'overview' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'overview' ? 'var(--primary-700)' : 'var(--text-muted)',
            cursor: 'pointer',
          }}
        >
          <LayoutDashboard size={18} />
          <span>Global Overview & Analytics</span>
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
            borderBottom: activeTab === 'categories' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'categories' ? 'var(--primary-700)' : 'var(--text-muted)',
            cursor: 'pointer',
          }}
        >
          <Tag size={18} />
          <span>Category Engine ({categories.length})</span>
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
            borderBottom: activeTab === 'items' ? '3px solid var(--primary-600)' : '3px solid transparent',
            color: activeTab === 'items' ? 'var(--primary-700)' : 'var(--text-muted)',
            cursor: 'pointer',
          }}
        >
          <Package size={18} />
          <span>Product Moderation & Inventory</span>
        </button>
      </div>

      {/* TAB 1: Global Overview */}
      {activeTab === 'overview' && stats && (
        <div className="animate-fade-in">
          
          {/* Top KPI Cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '20px', marginBottom: '32px' }}>
            
            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>
                Total Community Users
              </div>
              <div style={{ fontSize: '2.2rem', fontWeight: 800, color: 'var(--text-main)', marginTop: '8px' }}>
                {stats.totalUsers}
              </div>
              <div style={{ fontSize: '0.85rem', color: 'var(--primary-600)', marginTop: '4px', fontWeight: 600 }}>
                Across Web & Mobile Clients
              </div>
            </div>

            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>
                Active Pre-Loved Items
              </div>
              <div style={{ fontSize: '2.2rem', fontWeight: 800, color: 'var(--primary-700)', marginTop: '8px' }}>
                {stats.activeItems} <span style={{ fontSize: '1rem', color: 'var(--text-muted)', fontWeight: 500 }}>/ {stats.totalItems} total</span>
              </div>
              <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                {stats.revokedItems} Revoked / {stats.soldItems} Handed Over
              </div>
            </div>

            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>
                Watchlist Bookmarks
              </div>
              <div style={{ fontSize: '2.2rem', fontWeight: 800, color: '#f43f5e', marginTop: '8px' }}>
                {stats.totalWatchlistEntries}
              </div>
              <div style={{ fontSize: '0.85rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                User engagement interactions
              </div>
            </div>

            <div className="glass-card" style={{ padding: '24px' }}>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', fontWeight: 700, textTransform: 'uppercase' }}>
                Active Categories
              </div>
              <div style={{ fontSize: '2.2rem', fontWeight: 800, color: 'var(--text-main)', marginTop: '8px' }}>
                {categories.length}
              </div>
              <div style={{ fontSize: '0.85rem', color: 'var(--primary-600)', marginTop: '4px' }}>
                Fully dynamic MongoDB collection
              </div>
            </div>

          </div>

          {/* Platform Traffic Breakdown */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '24px', marginBottom: '32px' }}>
            
            <div className="glass-card" style={{ padding: '28px' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 800, marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <TrendingUp size={20} color="var(--primary-600)" />
                <span>Multi-Platform User Distribution</span>
              </h3>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '0.9rem', fontWeight: 600 }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Globe size={16} color="var(--primary-600)" /> Web Browser</span>
                    <span>{stats.platformStats.web || 0} users</span>
                  </div>
                  <div style={{ height: '8px', backgroundColor: '#e2e8f0', borderRadius: 'var(--radius-full)', overflow: 'hidden' }}>
                    <div style={{ width: `${Math.min(100, ((stats.platformStats.web || 0) / (stats.totalUsers || 1)) * 100)}%`, height: '100%', backgroundColor: 'var(--primary-500)' }} />
                  </div>
                </div>

                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '0.9rem', fontWeight: 600 }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Smartphone size={16} color="#0284c7" /> iOS App (Flutter)</span>
                    <span>{stats.platformStats.mobile_ios || 0} users</span>
                  </div>
                  <div style={{ height: '8px', backgroundColor: '#e2e8f0', borderRadius: 'var(--radius-full)', overflow: 'hidden' }}>
                    <div style={{ width: `${Math.min(100, ((stats.platformStats.mobile_ios || 0) / (stats.totalUsers || 1)) * 100)}%`, height: '100%', backgroundColor: '#0284c7' }} />
                  </div>
                </div>

                <div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '6px', fontSize: '0.9rem', fontWeight: 600 }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><Smartphone size={16} color="#16a34a" /> Android App (Flutter)</span>
                    <span>{stats.platformStats.mobile_android || 0} users</span>
                  </div>
                  <div style={{ height: '8px', backgroundColor: '#e2e8f0', borderRadius: 'var(--radius-full)', overflow: 'hidden' }}>
                    <div style={{ width: `${Math.min(100, ((stats.platformStats.mobile_android || 0) / (stats.totalUsers || 1)) * 100)}%`, height: '100%', backgroundColor: '#16a34a' }} />
                  </div>
                </div>
              </div>
            </div>

            {/* Category Breakdown */}
            <div className="glass-card" style={{ padding: '28px' }}>
              <h3 style={{ fontSize: '1.2rem', fontWeight: 800, marginBottom: '16px' }}>
                Inventory Volume by Category
              </h3>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px' }}>
                {stats.categoryDistribution.map((c) => (
                  <div
                    key={c.category}
                    style={{
                      backgroundColor: '#f1f5f9',
                      padding: '10px 16px',
                      borderRadius: 'var(--radius-md)',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      fontSize: '0.9rem',
                      fontWeight: 600,
                    }}
                  >
                    <span>{c.category}</span>
                    <span style={{ backgroundColor: 'var(--primary-600)', color: '#fff', padding: '2px 8px', borderRadius: 'var(--radius-full)', fontSize: '0.75rem' }}>
                      {c.count}
                    </span>
                  </div>
                ))}
              </div>
            </div>

          </div>

        </div>
      )}

      {/* TAB 2: Category Management */}
      {activeTab === 'categories' && (
        <div className="animate-fade-in">
          
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '32px', alignItems: 'start' }}>
            
            {/* Create Category Card */}
            <div className="glass-card" style={{ padding: '28px' }}>
              <h3 style={{ fontSize: '1.3rem', fontWeight: 800, marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Plus size={20} color="var(--primary-600)" />
                <span>Add New Category</span>
              </h3>

              <form onSubmit={handleCreateCategory} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Category Name *</label>
                  <input
                    type="text"
                    placeholder="e.g. Sports & Outdoors"
                    value={newCatName}
                    onChange={(e) => setNewCatName(e.target.value)}
                    className="form-input"
                    required
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Lucide Icon</label>
                  <select
                    value={newCatIcon}
                    onChange={(e) => setNewCatIcon(e.target.value)}
                    className="form-input"
                  >
                    <option value="Armchair">Armchair (Furniture)</option>
                    <option value="Tv">Tv (Electronics)</option>
                    <option value="Tent">Tent (Outdoor)</option>
                    <option value="Shirt">Shirt (Clothing)</option>
                    <option value="Wrench">Wrench (Tools)</option>
                    <option value="Utensils">Utensils (Kitchen)</option>
                    <option value="Flower2">Flower2 (Plants)</option>
                    <option value="Trophy">Trophy (Sports)</option>
                    <option value="BookOpen">BookOpen (Books/Media)</option>
                    <option value="Package">Package (General)</option>
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Description</label>
                  <input
                    type="text"
                    placeholder="Brief description for filters..."
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
                  {catActionLoading ? <Loader2 size={18} style={{ animation: 'spin 1s linear infinite' }} /> : 'Add Category to Database'}
                </button>
              </form>
            </div>

            {/* Existing Categories Table */}
            <div className="glass-card" style={{ padding: '28px' }}>
              <h3 style={{ fontSize: '1.3rem', fontWeight: 800, marginBottom: '16px' }}>
                Active Categories in MongoDB ({categories.length})
              </h3>

              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                {categories.map((cat) => (
                  <div
                    key={cat.id || cat._id}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      padding: '14px 18px',
                      backgroundColor: '#f8fafc',
                      borderRadius: 'var(--radius-md)',
                      border: '1px solid var(--border-subtle)',
                    }}
                  >
                    <div>
                      <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-main)' }}>
                        {cat.name} <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>({cat.slug})</span>
                      </div>
                      <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                        Icon: {cat.icon} • Items: {cat.itemCount || 0}
                      </div>
                    </div>

                    <button
                      onClick={() => handleDeleteCategory(cat.id || cat._id || '')}
                      className="btn-icon"
                      style={{ color: '#ef4444', backgroundColor: '#fee2e2' }}
                      title="Delete Category"
                    >
                      <Trash2 size={16} />
                    </button>
                  </div>
                ))}
              </div>
            </div>

          </div>

        </div>
      )}

      {/* TAB 3: Product Inventory & Moderation */}
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
                  <th style={{ padding: '16px' }}>Category</th>
                  <th style={{ padding: '16px' }}>Price</th>
                  <th style={{ padding: '16px' }}>Location</th>
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
                            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>ID: {itemId.slice(-6)}</div>
                          </div>
                        </td>

                        <td style={{ padding: '14px 16px' }}>
                          <span className="badge" style={{ backgroundColor: '#f1f5f9', color: '#475569' }}>
                            {it.category}
                          </span>
                        </td>

                        <td style={{ padding: '14px 16px', fontWeight: 700, color: 'var(--primary-700)' }}>
                          {price} NZD
                        </td>

                        <td style={{ padding: '14px 16px', color: 'var(--text-muted)' }}>
                          {it.location?.city || 'Auckland'}
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

      {/* Post New Item Modal */}
      <PostItemModal
        isOpen={isPostModalOpen}
        onClose={() => setIsPostModalOpen(false)}
        onItemCreated={() => {
          checkAdminAndFetch();
        }}
      />

    </div>
  );
};
