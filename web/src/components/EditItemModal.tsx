import React, { useState, useEffect, useRef } from 'react';
import { categoriesApi, itemsApi, uploadApi, CategoryItem, UsedItem } from '../api/client';
import {
  X,
  UploadCloud,
  DollarSign,
  Loader2,
  AlertCircle,
  Sparkles,
  RotateCcw,
  CheckCircle,
} from 'lucide-react';

export interface EditItemModalProps {
  isOpen?: boolean;
  item: UsedItem | null;
  onClose: () => void;
  onItemUpdated?: (updatedItem: UsedItem) => void;
  onUpdated?: (updatedItem: UsedItem) => void;
}

export const EditItemModal: React.FC<EditItemModalProps> = ({
  isOpen = true,
  item,
  onClose,
  onItemUpdated,
  onUpdated,
}) => {
  const [categories, setCategories] = useState<CategoryItem[]>([]);
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('');
  const [priceNzd, setPriceNzd] = useState('');
  const [condition, setCondition] = useState('good');
  const [status, setStatus] = useState('active');
  const [city, setCity] = useState('Auckland');
  const [suburb, setSuburb] = useState('');
  const [uploadedImages, setUploadedImages] = useState<string[]>([]);
  const [description, setDescription] = useState('');
  const [isSustainable, setIsSustainable] = useState(true);

  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);

  // Initialize form when item or isOpen changes
  useEffect(() => {
    if (isOpen && item) {
      setTitle(item.title || '');
      setCategory(item.category || '');
      setPriceNzd(
        item.isFree
          ? '0'
          : item.priceNzd !== undefined
            ? String(item.priceNzd)
            : typeof item.price === 'number'
              ? String(item.price / 100)
              : ''
      );
      setCondition(item.condition || 'good');
      setStatus(item.status || 'active');
      setCity(item.location?.city || 'Auckland');
      setSuburb(item.location?.suburb || '');
      setDescription(item.description || '');
      setIsSustainable(item.isSustainable ?? true);

      // Populate images
      const imgs: string[] = [];
      if (Array.isArray(item.images) && item.images.length > 0) {
        imgs.push(...item.images.map((im: any) => (typeof im === 'string' ? im : im.url || '')));
      } else if (item.imageUrl) {
        imgs.push(item.imageUrl);
      }
      setUploadedImages(imgs.filter(Boolean));

      // Fetch category options
      categoriesApi.getCategories().then((res) => {
        if (res.categories && res.categories.length > 0) {
          setCategories(res.categories);
        }
      }).catch(() => {});
    }
  }, [isOpen, item]);

  if (!isOpen || !item) return null;

  const handleMultipleFiles = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    try {
      setUploading(true);
      setError(null);
      const newUrls: string[] = [];

      for (let i = 0; i < files.length; i++) {
        setUploadProgress(`Uploading photo ${i + 1} of ${files.length} to Cloudflare R2...`);
        const res = await uploadApi.uploadImage(files[i]);
        if (res.url) {
          newUrls.push(res.url);
        }
      }

      setUploadedImages((prev) => [...prev, ...newUrls]);
    } catch (err: any) {
      setError(err.message || 'Photo upload failed. Please try again.');
    } finally {
      setUploading(false);
      setUploadProgress(null);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const removeImage = (indexToRemove: number) => {
    setUploadedImages((prev) => prev.filter((_, idx) => idx !== indexToRemove));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!title.trim()) {
      setError('Please provide a listing title.');
      return;
    }

    const numericPrice = parseFloat(priceNzd);
    if (isNaN(numericPrice) || numericPrice < 0) {
      setError('Please enter a valid price (0 or more for Free).');
      return;
    }

    try {
      setLoading(true);
      const targetId = item.id || item._id;
      if (!targetId) {
        setError('Invalid item ID.');
        return;
      }
      const imagesPayload = uploadedImages.map((url, idx) => ({ url, sortOrder: idx }));

      const res = await itemsApi.updateItem(targetId, {
        title: title.trim(),
        description: description.trim(),
        category,
        priceNzd: numericPrice === 0 ? '0' : priceNzd,
        condition,
        status,
        city,
        suburb,
        imageUrl: uploadedImages[0] || '',
        images: imagesPayload,
        isSustainable,
      });

      if (res.status === 'success' || res.item) {
        const updatedItem = res.item || { ...item, title, description, priceNzd, status };
        const mergedItem = { ...item, ...updatedItem, seller: updatedItem.seller || item.seller };
        onItemUpdated?.(mergedItem);
        onUpdated?.(mergedItem);
        onClose();
      }
    } catch (err: any) {
      setError(err.message || 'Failed to update listing.');
    } finally {
      setLoading(false);
    }
  };

  const isFree = parseFloat(priceNzd) === 0 || priceNzd === '0';

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: 'rgba(15, 23, 42, 0.65)',
        backdropFilter: 'blur(4px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
        padding: '20px',
      }}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        className="glass-card animate-scale-up"
        style={{
          backgroundColor: '#fff',
          maxWidth: '680px',
          width: '100%',
          maxHeight: '90vh',
          display: 'flex',
          flexDirection: 'column',
          borderRadius: 'var(--radius-xl)',
          overflow: 'hidden',
          boxShadow: 'var(--shadow-xl)',
          border: '1px solid var(--border-subtle)',
        }}
      >
        {/* Header */}
        <div
          style={{
            padding: '20px 24px',
            borderBottom: '1px solid var(--border-subtle)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div
              style={{
                width: '38px',
                height: '38px',
                borderRadius: '10px',
                backgroundColor: 'var(--primary-100)',
                color: 'var(--primary-700)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <Sparkles size={20} />
            </div>
            <div>
              <h2 style={{ fontSize: '1.25rem', fontWeight: 800, margin: 0 }}>Edit Listing</h2>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', margin: 0 }}>
                Update pricing, photos, status, and description
              </p>
            </div>
          </div>

          <button
            type="button"
            onClick={onClose}
            className="btn btn-secondary"
            style={{ padding: '6px', borderRadius: '50%' }}
          >
            <X size={18} />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
          {error && (
            <div
              style={{
                backgroundColor: '#fee2e2',
                color: '#b91c1c',
                padding: '12px 16px',
                borderRadius: 'var(--radius-md)',
                marginBottom: '20px',
                fontSize: '0.9rem',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
              }}
            >
              <AlertCircle size={18} />
              <span>{error}</span>
            </div>
          )}

          {/* Listing Status Bar / Re-list Button */}
          <div
            style={{
              padding: '14px 18px',
              backgroundColor: status === 'active' ? '#ecfdf5' : '#f8fafc',
              border: `1.5px solid ${status === 'active' ? '#a7f3d0' : '#e2e8f0'}`,
              borderRadius: 'var(--radius-lg)',
              marginBottom: '20px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              gap: '12px',
              flexWrap: 'wrap',
            }}
          >
            <div>
              <div style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-main)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                <span>Listing Status:</span>
                <span
                  style={{
                    textTransform: 'uppercase',
                    fontSize: '0.75rem',
                    padding: '2px 8px',
                    borderRadius: '12px',
                    backgroundColor: status === 'active' ? '#10b981' : status === 'reserved' ? '#f59e0b' : '#64748b',
                    color: '#fff',
                  }}
                >
                  {status}
                </span>
              </div>
              <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                {status === 'active'
                  ? 'Currently visible in discovery and searches.'
                  : status === 'reserved'
                    ? 'Temporarily reserved for a buyer.'
                    : 'Marked as completed / sold out.'}
              </div>
            </div>

            <div style={{ display: 'flex', gap: '8px' }}>
              {status !== 'active' ? (
                <button
                  type="button"
                  onClick={() => setStatus('active')}
                  className="btn btn-primary"
                  style={{ padding: '6px 14px', fontSize: '0.85rem' }}
                >
                  <RotateCcw size={14} />
                  <span>Re-list Active</span>
                </button>
              ) : (
                <>
                  <button
                    type="button"
                    onClick={() => setStatus('reserved')}
                    className="btn btn-secondary"
                    style={{ padding: '6px 12px', fontSize: '0.82rem' }}
                  >
                    Mark Reserved
                  </button>
                  <button
                    type="button"
                    onClick={() => setStatus('sold')}
                    className="btn btn-secondary"
                    style={{ padding: '6px 12px', fontSize: '0.82rem', color: '#64748b' }}
                  >
                    Mark Sold
                  </button>
                </>
              )}
            </div>
          </div>

          {/* Title Input */}
          <div style={{ marginBottom: '18px' }}>
            <label style={{ display: 'block', fontWeight: 700, fontSize: '0.9rem', marginBottom: '6px' }}>
              Item Title *
            </label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="form-input"
              placeholder="e.g. Ergonomic Office Desk Chair"
              required
            />
          </div>

          {/* Category & Price Row */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '18px' }}>
            <div>
              <label style={{ display: 'block', fontWeight: 700, fontSize: '0.9rem', marginBottom: '6px' }}>
                Category
              </label>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="form-input"
              >
                {categories.map((c) => (
                  <option key={c.id} value={c.name}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <label style={{ fontWeight: 700, fontSize: '0.9rem' }}>
                  Price (NZD) *
                </label>
                {isFree && (
                  <span
                    style={{
                      backgroundColor: '#10b981',
                      color: '#fff',
                      fontSize: '0.7rem',
                      fontWeight: 800,
                      padding: '1px 8px',
                      borderRadius: '12px',
                    }}
                  >
                    FREE
                  </span>
                )}
              </div>
              <div style={{ position: 'relative' }}>
                <DollarSign
                  size={16}
                  style={{
                    position: 'absolute',
                    left: '12px',
                    top: '50%',
                    transform: 'translateY(-50%)',
                    color: 'var(--text-muted)',
                  }}
                />
                <input
                  type="number"
                  min="0"
                  step="any"
                  value={priceNzd}
                  onChange={(e) => setPriceNzd(e.target.value)}
                  className="form-input"
                  style={{ paddingLeft: '32px' }}
                  placeholder="0 (Enter 0 for Free)"
                  required
                />
              </div>
            </div>
          </div>

          {/* Condition & Sustainability */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', marginBottom: '18px' }}>
            <div>
              <label style={{ display: 'block', fontWeight: 700, fontSize: '0.9rem', marginBottom: '6px' }}>
                Condition
              </label>
              <select
                value={condition}
                onChange={(e) => setCondition(e.target.value)}
                className="form-input"
              >
                <option value="new">Brand New / Unused</option>
                <option value="like_new">Like New (Mint)</option>
                <option value="good">Good (Light Wear)</option>
                <option value="fair">Fair (Visible Wear)</option>
              </select>
            </div>

            <div>
              <label style={{ display: 'block', fontWeight: 700, fontSize: '0.9rem', marginBottom: '6px' }}>
                Location (City / Suburb)
              </label>
              <div style={{ display: 'flex', gap: '8px' }}>
                <input
                  type="text"
                  value={city}
                  onChange={(e) => setCity(e.target.value)}
                  className="form-input"
                  placeholder="City (e.g. Auckland)"
                  style={{ flex: 1 }}
                />
                <input
                  type="text"
                  value={suburb}
                  onChange={(e) => setSuburb(e.target.value)}
                  className="form-input"
                  placeholder="Suburb (e.g. CBD)"
                  style={{ flex: 1 }}
                />
              </div>
            </div>
          </div>

          {/* Description */}
          <div style={{ marginBottom: '18px' }}>
            <label style={{ display: 'block', fontWeight: 700, fontSize: '0.9rem', marginBottom: '6px' }}>
              Description
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="form-input"
              rows={4}
              placeholder="Describe the item condition, pickup requirements, dimensions..."
            />
          </div>

          {/* Photo Management */}
          <div style={{ marginBottom: '20px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
              <label style={{ fontWeight: 700, fontSize: '0.9rem' }}>
                Listing Photos ({uploadedImages.length})
              </label>
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={uploading}
                className="btn btn-secondary"
                style={{ padding: '6px 12px', fontSize: '0.82rem' }}
              >
                {uploading ? <Loader2 size={14} className="animate-spin" /> : <UploadCloud size={14} />}
                <span>Add Photos</span>
              </button>
            </div>

            <input
              type="file"
              ref={fileInputRef}
              onChange={handleMultipleFiles}
              multiple
              accept="image/*"
              style={{ display: 'none' }}
            />

            {uploadProgress && (
              <div style={{ fontSize: '0.8rem', color: 'var(--primary-600)', marginBottom: '8px', fontWeight: 600 }}>
                {uploadProgress}
              </div>
            )}

            {/* Photo thumbnails grid */}
            {uploadedImages.length > 0 ? (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(90px, 1fr))', gap: '10px' }}>
                {uploadedImages.map((url, idx) => (
                  <div
                    key={idx}
                    style={{
                      position: 'relative',
                      height: '90px',
                      borderRadius: 'var(--radius-md)',
                      overflow: 'hidden',
                      border: idx === 0 ? '2px solid var(--primary-500)' : '1px solid var(--border-subtle)',
                    }}
                  >
                    <img
                      src={url}
                      alt={`Photo ${idx + 1}`}
                      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    />
                    {idx === 0 && (
                      <div
                        style={{
                          position: 'absolute',
                          bottom: 0,
                          left: 0,
                          right: 0,
                          backgroundColor: 'rgba(16, 185, 129, 0.9)',
                          color: '#fff',
                          fontSize: '0.65rem',
                          fontWeight: 700,
                          textAlign: 'center',
                          padding: '1px 0',
                        }}
                      >
                        Cover
                      </div>
                    )}
                    <button
                      type="button"
                      onClick={() => removeImage(idx)}
                      style={{
                        position: 'absolute',
                        top: '4px',
                        right: '4px',
                        backgroundColor: 'rgba(0,0,0,0.6)',
                        color: '#fff',
                        borderRadius: '50%',
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <X size={12} />
                    </button>
                  </div>
                ))}
              </div>
            ) : (
              <div
                onClick={() => fileInputRef.current?.click()}
                style={{
                  border: '2px dashed var(--border-subtle)',
                  borderRadius: 'var(--radius-md)',
                  padding: '24px',
                  textAlign: 'center',
                  cursor: 'pointer',
                  backgroundColor: '#f8fafc',
                }}
              >
                <UploadCloud size={24} color="var(--primary-500)" style={{ margin: '0 auto 6px' }} />
                <div style={{ fontSize: '0.85rem', fontWeight: 600 }}>Click to upload photos</div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>PNG, JPG, WebP supported</div>
              </div>
            )}
          </div>

          {/* Footer Actions */}
          <div
            style={{
              paddingTop: '16px',
              borderTop: '1px solid var(--border-subtle)',
              display: 'flex',
              justifyContent: 'flex-end',
              gap: '12px',
            }}
          >
            <button
              type="button"
              onClick={onClose}
              disabled={loading}
              className="btn btn-secondary"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="btn btn-primary"
              style={{ padding: '10px 24px' }}
            >
              {loading ? <Loader2 size={16} className="animate-spin" /> : <CheckCircle size={16} />}
              <span>Save & Update Listing</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
