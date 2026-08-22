import React, { useState, useEffect, useRef } from 'react';
import { categoriesApi, itemsApi, uploadApi, CategoryItem } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { 
  X, 
  PlusCircle, 
  Image as ImageIcon, 
  UploadCloud, 
  DollarSign, 
  Loader2, 
  AlertCircle, 
  Cloud,
  Layers,
  User
} from 'lucide-react';

interface PostItemModalProps {
  isOpen: boolean;
  onClose: () => void;
  onItemCreated: () => void;
}

export const PostItemModal: React.FC<PostItemModalProps> = ({ isOpen, onClose, onItemCreated }) => {
  const { user } = useAuth();
  const [categories, setCategories] = useState<CategoryItem[]>([]);
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('');
  const [priceNzd, setPriceNzd] = useState('');
  const [condition, setCondition] = useState('good');
  const [city, setCity] = useState('Auckland');
  const [suburb, setSuburb] = useState('');
  const [targetUserEmail, setTargetUserEmail] = useState('demo@example.com');
  const [uploadedImages, setUploadedImages] = useState<string[]>([]);
  const [customImageUrl, setCustomImageUrl] = useState('');
  const [description, setDescription] = useState('');
  const [isSustainable, setIsSustainable] = useState(true);

  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      categoriesApi.getCategories().then((res) => {
        if (res.categories && res.categories.length > 0) {
          setCategories(res.categories);
          setCategory((prev) => prev || res.categories[0].name);
        }
      });
    }
  }, [isOpen]);

  if (!isOpen) return null;

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
      setError(err.message || 'Failed to upload photos to Cloudflare R2.');
    } finally {
      setUploading(false);
      setUploadProgress(null);
      if (fileInputRef.current) {
        fileInputRef.current.value = '';
      }
    }
  };

  const handleAddCustomUrl = () => {
    if (!customImageUrl.trim()) return;
    setUploadedImages((prev) => [...prev, customImageUrl.trim()]);
    setCustomImageUrl('');
  };

  const handleRemoveImage = (index: number) => {
    setUploadedImages((prev) => prev.filter((_, i) => i !== index));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !category || !priceNzd) {
      setError('Please fill in item title, category, and price.');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      const finalImages = uploadedImages.length > 0
        ? uploadedImages
        : ['https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&auto=format&fit=crop&q=80'];

      await itemsApi.createItem({
        title: title.trim(),
        description: description.trim(),
        category,
        priceNzd: priceNzd.trim(),
        condition,
        city,
        suburb: suburb.trim() || undefined,
        imageUrls: finalImages,
        imageUrl: finalImages[0],
        isSustainable,
        targetUserEmail: user?.role === 'admin' && targetUserEmail.trim() ? targetUserEmail.trim() : undefined,
      });

      onItemCreated();
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to publish item.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        backgroundColor: 'rgba(15, 23, 42, 0.65)',
        backdropFilter: 'blur(6px)',
        zIndex: 200,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px',
      }}
      onClick={onClose}
    >
      <div
        className="glass-card animate-fade-in"
        style={{
          width: '100%',
          maxWidth: '640px',
          maxHeight: '90vh',
          overflowY: 'auto',
          padding: '32px',
          backgroundColor: '#ffffff',
          position: 'relative',
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close Button */}
        <button
          onClick={onClose}
          style={{ position: 'absolute', top: '20px', right: '20px', color: 'var(--text-muted)', cursor: 'pointer' }}
        >
          <X size={22} />
        </button>

        {/* Title */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '20px' }}>
          <div
            style={{
              width: '40px',
              height: '40px',
              borderRadius: '12px',
              backgroundColor: 'var(--primary-100)',
              color: 'var(--primary-700)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <PlusCircle size={22} />
          </div>
          <div>
            <h2 style={{ fontSize: '1.4rem', fontWeight: 800 }}>List a Pre-Loved Item</h2>
            <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>Share quality goods with your Kiwi community</p>
          </div>
        </div>

        {/* Error */}
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

        {/* Form */}
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          
          {/* Admin Feature: Bind to User */}
          {user?.role === 'admin' && (
            <div style={{ backgroundColor: '#f0fdf4', padding: '12px 16px', borderRadius: 'var(--radius-md)', border: '1px solid #bbf7d0' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '0.85rem', fontWeight: 700, color: '#15803d', marginBottom: '6px' }}>
                <User size={15} />
                <span>Admin: Assign Listing to User Account</span>
              </label>
              <input
                type="email"
                placeholder="demo@example.com"
                value={targetUserEmail}
                onChange={(e) => setTargetUserEmail(e.target.value)}
                className="form-input"
                style={{ backgroundColor: '#ffffff' }}
              />
              <div style={{ fontSize: '0.75rem', color: '#166534', marginTop: '4px' }}>
                This product will be publicly listed under this member's profile & student verification badge.
              </div>
            </div>
          )}

          {/* Title */}
          <div>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Item Title *</label>
            <input
              type="text"
              placeholder="e.g. Solid Oak Dining Table / Vintage Lamp"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="form-input"
              required
            />
          </div>

          {/* Category & Price */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Category *</label>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="form-input"
                required
              >
                {categories.map((cat) => (
                  <option key={cat.name} value={cat.name}>
                    {cat.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Price (NZD $) *</label>
              <div style={{ position: 'relative' }}>
                <DollarSign size={16} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                <input
                  type="number"
                  placeholder="35"
                  min="0"
                  step="1"
                  value={priceNzd}
                  onChange={(e) => setPriceNzd(e.target.value)}
                  className="form-input"
                  style={{ paddingLeft: '36px' }}
                  required
                />
              </div>
            </div>
          </div>

          {/* Condition & Location */}
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <div>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Condition</label>
              <select
                value={condition}
                onChange={(e) => setCondition(e.target.value)}
                className="form-input"
              >
                <option value="like_new">Like New (Mint)</option>
                <option value="good">Good (Normal wear)</option>
                <option value="fair">Fair (Usable with signs of love)</option>
              </select>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>City</label>
              <select
                value={city}
                onChange={(e) => setCity(e.target.value)}
                className="form-input"
              >
                <option value="Auckland">Auckland</option>
                <option value="Wellington">Wellington</option>
                <option value="Christchurch">Christchurch</option>
                <option value="Hamilton">Hamilton</option>
                <option value="Tauranga">Tauranga</option>
                <option value="Dunedin">Dunedin</option>
              </select>
            </div>
          </div>

          {/* Suburb */}
          <div>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Suburb (Optional)</label>
            <input
              type="text"
              placeholder="e.g. Ponsonby / Te Aro / Riccarton"
              value={suburb}
              onChange={(e) => setSuburb(e.target.value)}
              className="form-input"
            />
          </div>

          {/* Photo Upload: Multi-Image Cloudflare R2 Upload */}
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
              <label style={{ fontSize: '0.85rem', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '6px' }}>
                <Layers size={16} /> Photos ({uploadedImages.length} selected)
              </label>
              <span style={{ fontSize: '0.75rem', color: 'var(--primary-600)', display: 'flex', alignItems: 'center', gap: '4px' }}>
                <Cloud size={14} /> Cloudflare R2 Storage
              </span>
            </div>

            {/* Uploaded Photos Grid */}
            {uploadedImages.length > 0 && (
              <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', marginBottom: '12px' }}>
                {uploadedImages.map((imgUrl, idx) => (
                  <div
                    key={idx}
                    style={{
                      position: 'relative',
                      width: '76px',
                      height: '76px',
                      borderRadius: '8px',
                      overflow: 'hidden',
                      border: idx === 0 ? '2px solid var(--primary-600)' : '1px solid var(--border-subtle)',
                      boxShadow: '0 2px 4px rgba(0,0,0,0.06)',
                    }}
                  >
                    <img
                      src={imgUrl}
                      alt={`Photo ${idx + 1}`}
                      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    />
                    {idx === 0 && (
                      <span
                        style={{
                          position: 'absolute',
                          bottom: 0,
                          left: 0,
                          right: 0,
                          backgroundColor: 'var(--primary-700)',
                          color: '#fff',
                          fontSize: '0.65rem',
                          textAlign: 'center',
                          padding: '1px 0',
                          fontWeight: 700,
                        }}
                      >
                        Cover
                      </span>
                    )}
                    <button
                      type="button"
                      onClick={() => handleRemoveImage(idx)}
                      style={{
                        position: 'absolute',
                        top: '3px',
                        right: '3px',
                        width: '20px',
                        height: '20px',
                        borderRadius: '50%',
                        backgroundColor: 'rgba(15, 23, 42, 0.75)',
                        color: '#fff',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        cursor: 'pointer',
                        border: 'none',
                      }}
                      title="Remove photo"
                    >
                      <X size={12} />
                    </button>
                  </div>
                ))}
              </div>
            )}

            {/* Drag & Drop / Click Upload Box */}
            <div
              onClick={() => fileInputRef.current?.click()}
              style={{
                border: '2px dashed var(--border-subtle)',
                borderRadius: 'var(--radius-md)',
                padding: '20px',
                textAlign: 'center',
                cursor: 'pointer',
                backgroundColor: '#f8fafc',
                transition: 'all 0.2s ease',
                marginBottom: '10px',
              }}
              onMouseEnter={(e) => (e.currentTarget.style.borderColor = 'var(--primary-500)')}
              onMouseLeave={(e) => (e.currentTarget.style.borderColor = 'var(--border-subtle)')}
            >
              <input
                ref={fileInputRef}
                type="file"
                multiple
                accept="image/*"
                onChange={handleMultipleFiles}
                style={{ display: 'none' }}
              />

              {uploading ? (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px' }}>
                  <Loader2 size={24} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
                  <span style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                    {uploadProgress || 'Uploading to Cloudflare R2...'}
                  </span>
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px' }}>
                  <UploadCloud size={28} color="var(--primary-600)" />
                  <div style={{ fontSize: '0.85rem', fontWeight: 600 }}>Click or drag multiple photos to upload</div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                    Supports multi-image upload directly to Cloudflare R2
                  </div>
                </div>
              )}
            </div>

            {/* Direct Image URL input fallback */}
            <div style={{ display: 'flex', gap: '8px' }}>
              <div style={{ position: 'relative', flex: 1 }}>
                <ImageIcon size={16} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: 'var(--text-muted)' }} />
                <input
                  type="url"
                  placeholder="Or paste external image URL..."
                  value={customImageUrl}
                  onChange={(e) => setCustomImageUrl(e.target.value)}
                  className="form-input"
                  style={{ paddingLeft: '36px', fontSize: '0.8rem' }}
                />
              </div>
              <button
                type="button"
                onClick={handleAddCustomUrl}
                className="btn btn-secondary"
                style={{ padding: '0 16px', fontSize: '0.8rem' }}
              >
                Add URL
              </button>
            </div>
          </div>

          {/* Description */}
          <div>
            <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>Description</label>
            <textarea
              rows={3}
              placeholder="Provide key dimensions, history, or pickup details..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="form-input"
              style={{ resize: 'vertical' }}
            />
          </div>

          {/* Sustainable Checkbox */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginTop: '4px' }}>
            <input
              type="checkbox"
              id="sustainable_check"
              checked={isSustainable}
              onChange={(e) => setIsSustainable(e.target.checked)}
              style={{ width: '18px', height: '18px', accentColor: 'var(--primary-600)', cursor: 'pointer' }}
            />
            <label htmlFor="sustainable_check" style={{ fontSize: '0.85rem', fontWeight: 600, cursor: 'pointer' }}>
              Mark as Sustainable Community Pre-loved Item 🌱
            </label>
          </div>

          {/* Submit */}
          <button
            type="submit"
            disabled={loading || uploading}
            className="btn btn-primary"
            style={{ width: '100%', padding: '14px', marginTop: '12px', borderRadius: 'var(--radius-full)' }}
          >
            {loading ? <Loader2 size={20} style={{ animation: 'spin 1s linear infinite' }} /> : 'Publish Item to KiwiShare'}
          </button>

        </form>
      </div>
    </div>
  );
};
