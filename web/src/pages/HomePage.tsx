import React, { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { itemsApi, UsedItem } from '../api/client';
import { JumboCarousel } from '../components/JumboCarousel';
import { CategoryFilter } from '../components/CategoryFilter';
import { ProductCard } from '../components/ProductCard';
import { Sparkles, Loader2, PackageOpen } from 'lucide-react';

export const HomePage: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams();
  const categoryParam = searchParams.get('category') || '';
  const searchParam = searchParams.get('search') || '';
  const sustainableParam = searchParams.get('sustainable') === 'true';

  const [items, setItems] = useState<UsedItem[]>([]);
  const [recommended, setRecommended] = useState<UsedItem[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [sortBy, setSortBy] = useState<string>('newest');
  const [selectedLocation, setSelectedLocation] = useState<string>('');

  useEffect(() => {
    // Fetch recommended items once
    itemsApi
      .getRecommended(10)
      .then((res) => {
        if (res.items) setRecommended(res.items);
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    setLoading(true);
    const params: Record<string, any> = {};
    if (categoryParam) params.category = categoryParam;
    if (searchParam) params.search = searchParam;
    if (sustainableParam) params.sustainable = true;
    if (selectedLocation) params.location = selectedLocation;
    if (sortBy === 'price_asc') params.sort = 'price_asc';
    if (sortBy === 'price_desc') params.sort = 'price_desc';

    itemsApi
      .getItems(params)
      .then((res) => {
        setItems(res.items || []);
      })
      .catch((err) => {
        console.error('Failed to fetch items:', err);
      })
      .finally(() => {
        setLoading(false);
      });
  }, [categoryParam, searchParam, sustainableParam, selectedLocation, sortBy]);

  const handleCategoryChange = (cat: string) => {
    const nextParams = new URLSearchParams(searchParams);
    if (cat) {
      nextParams.set('category', cat);
    } else {
      nextParams.delete('category');
    }
    setSearchParams(nextParams);
  };

  return (
    <div className="container" style={{ padding: '32px 20px 60px' }}>
      
      {/* 1. Jumbo Carousel Showcase */}
      <JumboCarousel items={recommended} />

      {/* 2. Category Filter Pills */}
      <CategoryFilter
        selectedCategory={categoryParam}
        onSelectCategory={handleCategoryChange}
      />

      {/* 3. Filter Bar & Search Result Title */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '16px', marginBottom: '24px' }}>
        <div>
          <h2 style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--text-main)' }}>
            {searchParam
              ? `Results for "${searchParam}"`
              : categoryParam
              ? `${categoryParam} in Aotearoa`
              : sustainableParam
              ? 'Eco-Friendly & Sustainable Picks'
              : 'Discover Community Treasures'}
          </h2>
          <p style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}>
            {items.length} {items.length === 1 ? 'item' : 'items'} available nearby
          </p>
        </div>

        {/* Filter controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <select
            value={selectedLocation}
            onChange={(e) => setSelectedLocation(e.target.value)}
            className="form-input"
            style={{ width: 'auto', padding: '8px 16px', borderRadius: 'var(--radius-full)' }}
          >
            <option value="">All NZ Cities</option>
            <option value="Auckland">Auckland</option>
            <option value="Wellington">Wellington</option>
            <option value="Christchurch">Christchurch</option>
            <option value="Hamilton">Hamilton</option>
            <option value="Tauranga">Tauranga</option>
          </select>

          <select
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value)}
            className="form-input"
            style={{ width: 'auto', padding: '8px 16px', borderRadius: 'var(--radius-full)' }}
          >
            <option value="newest">Recently Listed</option>
            <option value="price_asc">Price: Low to High</option>
            <option value="price_desc">Price: High to Low</option>
          </select>
        </div>
      </div>

      {/* 4. Products Grid or Loading / Empty States */}
      {loading ? (
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '80px 0' }}>
          <Loader2 size={36} color="var(--primary-600)" style={{ animation: 'spin 1s linear infinite' }} />
          <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
          <p style={{ marginTop: '16px', color: 'var(--text-muted)', fontSize: '0.95rem' }}>Loading local pre-loved items...</p>
        </div>
      ) : items.length > 0 ? (
        <div className="product-grid animate-fade-in">
          {items.map((item) => (
            <ProductCard key={item.id || item._id} item={item} />
          ))}
        </div>
      ) : (
        <div className="empty-state animate-fade-in">
          <div className="empty-state-icon">
            <PackageOpen size={32} />
          </div>
          <h3 style={{ fontSize: '1.25rem', marginBottom: '8px' }}>No items found</h3>
          <p style={{ color: 'var(--text-muted)', maxWidth: '420px', margin: '0 auto 20px', fontSize: '0.9rem' }}>
            We couldn't find any items matching your current filters. Try changing your search keywords, category or location.
          </p>
          <button
            onClick={() => {
              setSearchParams({});
              setSelectedLocation('');
              setSortBy('newest');
            }}
            className="btn btn-primary"
          >
            Clear All Filters
          </button>
        </div>
      )}

      {/* 5. Recommended 10-Item Highlights section if on default view */}
      {!searchParam && !categoryParam && recommended.length > 0 && (
        <div style={{ marginTop: '56px', paddingTop: '40px', borderTop: '1px solid var(--border-subtle)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '20px' }}>
            <Sparkles size={22} color="var(--primary-600)" />
            <h2 style={{ fontSize: '1.5rem', fontWeight: 800 }}>Popular & Recommended For You</h2>
          </div>
          <div className="product-grid">
            {recommended.slice(0, 4).map((item) => (
              <ProductCard key={`rec-${item.id || item._id}`} item={item} />
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
