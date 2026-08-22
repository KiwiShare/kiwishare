import React, { useState, useEffect } from 'react';
import { categoriesApi, CategoryItem } from '../api/client';
import { 
  Sparkles, 
  Armchair, 
  Tv, 
  Tent, 
  Shirt, 
  Wrench, 
  Utensils, 
  Flower2, 
  Trophy, 
  BookOpen, 
  Package,
  LucideIcon
} from 'lucide-react';

interface CategoryFilterProps {
  selectedCategory: string;
  onSelectCategory: (cat: string) => void;
}

const ICON_MAP: Record<string, LucideIcon> = {
  Armchair,
  Tv,
  Tent,
  Shirt,
  Wrench,
  Utensils,
  Flower2,
  Trophy,
  BookOpen,
  Package,
  Sparkles,
};

export const CategoryFilter: React.FC<CategoryFilterProps> = ({
  selectedCategory,
  onSelectCategory,
}) => {
  const [categories, setCategories] = useState<CategoryItem[]>([]);

  useEffect(() => {
    categoriesApi
      .getCategories()
      .then((res) => {
        if (res.categories && res.categories.length > 0) {
          setCategories(res.categories);
        }
      })
      .catch((err) => {
        console.error('Failed to load categories:', err);
      });
  }, []);

  return (
    <div style={{ display: 'flex', gap: '10px', overflowX: 'auto', paddingBottom: '12px', marginBottom: '24px', scrollbarWidth: 'none' }}>
      {/* 'All Items' Tab */}
      <button
        type="button"
        onClick={() => onSelectCategory('')}
        style={{
          display: 'inline-flex',
          alignItems: 'center',
          gap: '8px',
          padding: '10px 18px',
          borderRadius: 'var(--radius-full)',
          fontSize: '0.9rem',
          fontWeight: 600,
          whiteSpace: 'nowrap',
          border: selectedCategory === '' ? '1.5px solid var(--primary-600)' : '1px solid var(--border-subtle)',
          backgroundColor: selectedCategory === '' ? 'var(--primary-50)' : '#ffffff',
          color: selectedCategory === '' ? 'var(--primary-700)' : 'var(--text-main)',
          boxShadow: selectedCategory === '' ? '0 0 0 1px var(--primary-500)' : 'var(--shadow-sm)',
          transition: 'all 0.2s ease',
          cursor: 'pointer',
        }}
      >
        <Sparkles size={16} color={selectedCategory === '' ? 'var(--primary-600)' : 'var(--text-muted)'} />
        <span>All Items</span>
      </button>

      {/* Dynamic Categories from MongoDB */}
      {categories.map((cat) => {
        const IconComponent = ICON_MAP[cat.icon] || Package;
        const isSelected = selectedCategory.toLowerCase() === cat.name.toLowerCase();

        return (
          <button
            key={cat.id || cat._id || cat.name}
            type="button"
            onClick={() => onSelectCategory(cat.name)}
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '8px',
              padding: '10px 18px',
              borderRadius: 'var(--radius-full)',
              fontSize: '0.9rem',
              fontWeight: 600,
              whiteSpace: 'nowrap',
              border: isSelected ? '1.5px solid var(--primary-600)' : '1px solid var(--border-subtle)',
              backgroundColor: isSelected ? 'var(--primary-50)' : '#ffffff',
              color: isSelected ? 'var(--primary-700)' : 'var(--text-main)',
              boxShadow: isSelected ? '0 0 0 1px var(--primary-500)' : 'var(--shadow-sm)',
              transition: 'all 0.2s ease',
              cursor: 'pointer',
            }}
          >
            <IconComponent size={16} color={isSelected ? 'var(--primary-600)' : 'var(--text-muted)'} />
            <span>{cat.name}</span>
            {cat.itemCount !== undefined && cat.itemCount > 0 && (
              <span
                style={{
                  fontSize: '0.75rem',
                  backgroundColor: isSelected ? 'var(--primary-200)' : '#f1f5f9',
                  color: isSelected ? 'var(--primary-800)' : 'var(--text-muted)',
                  padding: '2px 6px',
                  borderRadius: 'var(--radius-full)',
                }}
              >
                {cat.itemCount}
              </span>
            )}
          </button>
        );
      })}
    </div>
  );
};
