import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import { chatApi, ConversationItem } from '../api/client';
import { useAuth } from './AuthContext';

interface ChatContextType {
  unreadCount: number;
  conversations: ConversationItem[];
  refreshUnreadCount: () => Promise<void>;
  markConversationRead: (conversationId: string, throughMessageId?: string) => Promise<void>;
  setLocalConversationRead: (conversationId: string) => void;
}

const ChatContext = createContext<ChatContextType | undefined>(undefined);

export const ChatProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const { isLoggedIn } = useAuth();
  const [unreadCount, setUnreadCount] = useState<number>(0);
  const [conversations, setConversations] = useState<ConversationItem[]>([]);

  const refreshUnreadCount = useCallback(async () => {
    if (!isLoggedIn) {
      setUnreadCount(0);
      setConversations([]);
      return;
    }

    try {
      const res = await chatApi.getConversations();
      if (res.status === 'success' && Array.isArray(res.conversations)) {
        setConversations(res.conversations);
        const total = res.conversations.reduce((sum, c) => sum + (c.unreadCount || 0), 0);
        setUnreadCount(total);
      }
    } catch {
      // Ignore transient network errors
    }
  }, [isLoggedIn]);

  const setLocalConversationRead = useCallback((conversationId: string) => {
    setConversations((prev) => {
      let changed = false;
      const updated = prev.map((c) => {
        if (c.id === conversationId && (c.unreadCount || 0) > 0) {
          changed = true;
          return { ...c, unreadCount: 0 };
        }
        return c;
      });
      if (changed) {
        const total = updated.reduce((sum, c) => sum + (c.unreadCount || 0), 0);
        setUnreadCount(total);
      }
      return updated;
    });
  }, []);

  const markConversationRead = useCallback(
    async (conversationId: string, throughMessageId?: string) => {
      // Optimistically clear local unread count immediately so badges update without delay
      setLocalConversationRead(conversationId);
      try {
        await chatApi.markAsRead(conversationId, throughMessageId);
      } catch {
        // Fallback or ignore
      }
    },
    [setLocalConversationRead]
  );

  // Initial load on auth state change
  useEffect(() => {
    refreshUnreadCount();
  }, [refreshUnreadCount]);

  // Periodic poll every 10 seconds for unread updates when logged in
  useEffect(() => {
    if (!isLoggedIn) return;
    const interval = setInterval(refreshUnreadCount, 10000);
    return () => clearInterval(interval);
  }, [isLoggedIn, refreshUnreadCount]);

  return (
    <ChatContext.Provider
      value={{
        unreadCount,
        conversations,
        refreshUnreadCount,
        markConversationRead,
        setLocalConversationRead,
      }}
    >
      {children}
    </ChatContext.Provider>
  );
};

export const useChat = (): ChatContextType => {
  const context = useContext(ChatContext);
  if (!context) {
    throw new Error('useChat must be used within a ChatProvider');
  }
  return context;
};
