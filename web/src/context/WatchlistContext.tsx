import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { UsedItem, watchlistApi } from '../api/client';
import { useAuth } from './AuthContext';

interface WatchlistContextType {
  watchlistIds: Set<string>;
  watchlistItems: UsedItem[];
  isLoading: boolean;
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

  const refreshWatchlist = React.useCallback(async () => {
    if (!isLoggedIn) {
      setWatchlistIds(new Set());
      setWatchlistItems([]);
      return;
    }

    try {
      setIsLoading(true);
      const [idsRes, itemsRes] = await Promise.all([
        watchlistApi.getWatchlistIds().catch(() => ({ itemIds: [] })),
        watchlistApi.getWatchlist().catch(() => ({ items: [] })),
      ]);

      if (idsRes.itemIds) {
        setWatchlistIds(new Set(idsRes.itemIds.map(String)));
      }
      if (itemsRes.items) {
        setWatchlistItems(itemsRes.items);
      }
    } catch (err) {
      console.error('Failed to load watchlist:', err);
    } finally {
      setIsLoading(false);
    }
  }, [isLoggedIn]);

  useEffect(() => {
    refreshWatchlist();
  }, [refreshWatchlist]);

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
