import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { UsedItem } from '../api/client';
import { ChevronLeft, ChevronRight, Sparkles, ArrowRight, ShieldCheck } from 'lucide-react';

interface JumboCarouselProps {
  items: UsedItem[];
}

export const JumboCarousel: React.FC<JumboCarouselProps> = ({ items }) => {
  const [currentIndex, setCurrentIndex] = useState(0);

  // Fallback banners if items array is empty
  const defaultBanners = [
    {
      title: 'Aotearoa Sustainable Living',
      subtitle: 'Give pre-loved items a second home. Save money and cut carbon in your local community.',
      imageUrl: 'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=1200&auto=format&fit=crop&q=80',
      tag: 'Community Favorite',
      link: '/?sustainable=true',
    },
    {
      title: 'Quality Retro & Modern Furniture',
      subtitle: 'Discover solid timber tables, armchairs, and desk setups from verified neighbors.',
      imageUrl: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=1200&auto=format&fit=crop&q=80',
      tag: 'Trending in Auckland',
      link: '/?category=Furniture',
    },
  ];

  const displayList = items.length > 0
    ? items.slice(0, 4).map((it) => ({
        title: it.title,
        subtitle: it.description || 'Verified authentic quality item available in New Zealand.',
        imageUrl: it.imageUrl || (it.images && it.images[0]?.url) || 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=1200&auto=format&fit=crop&q=80',
        tag: `NZ$${it.priceNzd || (it.price ? (it.price / 100).toFixed(0) : '25')}`,
        link: `/products/${it.id || it._id}`,
      }))
    : defaultBanners;

  useEffect(() => {
    if (displayList.length <= 1) return;
    const timer = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % displayList.length);
    }, 6000);
    return () => clearInterval(timer);
  }, [displayList.length]);

  const current = displayList[currentIndex];

  const prevSlide = () => {
    setCurrentIndex((prev) => (prev - 1 + displayList.length) % displayList.length);
  };

  const nextSlide = () => {
    setCurrentIndex((prev) => (prev + 1) % displayList.length);
  };

  return (
    <div
      style={{
        position: 'relative',
        borderRadius: 'var(--radius-xl)',
        overflow: 'hidden',
        height: '360px',
        boxShadow: 'var(--shadow-xl)',
        marginBottom: '32px',
        backgroundColor: '#1e293b',
      }}
    >
      {/* Background Image with Gradient Overlay */}
      <img
        src={current.imageUrl}
        alt={current.title}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          transition: 'all 0.5s ease-in-out',
        }}
      />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: 'linear-gradient(to right, rgba(6, 78, 59, 0.92) 0%, rgba(15, 23, 42, 0.75) 60%, rgba(0,0,0,0.3) 100%)',
        }}
      />

      {/* Slide Content */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          padding: '48px',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          maxWidth: '680px',
          color: '#ffffff',
          zIndex: 2,
        }}
      >
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px', backgroundColor: 'rgba(255, 255, 255, 0.2)', backdropFilter: 'blur(8px)', padding: '6px 14px', borderRadius: 'var(--radius-full)', fontSize: '0.8rem', fontWeight: 700, width: 'fit-content', marginBottom: '16px' }}>
          <Sparkles size={14} color="#a7f3d0" />
          <span>{current.tag}</span>
        </div>

        <h2 style={{ fontSize: '2.4rem', fontWeight: 800, color: '#ffffff', marginBottom: '14px', lineHeight: 1.15, textShadow: '0 2px 4px rgba(0,0,0,0.3)' }}>
          {current.title}
        </h2>

        <p style={{ fontSize: '1.05rem', color: '#e2e8f0', marginBottom: '24px', lineHeight: 1.5, maxHeight: '54px', overflow: 'hidden', textOverflow: 'ellipsis', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
          {current.subtitle}
        </p>

        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <Link to={current.link} className="btn btn-primary" style={{ padding: '12px 24px', fontSize: '1rem' }}>
            <span>Explore Item</span>
            <ArrowRight size={18} />
          </Link>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#a7f3d0', fontSize: '0.85rem', fontWeight: 600 }}>
            <ShieldCheck size={16} />
            <span>NZ Verified Community</span>
          </div>
        </div>
      </div>

      {/* Navigation Arrows */}
      {displayList.length > 1 && (
        <>
          <button
            onClick={prevSlide}
            aria-label="Previous Slide"
            className="btn-icon"
            style={{
              position: 'absolute',
              left: '16px',
              top: '50%',
              transform: 'translateY(-50%)',
              backgroundColor: 'rgba(255, 255, 255, 0.25)',
              backdropFilter: 'blur(8px)',
              color: '#ffffff',
              zIndex: 3,
            }}
          >
            <ChevronLeft size={22} />
          </button>
          <button
            onClick={nextSlide}
            aria-label="Next Slide"
            className="btn-icon"
            style={{
              position: 'absolute',
              right: '16px',
              top: '50%',
              transform: 'translateY(-50%)',
              backgroundColor: 'rgba(255, 255, 255, 0.25)',
              backdropFilter: 'blur(8px)',
              color: '#ffffff',
              zIndex: 3,
            }}
          >
            <ChevronRight size={22} />
          </button>

          {/* Dots Indicator */}
          <div
            style={{
              position: 'absolute',
              bottom: '20px',
              right: '32px',
              display: 'flex',
              gap: '8px',
              zIndex: 3,
            }}
          >
            {displayList.map((_, idx) => (
              <button
                key={idx}
                onClick={() => setCurrentIndex(idx)}
                style={{
                  width: idx === currentIndex ? '28px' : '8px',
                  height: '8px',
                  borderRadius: 'var(--radius-full)',
                  backgroundColor: idx === currentIndex ? 'var(--primary-400)' : 'rgba(255, 255, 255, 0.4)',
                  transition: 'all 0.3s ease',
                }}
              />
            ))}
          </div>
        </>
      )}
    </div>
  );
};
