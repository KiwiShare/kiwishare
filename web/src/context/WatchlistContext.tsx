import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { UsedItem, watchlistApi } from '../api/client';
import { useAuth } from './AuthContext';

interface WatchlistContextType {
  watchlistIds: Set<string>;
  watchlistItems: UsedItem[];
  isLoading: boolean;
  error: string | null;
  isWatched: (itemId: string) => boolean;
  toggleWatch: (item: UsedItem) => Promise<boolean>;
  refreshWatchlist: () => Promise<void>;
}

const WatchlistContext = createContext<WatchlistContextType | undefined>(undefined);

export const WatchlistProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const { isLoggedIn } = useAuth();
  const [watchlistIds, setWatchlistIds] = useState<Set<string>>(new Set());
  const [watchlistItems, setWatchlistItems] = useState<UsedItem[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const refreshWatchlist = React.useCallback(async () => {
    if (!isLoggedIn) {
      setWatchlistIds(new Set());
      setWatchlistItems([]);
      setError(null);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);
      const idsRes = await watchlistApi.getWatchlistIds();
      const rawItems: UsedItem[] = [];
      let cursor: string | undefined;
      do {
        const page = await watchlistApi.getWatchlist(cursor);
        rawItems.push(...(page.items || page.data || []));
        cursor = page.pagination?.hasMore
          ? page.pagination.nextCursor || undefined
          : undefined;
      } while (cursor);

      if (idsRes.itemIds && Array.isArray(idsRes.itemIds)) {
        const idSet = new Set<string>(idsRes.itemIds.map(String));
        // Also add IDs from loaded items
        rawItems.forEach((it) => {
          const id = it.id || it._id;
          if (id) idSet.add(String(id));
        });
        setWatchlistIds(idSet);
      } else if (rawItems.length > 0) {
        const idSet = new Set<string>();
        rawItems.forEach((it) => {
          const id = it.id || it._id;
          if (id) idSet.add(String(id));
        });
        setWatchlistIds(idSet);
      }

      setWatchlistItems(rawItems);
    } catch (err) {
      console.error('Failed to load watchlist:', err);
      setError('Could not load your Watchlist. Please try again.');
    } finally {
      setIsLoading(false);
    }
  }, [isLoggedIn]);

  useEffect(() => {
    void refreshWatchlist();
    if (!isLoggedIn) return;

    const interval = window.setInterval(() => {
      if (document.visibilityState === 'visible') {
        void refreshWatchlist();
      }
    }, 10000);

    const refreshOnFocus = () => void refreshWatchlist();
    window.addEventListener('focus', refreshOnFocus);

    return () => {
      window.clearInterval(interval);
      window.removeEventListener('focus', refreshOnFocus);
    };
  }, [isLoggedIn, refreshWatchlist]);

  const isWatched = (itemId: string): boolean => {
    return watchlistIds.has(itemId);
  };

  const toggleWatch = async (item: UsedItem): Promise<boolean> => {
    const itemId = item.id || item._id;
    if (!itemId) return false;

    if (!isLoggedIn) {
      // Return false if unauthenticated
      return false;
    }

    const currentlyWatched = watchlistIds.has(itemId);
    const newIds = new Set(watchlistIds);

    if (currentlyWatched) {
      newIds.delete(itemId);
      setWatchlistIds(newIds);
      setWatchlistItems((prev) => prev.filter((i) => (i.id || i._id) !== itemId));
      try {
        await watchlistApi.removeFromWatchlist(itemId);
      } catch (e) {
        // Rollback on error
        newIds.add(itemId);
        setWatchlistIds(new Set(newIds));
        refreshWatchlist();
        throw e;
      }
      return false;
    } else {
      newIds.add(itemId);
      setWatchlistIds(newIds);
      setWatchlistItems((prev) => [item, ...prev]);
      try {
        await watchlistApi.addToWatchlist(itemId);
      } catch (e) {
        // Rollback on error
        newIds.delete(itemId);
        setWatchlistIds(new Set(newIds));
        refreshWatchlist();
        throw e;
      }
      return true;
    }
  };

  return (
    <WatchlistContext.Provider
      value={{
        watchlistIds,
        watchlistItems,
        isLoading,
        error,
        isWatched,
        toggleWatch,
        refreshWatchlist,
      }}
    >
      {children}
    </WatchlistContext.Provider>
  );
};

export const useWatchlist = () => {
  const context = useContext(WatchlistContext);
  if (!context) {
    throw new Error('useWatchlist must be used within a WatchlistProvider');
  }
  return context;
};
