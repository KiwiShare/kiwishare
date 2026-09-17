import React, { useState, useEffect, useRef, useCallback } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { chatApi, uploadApi, ConversationItem, ChatMessage } from '../api/client';
import {
  Send,
  Image as ImageIcon,
  ArrowLeft,
  ExternalLink,
  MessageSquare,
  Search,
  Check,
  CheckCheck,
  Sparkles,
  ShoppingBag,
  Store,
  RefreshCw,
  Loader2,
  X,
} from 'lucide-react';

export const ChatPage: React.FC = () => {
  const { user, isLoggedIn } = useAuth();
  const { conversationId } = useParams<{ conversationId?: string }>();
  const navigate = useNavigate();

  const [conversations, setConversations] = useState<ConversationItem[]>([]);
  const [loadingConversations, setLoadingConversations] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [messageText, setMessageText] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [uploadingImage, setUploadingImage] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Selected image preview for lightbox
  const [previewImageUrl, setPreviewImageUrl] = useState<string | null>(null);

  const messagesContainerRef = useRef<HTMLDivElement | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const isPollingRef = useRef(false);

  // Lock window and document scroll so page never shifts or jumps downward
  useEffect(() => {
    const prevHtmlOverflow = document.documentElement.style.overflow;
    const prevBodyOverflow = document.body.style.overflow;
    document.documentElement.style.overflow = 'hidden';
    document.body.style.overflow = 'hidden';
    window.scrollTo(0, 0);

    return () => {
      document.documentElement.style.overflow = prevHtmlOverflow;
      document.body.style.overflow = prevBodyOverflow;
    };
  }, []);

  // Ensure window scroll is always 0 when switching conversations
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [conversationId]);

  // Redirect to login if unauthenticated
  useEffect(() => {
    if (!isLoggedIn && !localStorage.getItem('kiwishare_token')) {
      navigate('/login?redirect=/chat');
    }
  }, [isLoggedIn, navigate]);

  // Scroll only internal messages container to bottom (prevents whole window from shifting down)
  const scrollToBottom = (behavior: ScrollBehavior = 'smooth') => {
    if (messagesContainerRef.current) {
      messagesContainerRef.current.scrollTo({
        top: messagesContainerRef.current.scrollHeight,
        behavior,
      });
    }
  };

  // Load conversations list
  const fetchConversations = useCallback(async (isSilent = false) => {
    if (!isSilent) setLoadingConversations(true);
    try {
      const res = await chatApi.getConversations();
      if (res.status === 'success') {
        setConversations(res.conversations || []);
      }
    } catch (err: any) {
      if (!isSilent) {
        setErrorMsg(err.message || 'Failed to load conversations.');
      }
    } finally {
      if (!isSilent) setLoadingConversations(false);
    }
  }, []);

  // Initial load of conversation list
  useEffect(() => {
    fetchConversations();
  }, [fetchConversations]);

  // Load messages for current conversation
  const fetchMessages = useCallback(
    async (convId: string, isSilent = false) => {
      if (isPollingRef.current) return;
      isPollingRef.current = true;
      if (!isSilent) setLoadingMessages(true);
      try {
        const res = await chatApi.getMessages(convId, 50);
        if (res.status === 'success') {
          setMessages((prev) => {
            // Check if messages changed before triggering re-render
            const newCount = res.messages?.length || 0;
            if (prev.length !== newCount || (newCount > 0 && prev[prev.length - 1]?.id !== res.messages[newCount - 1]?.id)) {
              setTimeout(() => scrollToBottom('auto'), 50);
              return res.messages || [];
            }
            return prev;
          });

          // Mark as read
          chatApi.markAsRead(convId).catch(() => {});
        }
      } catch (err: any) {
        if (!isSilent) {
          setErrorMsg(err.message || 'Failed to load messages.');
        }
      } finally {
        if (!isSilent) setLoadingMessages(false);
        isPollingRef.current = false;
      }
    },
    []
  );

  // When conversationId changes, load its messages
  useEffect(() => {
    if (conversationId) {
      fetchMessages(conversationId, false);
      scrollToBottom('auto');
    } else {
      setMessages([]);
    }
  }, [conversationId, fetchMessages]);

  // Polling for active conversation messages (every 3.5s) & conversation list (every 10s)
  useEffect(() => {
    if (!conversationId) return;

    const messageInterval = setInterval(() => {
      fetchMessages(conversationId, true);
    }, 3500);

    const convListInterval = setInterval(() => {
      fetchConversations(true);
    }, 10000);

    return () => {
      clearInterval(messageInterval);
      clearInterval(convListInterval);
    };
  }, [conversationId, fetchMessages, fetchConversations]);

  // Send text message
  const handleSendMessage = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!conversationId || !messageText.trim() || isSending) return;

    const trimmed = messageText.trim();
    setMessageText('');
    setIsSending(true);

    try {
      const res = await chatApi.sendMessage(conversationId, {
        type: 'text',
        text: trimmed,
      });

      if (res.status === 'created' || res.message) {
        setMessages((prev) => [...prev, res.message]);
        setTimeout(() => scrollToBottom('smooth'), 50);
        // Refresh conversation list to update last message preview
        fetchConversations(true);
      }
    } catch (err: any) {
      alert(err.message || 'Failed to send message.');
      setMessageText(trimmed); // Restore typed message
    } finally {
      setIsSending(false);
    }
  };

  // Upload and send image
  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !conversationId) return;

    setUploadingImage(true);
    try {
      const uploadRes = await uploadApi.uploadImage(file);
      if (uploadRes?.url) {
        const sendRes = await chatApi.sendMessage(conversationId, {
          type: 'image',
          imageUrl: uploadRes.url,
        });
        if (sendRes.message) {
          setMessages((prev) => [...prev, sendRes.message]);
          setTimeout(() => scrollToBottom('smooth'), 50);
          fetchConversations(true);
        }
      }
    } catch (err: any) {
      alert(err.message || 'Image upload failed. Please try again.');
    } finally {
      setUploadingImage(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  // Active conversation object
  const activeConversation = conversations.find((c) => c.id === conversationId);

  // Filtered conversation list
  const filteredConversations = conversations.filter((c) => {
    if (!searchTerm.trim()) return true;
    const term = searchTerm.toLowerCase();
    return (
      c.participant.displayName.toLowerCase().includes(term) ||
      c.item.title.toLowerCase().includes(term) ||
      c.lastMessageText.toLowerCase().includes(term)
    );
  });

  const formatTimestamp = (dateStr?: string | null) => {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    return date.toLocaleDateString([], { month: 'short', day: 'numeric' });
  };

  return (
    <div
      className="container"
      style={{
        padding: '10px 16px 14px',
        maxWidth: '1200px',
        height: 'calc(100vh - var(--header-height))',
        display: 'flex',
        flexDirection: 'column',
        boxSizing: 'border-box',
        overflow: 'hidden',
      }}
    >
      {/* Page Title & Breadcrumb */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          marginBottom: '14px',
          flexShrink: 0,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <div
            style={{
              width: '36px',
              height: '36px',
              borderRadius: '10px',
              background: 'linear-gradient(135deg, var(--primary-500), var(--primary-700))',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
            }}
          >
            <MessageSquare size={20} />
          </div>
          <div>
            <h1 style={{ fontSize: '1.4rem', fontWeight: 800, margin: 0 }}>KiwiShare Messages</h1>
            <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)', margin: 0 }}>
              Connect with buyers and sellers across New Zealand
            </p>
          </div>
        </div>

        <button
          onClick={() => {
            fetchConversations(false);
            if (conversationId) fetchMessages(conversationId, false);
          }}
          className="btn btn-secondary"
          style={{ padding: '6px 12px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }}
          title="Refresh messages"
        >
          <RefreshCw size={14} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Main Chat Layout Frame */}
      <div
        className="glass-card"
        style={{
          flex: 1,
          display: 'flex',
          overflow: 'hidden',
          borderRadius: 'var(--radius-lg)',
          border: '1px solid var(--border-subtle)',
          boxShadow: 'var(--shadow-md)',
          backgroundColor: '#fff',
          position: 'relative',
        }}
      >
        {/* Left Column: Conversation Sidebar */}
        <div
          style={{
            width: conversationId ? '340px' : '100%',
            maxWidth: '380px',
            borderRight: '1px solid var(--border-subtle)',
            display: conversationId ? (window.innerWidth < 768 ? 'none' : 'flex') : 'flex',
            flexDirection: 'column',
            backgroundColor: '#fafbfc',
            flexShrink: 0,
          }}
        >
          {/* Search Conversations */}
          <div style={{ padding: '14px', borderBottom: '1px solid var(--border-subtle)' }}>
            <div style={{ position: 'relative' }}>
              <Search
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
                type="text"
                placeholder="Search chats or items..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="form-input"
                style={{
                  paddingLeft: '36px',
                  paddingTop: '8px',
                  paddingBottom: '8px',
                  fontSize: '0.85rem',
                  borderRadius: 'var(--radius-full)',
                  backgroundColor: '#fff',
                }}
              />
            </div>
          </div>

          {/* Conversations Scrollable List */}
          <div style={{ flex: 1, overflowY: 'auto' }}>
            {loadingConversations ? (
              <div style={{ padding: '40px 20px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Loader2 size={24} className="animate-spin" style={{ margin: '0 auto 8px' }} />
                <div style={{ fontSize: '0.9rem' }}>Loading chats...</div>
              </div>
            ) : filteredConversations.length === 0 ? (
              <div style={{ padding: '40px 20px', textAlign: 'center', color: 'var(--text-muted)' }}>
                <Sparkles size={28} style={{ margin: '0 auto 8px', color: 'var(--primary-400)' }} />
                <div style={{ fontWeight: 600, fontSize: '0.95rem', color: 'var(--text-main)', marginBottom: '4px' }}>
                  No messages yet
                </div>
                <div style={{ fontSize: '0.85rem' }}>
                  {searchTerm ? 'No results matching search.' : 'Contact a seller on any listing to start chatting!'}
                </div>
              </div>
            ) : (
              filteredConversations.map((conv) => {
                const isActive = conv.id === conversationId;
                const isBuying = conv.direction === 'buying';

                return (
                  <div
                    key={conv.id}
                    onClick={() => navigate(`/chat/${conv.id}`)}
                    style={{
                      padding: '12px 16px',
                      display: 'flex',
                      gap: '12px',
                      cursor: 'pointer',
                      borderBottom: '1px solid #f1f5f9',
                      backgroundColor: isActive ? 'var(--primary-50)' : 'transparent',
                      borderLeft: isActive ? '4px solid var(--primary-500)' : '4px solid transparent',
                      transition: 'all 0.15s ease',
                    }}
                    onMouseEnter={(e) => {
                      if (!isActive) e.currentTarget.style.backgroundColor = '#f1f5f9';
                    }}
                    onMouseLeave={(e) => {
                      if (!isActive) e.currentTarget.style.backgroundColor = 'transparent';
                    }}
                  >
                    {/* Participant Avatar */}
                    <div style={{ position: 'relative' }}>
                      {conv.participant.avatarUrl ? (
                        <img
                          src={conv.participant.avatarUrl}
                          alt={conv.participant.displayName}
                          style={{
                            width: '44px',
                            height: '44px',
                            borderRadius: '50%',
                            objectFit: 'cover',
                            border: '1.5px solid var(--border-subtle)',
                          }}
                        />
                      ) : (
                        <div
                          style={{
                            width: '44px',
                            height: '44px',
                            borderRadius: '50%',
                            backgroundColor: isBuying ? '#e0e7ff' : 'var(--primary-100)',
                            color: isBuying ? '#3730a3' : 'var(--primary-700)',
                            fontWeight: 700,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: '1rem',
                          }}
                        >
                          {(conv.participant.displayName || 'K').charAt(0).toUpperCase()}
                        </div>
                      )}

                      {/* Direction tag dot */}
                      <div
                        style={{
                          position: 'absolute',
                          bottom: -2,
                          right: -2,
                          width: '18px',
                          height: '18px',
                          borderRadius: '50%',
                          backgroundColor: isBuying ? '#6366f1' : 'var(--primary-600)',
                          color: '#fff',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          fontSize: '0.65rem',
                          boxShadow: '0 1px 3px rgba(0,0,0,0.2)',
                        }}
                        title={isBuying ? 'You are buying' : 'You are selling'}
                      >
                        {isBuying ? <ShoppingBag size={10} /> : <Store size={10} />}
                      </div>
                    </div>

                    {/* Chat Item Snippet */}
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: '2px' }}>
                        <div
                          style={{
                            fontWeight: 700,
                            fontSize: '0.92rem',
                            color: 'var(--text-main)',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {conv.participant.displayName}
                        </div>
                        <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)', flexShrink: 0, marginLeft: '6px' }}>
                          {formatTimestamp(conv.lastMessageAt || conv.updatedAt)}
                        </div>
                      </div>

                      {/* Item Title Badge */}
                      <div
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '0.75rem',
                          color: '#0369a1',
                          backgroundColor: '#e0f2fe',
                          padding: '1px 6px',
                          borderRadius: '4px',
                          marginBottom: '4px',
                          maxWidth: '100%',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        <span style={{ fontWeight: 600 }}>Item:</span>
                        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {conv.item.title}
                        </span>
                      </div>

                      {/* Last message text + unread pill */}
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '8px' }}>
                        <div
                          style={{
                            fontSize: '0.82rem',
                            color: conv.unreadCount > 0 ? 'var(--text-main)' : 'var(--text-muted)',
                            fontWeight: conv.unreadCount > 0 ? 600 : 400,
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            whiteSpace: 'nowrap',
                          }}
                        >
                          {conv.lastMessageText || 'Started conversation'}
                        </div>

                        {conv.unreadCount > 0 && (
                          <div
                            style={{
                              backgroundColor: '#e11d48',
                              color: '#fff',
                              fontSize: '0.7rem',
                              fontWeight: 700,
                              minWidth: '18px',
                              height: '18px',
                              borderRadius: '9px',
                              padding: '0 5px',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              flexShrink: 0,
                            }}
                          >
                            {conv.unreadCount}
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right Column: Active Conversation Pane */}
        {conversationId ? (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', height: '100%', backgroundColor: '#ffffff' }}>
            {/* Chat Top Header */}
            <div
              style={{
                padding: '12px 18px',
                borderBottom: '1px solid var(--border-subtle)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                backgroundColor: '#fff',
                gap: '12px',
                flexShrink: 0,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <button
                  onClick={() => navigate('/chat')}
                  className="btn btn-secondary"
                  style={{
                    padding: '6px',
                    borderRadius: '50%',
                    display: window.innerWidth < 768 ? 'flex' : 'none',
                  }}
                  title="Back to conversations"
                >
                  <ArrowLeft size={18} />
                </button>

                {activeConversation?.participant.avatarUrl ? (
                  <img
                    src={activeConversation.participant.avatarUrl}
                    alt={activeConversation.participant.displayName}
                    style={{ width: '40px', height: '40px', borderRadius: '50%', objectFit: 'cover' }}
                  />
                ) : (
                  <div
                    style={{
                      width: '40px',
                      height: '40px',
                      borderRadius: '50%',
                      backgroundColor: 'var(--primary-100)',
                      color: 'var(--primary-700)',
                      fontWeight: 700,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    {(activeConversation?.participant.displayName || 'K').charAt(0).toUpperCase()}
                  </div>
                )}

                <div>
                  <div style={{ fontWeight: 700, fontSize: '1rem', color: 'var(--text-main)' }}>
                    {activeConversation?.participant.displayName || 'User'}
                  </div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                    {activeConversation?.direction === 'buying'
                      ? 'Seller on KiwiShare'
                      : 'Interested Buyer'}
                  </div>
                </div>
              </div>

              {/* Linked Product Banner */}
              {activeConversation?.item && (
                <Link
                  to={`/products/${activeConversation.item.id}`}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    padding: '6px 12px',
                    backgroundColor: '#f8fafc',
                    border: '1px solid var(--border-subtle)',
                    borderRadius: 'var(--radius-md)',
                    textDecoration: 'none',
                    maxWidth: '280px',
                    transition: 'all 0.15s ease',
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.borderColor = 'var(--primary-400)')}
                  onMouseLeave={(e) => (e.currentTarget.style.borderColor = 'var(--border-subtle)')}
                  title="View item detail"
                >
                  {activeConversation.item.imageUrl ? (
                    <img
                      src={activeConversation.item.imageUrl}
                      alt={activeConversation.item.title}
                      style={{ width: '32px', height: '32px', borderRadius: '6px', objectFit: 'cover' }}
                    />
                  ) : (
                    <div
                      style={{
                        width: '32px',
                        height: '32px',
                        borderRadius: '6px',
                        backgroundColor: '#e2e8f0',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        color: 'var(--text-muted)',
                      }}
                    >
                      <ShoppingBag size={16} />
                    </div>
                  )}

                  <div style={{ overflow: 'hidden', textAlign: 'left' }}>
                    <div
                      style={{
                        fontSize: '0.78rem',
                        fontWeight: 600,
                        color: 'var(--text-main)',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {activeConversation.item.title}
                    </div>
                    <div style={{ fontSize: '0.7rem', color: 'var(--primary-600)', display: 'flex', alignItems: 'center', gap: '3px' }}>
                      <span>View Listing</span>
                      <ExternalLink size={10} />
                    </div>
                  </div>
                </Link>
              )}
            </div>

            {/* Messages Area */}
            <div
              ref={messagesContainerRef}
              style={{
                flex: 1,
                overflowY: 'auto',
                padding: '20px',
                display: 'flex',
                flexDirection: 'column',
                gap: '12px',
                backgroundColor: '#f8fafc',
              }}
            >
              {loadingMessages ? (
                <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
                  <Loader2 size={28} className="animate-spin" style={{ margin: '0 auto 8px' }} />
                  <div>Loading conversation...</div>
                </div>
              ) : messages.length === 0 ? (
                <div
                  style={{
                    margin: 'auto',
                    textAlign: 'center',
                    padding: '24px',
                    maxWidth: '360px',
                    backgroundColor: '#fff',
                    borderRadius: 'var(--radius-lg)',
                    border: '1px solid var(--border-subtle)',
                    boxShadow: 'var(--shadow-sm)',
                  }}
                >
                  <Sparkles size={32} color="var(--primary-500)" style={{ margin: '0 auto 12px' }} />
                  <h3 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: '6px' }}>
                    Start the conversation!
                  </h3>
                  <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)', margin: 0, lineHeight: 1.5 }}>
                    Say hi to {activeConversation?.participant.displayName || 'the seller'}, ask questions about condition, or coordinate pickup location.
                  </p>
                </div>
              ) : (
                messages.map((msg) => {
                  const isMine = msg.isMine || msg.senderId === user?.id;

                  return (
                    <div
                      key={msg.id}
                      style={{
                        display: 'flex',
                        flexDirection: 'column',
                        alignItems: isMine ? 'flex-end' : 'flex-start',
                        maxWidth: '80%',
                        alignSelf: isMine ? 'flex-end' : 'flex-start',
                      }}
                    >
                      {/* Bubble */}
                      <div
                        style={{
                          padding: msg.type === 'image' ? '4px' : '10px 14px',
                          borderRadius: isMine ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                          backgroundColor: isMine ? 'var(--primary-600)' : '#ffffff',
                          color: isMine ? '#ffffff' : 'var(--text-main)',
                          boxShadow: 'var(--shadow-sm)',
                          border: isMine ? 'none' : '1px solid var(--border-subtle)',
                          fontSize: '0.92rem',
                          lineHeight: 1.45,
                          wordBreak: 'break-word',
                        }}
                      >
                        {/* Image message */}
                        {msg.type === 'image' && msg.imageUrl && (
                          <img
                            src={msg.imageUrl}
                            alt="Shared photo"
                            onClick={() => setPreviewImageUrl(msg.imageUrl)}
                            style={{
                              maxWidth: '280px',
                              maxHeight: '260px',
                              borderRadius: '14px',
                              cursor: 'pointer',
                              display: 'block',
                              objectFit: 'cover',
                            }}
                          />
                        )}

                        {/* Text message */}
                        {msg.text && (
                          <div style={{ padding: msg.type === 'image' ? '6px 8px' : 0 }}>
                            {msg.text}
                          </div>
                        )}
                      </div>

                      {/* Time & Read Status */}
                      <div
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '0.7rem',
                          color: 'var(--text-muted)',
                          marginTop: '3px',
                          padding: '0 4px',
                        }}
                      >
                        <span>{formatTimestamp(msg.createdAt)}</span>
                        {isMine && (
                          <span title={msg.readAt ? 'Read' : 'Delivered'}>
                            {msg.readAt ? (
                              <CheckCheck size={13} color="var(--primary-600)" />
                            ) : (
                              <Check size={13} color="var(--text-muted)" />
                            )}
                          </span>
                        )}
                      </div>
                    </div>
                  );
                })
              )}
            </div>

            {/* Message Input Bottom Bar */}
            <form
              onSubmit={handleSendMessage}
              style={{
                padding: '14px 18px',
                borderTop: '1px solid var(--border-subtle)',
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                backgroundColor: '#fff',
                flexShrink: 0,
              }}
            >
              {/* Hidden file input for image attachment */}
              <input
                type="file"
                ref={fileInputRef}
                accept="image/*"
                style={{ display: 'none' }}
                onChange={handleImageUpload}
              />

              {/* Photo Upload Button */}
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={uploadingImage || isSending}
                className="btn btn-secondary"
                style={{
                  width: '40px',
                  height: '40px',
                  padding: 0,
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
                title="Send a photo"
              >
                {uploadingImage ? <Loader2 size={18} className="animate-spin" /> : <ImageIcon size={18} />}
              </button>

              {/* Text Input */}
              <input
                type="text"
                value={messageText}
                onChange={(e) => setMessageText(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    handleSendMessage();
                  }
                }}
                placeholder={`Message ${activeConversation?.participant.displayName || 'seller'}...`}
                className="form-input"
                style={{
                  flex: 1,
                  padding: '10px 16px',
                  borderRadius: 'var(--radius-full)',
                  border: '1px solid var(--border-subtle)',
                  backgroundColor: '#f8fafc',
                  fontSize: '0.92rem',
                }}
                disabled={isSending}
              />

              {/* Send Button */}
              <button
                type="submit"
                disabled={!messageText.trim() || isSending}
                className="btn btn-primary"
                style={{
                  width: '40px',
                  height: '40px',
                  padding: 0,
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                  opacity: !messageText.trim() || isSending ? 0.6 : 1,
                }}
                title="Send message"
              >
                {isSending ? <Loader2 size={18} className="animate-spin" /> : <Send size={18} />}
              </button>
            </form>
          </div>
        ) : (
          /* Empty State: No conversation selected */
          <div
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '40px',
              backgroundColor: '#ffffff',
              textAlign: 'center',
            }}
          >
            <div
              style={{
                width: '64px',
                height: '64px',
                borderRadius: '50%',
                backgroundColor: 'var(--primary-50)',
                color: 'var(--primary-600)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: '16px',
              }}
            >
              <MessageSquare size={32} />
            </div>
            <h2 style={{ fontSize: '1.25rem', fontWeight: 700, marginBottom: '8px' }}>
              Select a conversation
            </h2>
            <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', maxWidth: '380px', marginBottom: '24px', lineHeight: 1.5 }}>
              Choose a message thread from the left or explore listings to contact sellers about items you want.
            </p>
            <Link to="/" className="btn btn-primary" style={{ padding: '10px 20px', borderRadius: 'var(--radius-full)' }}>
              Explore Listings
            </Link>
          </div>
        )}
      </div>

      {/* Lightbox Image Preview Modal */}
      {previewImageUrl && (
        <div
          onClick={() => setPreviewImageUrl(null)}
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.85)',
            zIndex: 1000,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '20px',
            backdropFilter: 'blur(4px)',
          }}
        >
          <div style={{ position: 'relative', maxWidth: '90vw', maxHeight: '90vh' }}>
            <button
              onClick={() => setPreviewImageUrl(null)}
              style={{
                position: 'absolute',
                top: '-40px',
                right: '0',
                color: '#fff',
                backgroundColor: 'rgba(255,255,255,0.2)',
                borderRadius: '50%',
                padding: '6px',
                cursor: 'pointer',
              }}
            >
              <X size={20} />
            </button>
            <img
              src={previewImageUrl}
              alt="Full preview"
              style={{
                maxWidth: '100%',
                maxHeight: '85vh',
                borderRadius: 'var(--radius-md)',
                objectFit: 'contain',
              }}
            />
          </div>
        </div>
      )}

      {errorMsg && (
        <div
          style={{
            position: 'fixed',
            bottom: '24px',
            right: '24px',
            backgroundColor: '#fee2e2',
            color: '#b91c1c',
            border: '1px solid #fca5a5',
            padding: '12px 18px',
            borderRadius: 'var(--radius-md)',
            boxShadow: 'var(--shadow-lg)',
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
            fontSize: '0.9rem',
            zIndex: 999,
          }}
        >
          <span>{errorMsg}</span>
          <button onClick={() => setErrorMsg(null)} style={{ color: '#b91c1c', cursor: 'pointer' }}>
            <X size={16} />
          </button>
        </div>
      )}
    </div>
  );
};
