import React, { useState, useEffect, useRef, useCallback, useMemo } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useChat } from '../context/ChatContext';
import {
  chatApi,
  uploadApi,
  getApiBaseUrl,
  ConversationItem,
  ChatMessage,
  OrderItem,
  ordersApi,
  paymentsApi,
  meetupsApi,
} from '../api/client';
import { CAMPUS_LOCATIONS } from '../utils/campusLocations';
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
  Play,
  Pause,
  Mic,
  CreditCard,
  Calendar,
  MapPin,
  QrCode,
  ShieldCheck,
  RotateCcw,
  Receipt,
  CheckCircle2,
  AlertCircle,
} from 'lucide-react';

const VoiceAudioPlayer: React.FC<{
  audioUrl: string;
  durationMs?: number | null;
  isMine: boolean;
}> = ({ audioUrl, durationMs, isMine }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState<number>(durationMs && durationMs > 0 ? durationMs / 1000 : 0);
  const [isLoading, setIsLoading] = useState(false);
  const [hasError, setHasError] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  const resolvedUrl = useMemo(() => {
    if (!audioUrl) return '';
    if (audioUrl.startsWith('http://') || audioUrl.startsWith('https://')) return audioUrl;
    const cleanPath = audioUrl.startsWith('/') ? audioUrl : `/${audioUrl}`;
    const base = getApiBaseUrl().replace(/\/api$/, '');
    return `${base}${cleanPath}`;
  }, [audioUrl]);

  useEffect(() => {
    if (!resolvedUrl) return;
    const audio = new Audio(resolvedUrl);
    audioRef.current = audio;

    const handleLoadedMetadata = () => {
      if (audio.duration && !isNaN(audio.duration) && isFinite(audio.duration)) {
        setDuration(audio.duration);
      }
    };

    const handleTimeUpdate = () => {
      setCurrentTime(audio.currentTime);
    };

    const handleEnded = () => {
      setIsPlaying(false);
      setCurrentTime(0);
    };

    const handleWaiting = () => setIsLoading(true);
    const handleCanPlay = () => setIsLoading(false);
    const handleError = () => {
      setIsLoading(false);
      setIsPlaying(false);
      setHasError(true);
    };

    audio.addEventListener('loadedmetadata', handleLoadedMetadata);
    audio.addEventListener('timeupdate', handleTimeUpdate);
    audio.addEventListener('ended', handleEnded);
    audio.addEventListener('waiting', handleWaiting);
    audio.addEventListener('canplay', handleCanPlay);
    audio.addEventListener('error', handleError);

    return () => {
      audio.pause();
      audio.removeEventListener('loadedmetadata', handleLoadedMetadata);
      audio.removeEventListener('timeupdate', handleTimeUpdate);
      audio.removeEventListener('ended', handleEnded);
      audio.removeEventListener('waiting', handleWaiting);
      audio.removeEventListener('canplay', handleCanPlay);
      audio.removeEventListener('error', handleError);
      audioRef.current = null;
    };
  }, [resolvedUrl]);

  const togglePlay = () => {
    if (!audioRef.current || hasError) return;
    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      audioRef.current
        .play()
        .then(() => setIsPlaying(true))
        .catch(() => {
          setIsPlaying(false);
          setHasError(true);
        });
    }
  };

  const handleSeek = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!audioRef.current || !duration || duration <= 0) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const clickX = e.clientX - rect.left;
    const ratio = Math.max(0, Math.min(1, clickX / rect.width));
    const targetTime = ratio * duration;
    audioRef.current.currentTime = targetTime;
    setCurrentTime(targetTime);
  };

  const formatTime = (secs: number) => {
    if (!secs || isNaN(secs) || secs < 0) return '0:00';
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const progressPercent = duration > 0 ? Math.min(100, (currentTime / duration) * 100) : 0;
  const barHeights = [40, 70, 50, 90, 60, 100, 75, 45, 80, 55, 65, 85, 40, 70];

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '10px',
        padding: '6px 4px',
        minWidth: '220px',
        maxWidth: '300px',
      }}
    >
      <button
        type="button"
        onClick={togglePlay}
        style={{
          width: '38px',
          height: '38px',
          borderRadius: '50%',
          border: 'none',
          backgroundColor: isMine ? '#ffffff' : 'var(--primary-600)',
          color: isMine ? 'var(--primary-600)' : '#ffffff',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          cursor: hasError ? 'not-allowed' : 'pointer',
          flexShrink: 0,
          boxShadow: '0 2px 6px rgba(0,0,0,0.12)',
          transition: 'transform 0.15s ease',
        }}
        onMouseDown={(e) => (e.currentTarget.style.transform = 'scale(0.95)')}
        onMouseUp={(e) => (e.currentTarget.style.transform = 'scale(1)')}
        title={hasError ? 'Failed to play voice message' : isPlaying ? 'Pause' : 'Play voice message'}
      >
        {isLoading ? (
          <Loader2 size={18} className="animate-spin" />
        ) : isPlaying ? (
          <Pause size={18} fill="currentColor" />
        ) : (
          <Play size={18} fill="currentColor" style={{ marginLeft: '2px' }} />
        )}
      </button>

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
        <div
          onClick={handleSeek}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '3px',
            height: '24px',
            cursor: 'pointer',
            padding: '2px 0',
          }}
          title="Click to scrub"
        >
          {barHeights.map((h, i) => {
            const barProgress = ((i + 1) / barHeights.length) * 100;
            const isFilled = progressPercent >= barProgress;
            return (
              <div
                key={i}
                style={{
                  flex: 1,
                  height: `${h}%`,
                  borderRadius: '2px',
                  backgroundColor: isMine
                    ? isFilled
                      ? '#ffffff'
                      : 'rgba(255, 255, 255, 0.4)'
                    : isFilled
                      ? 'var(--primary-600)'
                      : 'var(--border-subtle)',
                  transition: 'background-color 0.1s ease',
                }}
              />
            );
          })}
        </div>

        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            fontSize: '0.72rem',
            color: isMine ? 'rgba(255, 255, 255, 0.85)' : 'var(--text-muted)',
            fontWeight: 500,
          }}
        >
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: '3px' }}>
            <Mic size={11} />
            <span>Voice</span>
          </span>
          <span>
            {hasError
              ? 'Audio error'
              : isPlaying
                ? `${formatTime(currentTime)} / ${formatTime(duration)}`
                : duration > 0
                  ? formatTime(duration)
                  : '0:00'}
          </span>
        </div>
      </div>
    </div>
  );
};

export const ChatPage: React.FC = () => {
  const { user, isLoggedIn } = useAuth();
  const { markConversationRead, setLocalConversationRead } = useChat();
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

  // Order & Meetup transaction state for current conversation
  const [currentOrder, setCurrentOrder] = useState<OrderItem | null>(null);
  const [meetupDetails, setMeetupDetails] = useState<any | null>(null);
  const [, setLoadingOrder] = useState(false);

  // Modals state
  const [showCheckoutModal, setShowCheckoutModal] = useState(false);
  const [showScheduleModal, setShowScheduleModal] = useState(false);
  const [showQrModal, setShowQrModal] = useState(false);
  const [showInvoiceModal, setShowInvoiceModal] = useState(false);

  // Modal actions loading state
  const [isProcessingPayment, setIsProcessingPayment] = useState(false);
  const [isSubmittingMeetup, setIsSubmittingMeetup] = useState(false);
  const [isConfirmingHandover, setIsConfirmingHandover] = useState(false);
  const [isRefunding, setIsRefunding] = useState(false);

  // Safe Pay card details. The backend tokenises these into a Stripe PaymentMethod
  // before the order can be confirmed as paid.
  const [cardNumber, setCardNumber] = useState('');
  const [cardExpiry, setCardExpiry] = useState('');
  const [cardCvc, setCardCvc] = useState('');

  // Meetup schedule form state
  const [meetupDate, setMeetupDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    d.setHours(14, 0, 0, 0);
    return d.toISOString().slice(0, 16);
  });
  const [meetupLocation, setMeetupLocation] = useState('UoA City Campus - Quad / General Library');
  const [meetupNote, setMeetupNote] = useState('');

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
        const raw = res.conversations || [];
        // Keep currently active conversation unreadCount at 0
        setConversations(
          raw.map((c) => (c.id === conversationId ? { ...c, unreadCount: 0 } : c))
        );
      }
    } catch (err: any) {
      if (!isSilent) {
        setErrorMsg(err.message || 'Failed to load conversations.');
      }
    } finally {
      if (!isSilent) setLoadingConversations(false);
    }
  }, [conversationId]);

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

          // Immediately clear unread badges for this conversation locally & globally
          setConversations((prev) =>
            prev.map((c) => (c.id === convId ? { ...c, unreadCount: 0 } : c))
          );
          setLocalConversationRead(convId);
          const lastMsg = res.messages && res.messages.length > 0 ? res.messages[res.messages.length - 1] : undefined;
          markConversationRead(convId, lastMsg?.id).catch(() => {});
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
    [markConversationRead, setLocalConversationRead]
  );

  // When conversationId changes, mark as read immediately and load its messages
  useEffect(() => {
    if (conversationId) {
      setConversations((prev) =>
        prev.map((c) => (c.id === conversationId ? { ...c, unreadCount: 0 } : c))
      );
      setLocalConversationRead(conversationId);
      markConversationRead(conversationId).catch(() => {});
      fetchMessages(conversationId, false);
      scrollToBottom('auto');
    } else {
      setMessages([]);
    }
  }, [conversationId, fetchMessages, markConversationRead, setLocalConversationRead]);

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

  // Load Order & Meetup for active item
  const loadOrderAndMeetup = useCallback(async (itemId?: string) => {
    if (!itemId) {
      setCurrentOrder(null);
      setMeetupDetails(null);
      return;
    }
    setLoadingOrder(true);
    try {
      const res = await ordersApi.getOrderByItemId(itemId);
      if (res?.order) {
        setCurrentOrder(res.order);
        try {
          const meetupRes = await meetupsApi.getMeetup(res.order.id);
          setMeetupDetails(meetupRes?.meetup || null);
        } catch {
          setMeetupDetails(null);
        }
      } else {
        setCurrentOrder(null);
        setMeetupDetails(null);
      }
    } catch {
      setCurrentOrder(null);
      setMeetupDetails(null);
    } finally {
      setLoadingOrder(false);
    }
  }, []);

  useEffect(() => {
    if (activeConversation?.item?.id) {
      loadOrderAndMeetup(activeConversation.item.id);
    } else {
      setCurrentOrder(null);
      setMeetupDetails(null);
    }
  }, [activeConversation?.item?.id, loadOrderAndMeetup]);

  // Buyer Checkout with Safe Pay
  const handleSafePayCheckout = async () => {
    if (!activeConversation?.item || isProcessingPayment) return;

    const cleanCardNumber = cardNumber.replace(/\s+/g, '');
    const expiryMatch = cardExpiry.trim().match(/^(0?[1-9]|1[0-2])\s*\/\s*(\d{2}|\d{4})$/);
    if (!/^\d{12,19}$/.test(cleanCardNumber)) {
      alert('Please enter a valid card number.');
      return;
    }
    if (!expiryMatch) {
      alert('Please enter card expiry as MM/YY.');
      return;
    }
    if (!/^\d{3,4}$/.test(cardCvc.trim())) {
      alert('Please enter a valid CVC.');
      return;
    }

    setIsProcessingPayment(true);
    try {
      let orderToPay = currentOrder;
      if (!orderToPay || orderToPay.status === 'pending' || orderToPay.status === 'refunded') {
        const orderRes = await ordersApi.createOrder(activeConversation.item.id);
        orderToPay = orderRes.order;
        setCurrentOrder(orderToPay);
      }

      // Always create a fresh intent so the amount reflects the latest listing/special price.
      const intentRes = await paymentsApi.createIntent(orderToPay.id);

      if (!intentRes.isFree) {
        const expMonth = Number(expiryMatch[1]);
        const rawYear = Number(expiryMatch[2]);
        const expYear = rawYear < 100 ? 2000 + rawYear : rawYear;
        const paymentMethod = await paymentsApi.createPaymentMethod({
          cardNumber: cleanCardNumber,
          expMonth,
          expYear,
          cvc: cardCvc.trim(),
        });

        await paymentsApi.confirm(
          orderToPay.id,
          intentRes.paymentIntentId,
          paymentMethod.paymentMethodId,
        );
      }

      // Reload the authoritative order/item state after the server confirms payment.
      await loadOrderAndMeetup(activeConversation.item.id);
      await fetchConversations(true);

      await chatApi.sendMessage(activeConversation.id, {
        type: 'text',
        text: `[Payment Confirmed] Safe Pay payment of $${intentRes.amountNzd} NZD completed. Item is now SOLD and reserved. Funds held securely in KiwiShare Escrow until meetup handover.`,
      });

      setCardNumber('');
      setCardExpiry('');
      setCardCvc('');
      setShowCheckoutModal(false);
      fetchMessages(activeConversation.id, false);
    } catch (err: any) {
      alert(err.message || 'Payment processing failed. No order status was changed.');
    } finally {
      setIsProcessingPayment(false);
    }
  };

  // Propose Meetup
  const handleProposeMeetup = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (!currentOrder || isSubmittingMeetup) return;
    if (!meetupLocation.trim()) {
      alert('Please enter or select a meetup location.');
      return;
    }

    setIsSubmittingMeetup(true);
    try {
      const res = await meetupsApi.propose(currentOrder.id, {
        scheduledAt: new Date(meetupDate).toISOString(),
        locationName: meetupLocation.trim(),
        note: meetupNote.trim() || undefined,
      });
      if (res?.meetup) {
        setMeetupDetails(res.meetup);
      }

      // Send proposal in chat
      const formattedDate = new Date(meetupDate).toLocaleString('en-NZ', {
        dateStyle: 'medium',
        timeStyle: 'short',
      });
      await chatApi.sendMessage(activeConversation!.id, {
        type: 'text',
        text: `[Meetup Proposal] Location: ${meetupLocation.trim()} | Time: ${formattedDate}${meetupNote.trim() ? ` | Note: ${meetupNote.trim()}` : ''}`,
      });

      setShowScheduleModal(false);
      fetchMessages(activeConversation!.id, false);
      loadOrderAndMeetup(activeConversation!.item.id);
    } catch (err: any) {
      alert(err.message || 'Failed to propose meetup.');
    } finally {
      setIsSubmittingMeetup(false);
    }
  };

  // Accept Meetup Proposal
  const handleAcceptMeetup = async () => {
    if (!currentOrder) return;
    try {
      const res = await meetupsApi.accept(currentOrder.id);
      if (res?.meetup) {
        setMeetupDetails(res.meetup);
      }

      await chatApi.sendMessage(activeConversation!.id, {
        type: 'text',
        text: `[Meetup Confirmed] Meetup proposal accepted. Please meet at the designated campus location on time!`,
      });

      fetchMessages(activeConversation!.id, false);
      loadOrderAndMeetup(activeConversation!.item.id);
    } catch (err: any) {
      alert(err.message || 'Failed to accept meetup.');
    }
  };

  // Confirm Handover (Buyer confirms receipt OR Seller confirms handover)
  const handleConfirmHandover = async (role: 'buyer' | 'seller') => {
    if (!currentOrder || isConfirmingHandover) return;
    setIsConfirmingHandover(true);
    try {
      const res = await meetupsApi.confirmHandover(currentOrder.id, role);
      await chatApi.sendMessage(activeConversation!.id, {
        type: 'text',
        text: `[Handover Confirmed] ${role === 'buyer' ? 'Buyer confirmed safe receipt of the item. KiwiShare Escrow funds released to seller.' : 'Seller confirmed handing over the item to buyer.'}`,
      });

      setShowQrModal(false);
      fetchMessages(activeConversation!.id, false);
      loadOrderAndMeetup(activeConversation!.item.id);
      if (res?.order) {
        setCurrentOrder(res.order);
      }
    } catch (err: any) {
      alert(err.message || 'Failed to confirm handover.');
    } finally {
      setIsConfirmingHandover(false);
    }
  };

  // Refund Order (Seller direct refund or Buyer 48h claim)
  const handleRefundOrder = async () => {
    if (!currentOrder || isRefunding) return;
    if (!window.confirm('Are you sure you want to refund this order? Funds will be returned to the buyer and the listing will be relisted.')) {
      return;
    }

    setIsRefunding(true);
    try {
      const res = await ordersApi.refundOrder(currentOrder.id, 'Refund issued via chat');
      if (res?.order) {
        setCurrentOrder(res.order);
      }
      if (activeConversation?.item) {
        activeConversation.item.status = 'active';
      }

      await chatApi.sendMessage(activeConversation!.id, {
        type: 'text',
        text: `[Order Refunded] The order has been refunded. Funds will return to buyer account and the listing is active again.`,
      });

      fetchMessages(activeConversation!.id, false);
      loadOrderAndMeetup(activeConversation!.item.id);
      alert('Order successfully refunded.');
    } catch (err: any) {
      alert(err.message || 'Failed to refund order.');
    } finally {
      setIsRefunding(false);
    }
  };

  // Seller request payment from buyer
  const handleSendPaymentRequest = async () => {
    if (!activeConversation?.item) return;
    try {
      await chatApi.sendMessage(activeConversation.id, {
        type: 'text',
        text: `[Payment Request] Seller requested KiwiShare Safe Pay payment for "${activeConversation.item.title}" ($${activeConversation.item.priceNzd} NZD). Click below to complete secure escrow checkout.`,
      });
      fetchMessages(activeConversation.id, false);
    } catch (err: any) {
      alert(err.message || 'Failed to send payment request.');
    }
  };

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
                          {conv.lastMessageText === 'Voice message' ? (
                            <span style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                              <Mic size={13} color="var(--primary-600)" />
                              <span>Voice message</span>
                            </span>
                          ) : (
                            conv.lastMessageText || 'Started conversation'
                          )}
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

              {/* Linked Product Banner with Top-Right Corner Status Badge */}
              {activeConversation?.item && (() => {
                const isPaid = currentOrder?.status === 'paid' || currentOrder?.status === 'meeting_scheduled';
                const isRefunded = currentOrder?.status === 'refunded' || currentOrder?.isRefunded;
                const isCompleted = currentOrder?.status === 'completed';
                const isSold = activeConversation.item.status === 'sold' || isPaid || isCompleted;
                const isDelisted = activeConversation.item.status === 'delisted';

                let badgeText = 'AVAILABLE';
                let badgeBg = '#ecfdf5';
                let badgeColor = '#059669';
                let badgeBorder = '#a7f3d0';

                if (isRefunded) {
                  badgeText = 'REFUNDED';
                  badgeBg = '#fee2e2';
                  badgeColor = '#dc2626';
                  badgeBorder = '#fca5a5';
                } else if (isCompleted) {
                  badgeText = 'COMPLETED';
                  badgeBg = '#e0e7ff';
                  badgeColor = '#4338ca';
                  badgeBorder = '#c7d2fe';
                } else if (isPaid) {
                  badgeText = 'PAID';
                  badgeBg = '#d1fae5';
                  badgeColor = '#065f46';
                  badgeBorder = '#34d399';
                } else if (isSold) {
                  badgeText = 'SOLD';
                  badgeBg = '#f1f5f9';
                  badgeColor = '#475569';
                  badgeBorder = '#cbd5e1';
                } else if (isDelisted) {
                  badgeText = 'DELISTED';
                  badgeBg = '#f3f4f6';
                  badgeColor = '#6b7280';
                  badgeBorder = '#d1d5db';
                }

                return (
                  <div style={{ position: 'relative' }}>
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
                          <span>${activeConversation.item.priceNzd} NZD • View</span>
                          <ExternalLink size={10} />
                        </div>
                      </div>
                    </Link>

                    {/* Corner Status Badge */}
                    <span
                      style={{
                        position: 'absolute',
                        top: '-8px',
                        right: '-6px',
                        backgroundColor: badgeBg,
                        color: badgeColor,
                        border: `1px solid ${badgeBorder}`,
                        fontSize: '0.62rem',
                        fontWeight: 800,
                        padding: '1px 6px',
                        borderRadius: '6px',
                        letterSpacing: '0.04em',
                        boxShadow: '0 1px 2px rgba(0,0,0,0.06)',
                        pointerEvents: 'none',
                      }}
                    >
                      {badgeText}
                    </span>
                  </div>
                );
              })()}
            </div>

            {/* KiwiShare Safe Trade Action Bar */}
            {activeConversation?.item && activeConversation.item.status !== 'sold' && (
              <div
                style={{
                  padding: '8px 18px',
                  backgroundColor: '#f8fafc',
                  borderBottom: '1px solid var(--border-subtle)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  flexWrap: 'wrap',
                  gap: '8px',
                  fontSize: '0.82rem',
                  flexShrink: 0,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-muted)' }}>
                  <ShieldCheck size={16} color="#059669" />
                  <span style={{ fontWeight: 500 }}>
                    {currentOrder?.status === 'paid' || currentOrder?.status === 'meeting_scheduled'
                      ? 'KiwiShare Escrow Active: Payment protected until meetup handover.'
                      : currentOrder?.status === 'completed'
                      ? 'Order Completed: Handover verified.'
                      : currentOrder?.status === 'refunded' || currentOrder?.isRefunded
                      ? 'Order Refunded: Funds returned to buyer.'
                      : 'Campus Safe Trade: NZ Escrow Protection.'}
                  </span>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flexWrap: 'wrap' }}>
                  {/* Buyer: Buy Now */}
                  {activeConversation.direction === 'buying' && (!currentOrder || currentOrder.status === 'pending' || currentOrder.status === 'refunded') && (
                    <button
                      onClick={() => setShowCheckoutModal(true)}
                      className="btn btn-primary"
                      style={{
                        padding: '6px 14px',
                        fontSize: '0.82rem',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '6px',
                        backgroundColor: '#059669',
                        borderColor: '#059669',
                      }}
                    >
                      <CreditCard size={14} />
                      <span>Buy Now (${activeConversation.item.priceNzd} NZD)</span>
                    </button>
                  )}

                  {/* Seller: Request Safe Pay */}
                  {activeConversation.direction === 'selling' && (!currentOrder || currentOrder.status === 'pending' || currentOrder.status === 'refunded') && (
                    <button
                      onClick={handleSendPaymentRequest}
                      className="btn btn-secondary"
                      style={{ padding: '6px 12px', fontSize: '0.82rem', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                    >
                      <CreditCard size={14} />
                      <span>Request Payment</span>
                    </button>
                  )}

                  {/* If Paid / Scheduled */}
                  {(currentOrder?.status === 'paid' || currentOrder?.status === 'meeting_scheduled') && !currentOrder?.isRefunded && (
                    <>
                      <button
                        onClick={() => setShowScheduleModal(true)}
                        className="btn btn-secondary"
                        style={{ padding: '6px 12px', fontSize: '0.82rem', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                      >
                        <Calendar size={14} />
                        <span>{currentOrder.meeting ? 'Reschedule' : 'Schedule Meetup'}</span>
                      </button>

                      <button
                        onClick={() => setShowQrModal(true)}
                        className="btn btn-primary"
                        style={{ padding: '6px 14px', fontSize: '0.82rem', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                      >
                        <QrCode size={14} />
                        <span>Meetup & QR</span>
                      </button>

                      <button
                        onClick={() => setShowInvoiceModal(true)}
                        className="btn btn-secondary"
                        style={{ padding: '6px 12px', fontSize: '0.82rem', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                        title="View Tax Invoice"
                      >
                        <Receipt size={14} />
                        <span>Invoice</span>
                      </button>

                      {/* Seller Refund */}
                      {activeConversation.direction === 'selling' && (
                        <button
                          onClick={handleRefundOrder}
                          disabled={isRefunding}
                          className="btn btn-secondary"
                          style={{ padding: '6px 12px', fontSize: '0.82rem', display: 'inline-flex', alignItems: 'center', gap: '6px', color: '#dc2626', borderColor: '#fca5a5' }}
                        >
                          <RotateCcw size={14} />
                          <span>{isRefunding ? 'Refunding…' : 'Refund'}</span>
                        </button>
                      )}

                      {/* Buyer 48h Refund Claim */}
                      {activeConversation.direction === 'buying' && (() => {
                        const ageHours = (Date.now() - new Date(currentOrder.createdAt).getTime()) / (1000 * 3600);
                        const isUnmet48h = ageHours >= 48 && (!currentOrder.meeting || currentOrder.meeting.proposalStatus !== 'accepted');
                        if (isUnmet48h) {
                          return (
                            <button
                              onClick={handleRefundOrder}
                              disabled={isRefunding}
                              className="btn btn-secondary"
                              style={{ padding: '6px 12px', fontSize: '0.82rem', display: 'inline-flex', alignItems: 'center', gap: '6px', color: '#b45309', borderColor: '#fde68a', backgroundColor: '#fffbeb' }}
                            >
                              <RotateCcw size={14} />
                              <span>Claim Refund (48h)</span>
                            </button>
                          );
                        }
                        return null;
                      })()}
                    </>
                  )}

                  {/* If Completed */}
                  {currentOrder?.status === 'completed' && (
                    <button
                      onClick={() => setShowInvoiceModal(true)}
                      className="btn btn-secondary"
                      style={{ padding: '6px 12px', fontSize: '0.82rem', display: 'inline-flex', alignItems: 'center', gap: '6px' }}
                    >
                      <Receipt size={14} />
                      <span>Invoice</span>
                    </button>
                  )}
                </div>
              </div>
            )}

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

                  const isPaymentConfirmed = msg.text?.startsWith('[Payment Confirmed]');
                  const isMeetupProposal = msg.text?.startsWith('[Meetup Proposal]');
                  const isPaymentRequest = msg.text?.startsWith('[Payment Request]');
                  const isMeetupConfirmed = msg.text?.startsWith('[Meetup Confirmed]');
                  const isHandoverConfirmed = msg.text?.startsWith('[Handover Confirmed]');
                  const isOrderRefunded = msg.text?.startsWith('[Order Refunded]');
                  const isTransactionEvent = isPaymentConfirmed || isMeetupProposal || isPaymentRequest || isMeetupConfirmed || isHandoverConfirmed || isOrderRefunded;

                  if (isTransactionEvent) {
                    return (
                      <div
                        key={msg.id}
                        style={{
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          width: '100%',
                          margin: '4px 0',
                        }}
                      >
                        {isPaymentConfirmed && (
                          <div
                            style={{
                              padding: '12px 18px',
                              borderRadius: '12px',
                              backgroundColor: '#ecfdf5',
                              border: '1.5px solid #a7f3d0',
                              color: '#065f46',
                              boxShadow: '0 2px 6px rgba(16, 185, 129, 0.1)',
                              maxWidth: '460px',
                              width: '100%',
                            }}
                          >
                            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '6px' }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontWeight: 800, fontSize: '0.92rem' }}>
                                <ShieldCheck size={20} color="#059669" />
                                <span>Safe Pay Confirmed</span>
                              </div>
                              <span style={{ fontSize: '0.68rem', backgroundColor: '#d1fae5', color: '#047857', padding: '2px 6px', borderRadius: '4px', fontWeight: 700 }}>PAID</span>
                            </div>
                            <div style={{ fontSize: '0.85rem', lineHeight: 1.45, color: '#047857', marginBottom: '10px' }}>
                              {msg.text?.replace('[Payment Confirmed] ', '')}
                            </div>
                            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                              <button
                                onClick={() => setShowInvoiceModal(true)}
                                className="btn btn-secondary"
                                style={{ padding: '4px 10px', fontSize: '0.78rem', backgroundColor: '#fff' }}
                              >
                                <Receipt size={12} />
                                <span>View Invoice</span>
                              </button>
                              <button
                                onClick={() => setShowScheduleModal(true)}
                                className="btn btn-primary"
                                style={{ padding: '4px 10px', fontSize: '0.78rem', backgroundColor: '#059669', borderColor: '#059669' }}
                              >
                                <Calendar size={12} />
                                <span>Schedule Meetup</span>
                              </button>
                            </div>
                          </div>
                        )}

                        {isMeetupProposal && (
                          <div
                            style={{
                              padding: '12px 18px',
                              borderRadius: '12px',
                              backgroundColor: '#eff6ff',
                              border: '1.5px solid #bfdbfe',
                              color: '#1e40af',
                              boxShadow: '0 2px 6px rgba(59, 130, 246, 0.1)',
                              maxWidth: '460px',
                              width: '100%',
                            }}
                          >
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px', fontWeight: 800, fontSize: '0.92rem' }}>
                              <MapPin size={18} color="#2563eb" />
                              <span>Meetup Proposal</span>
                            </div>
                            <div style={{ fontSize: '0.85rem', lineHeight: 1.45, color: '#1d4ed8', marginBottom: '10px' }}>
                              {msg.text?.replace('[Meetup Proposal] ', '')}
                            </div>
                            <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
                              {!isMine && (!meetupDetails || meetupDetails.proposalStatus === 'proposed') && (
                                <button
                                  onClick={handleAcceptMeetup}
                                  className="btn btn-primary"
                                  style={{ padding: '4px 12px', fontSize: '0.78rem', backgroundColor: '#2563eb', borderColor: '#2563eb' }}
                                >
                                  <Check size={13} />
                                  <span>Accept Meetup</span>
                                </button>
                              )}
                              <button
                                onClick={() => setShowQrModal(true)}
                                className="btn btn-secondary"
                                style={{ padding: '4px 10px', fontSize: '0.78rem', backgroundColor: '#fff' }}
                              >
                                <QrCode size={12} />
                                <span>View Handover Info</span>
                              </button>
                            </div>
                          </div>
                        )}

                        {isPaymentRequest && (
                          <div
                            style={{
                              padding: '12px 18px',
                              borderRadius: '12px',
                              backgroundColor: '#fffbeb',
                              border: '1.5px solid #fde68a',
                              color: '#92400e',
                              boxShadow: '0 2px 6px rgba(245, 158, 11, 0.1)',
                              maxWidth: '460px',
                              width: '100%',
                            }}
                          >
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px', fontWeight: 800, fontSize: '0.92rem' }}>
                              <CreditCard size={18} color="#d97706" />
                              <span>Payment Request</span>
                            </div>
                            <div style={{ fontSize: '0.85rem', lineHeight: 1.45, color: '#78350f', marginBottom: '10px' }}>
                              {msg.text?.replace('[Payment Request] ', '')}
                            </div>
                            {!isMine && (
                              <button
                                onClick={() => setShowCheckoutModal(true)}
                                className="btn btn-primary"
                                style={{ padding: '6px 14px', fontSize: '0.82rem', backgroundColor: '#059669', borderColor: '#059669' }}
                              >
                                <CreditCard size={14} />
                                <span>Pay Now with Safe Pay</span>
                              </button>
                            )}
                          </div>
                        )}

                        {isMeetupConfirmed && (
                          <div
                            style={{
                              padding: '10px 16px',
                              borderRadius: '10px',
                              backgroundColor: '#f0fdf4',
                              border: '1px solid #bbf7d0',
                              color: '#166534',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '8px',
                              fontSize: '0.84rem',
                              fontWeight: 600,
                              maxWidth: '460px',
                              width: '100%',
                            }}
                          >
                            <CheckCircle2 size={16} color="#16a34a" style={{ flexShrink: 0 }} />
                            <span>{msg.text?.replace('[Meetup Confirmed] ', '')}</span>
                          </div>
                        )}

                        {isHandoverConfirmed && (
                          <div
                            style={{
                              padding: '10px 16px',
                              borderRadius: '10px',
                              backgroundColor: '#f5f3ff',
                              border: '1px solid #ddd6fe',
                              color: '#5b21b6',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '8px',
                              fontSize: '0.84rem',
                              fontWeight: 600,
                              maxWidth: '460px',
                              width: '100%',
                            }}
                          >
                            <CheckCircle2 size={16} color="#7c3aed" style={{ flexShrink: 0 }} />
                            <span>{msg.text?.replace('[Handover Confirmed] ', '')}</span>
                          </div>
                        )}

                        {isOrderRefunded && (
                          <div
                            style={{
                              padding: '10px 16px',
                              borderRadius: '10px',
                              backgroundColor: '#fee2e2',
                              border: '1px solid #fca5a5',
                              color: '#991b1b',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '8px',
                              fontSize: '0.84rem',
                              fontWeight: 600,
                              maxWidth: '460px',
                              width: '100%',
                            }}
                          >
                            <RotateCcw size={16} color="#dc2626" style={{ flexShrink: 0 }} />
                            <span>{msg.text?.replace('[Order Refunded] ', '')}</span>
                          </div>
                        )}

                        <div style={{ fontSize: '0.68rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                          {formatTimestamp(msg.createdAt)}
                        </div>
                      </div>
                    );
                  }

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
                          padding: msg.type === 'image' ? '4px' : (msg.type === 'voice' || msg.audioUrl) ? '8px 12px' : '10px 14px',
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
                        {/* Voice message */}
                        {(msg.type === 'voice' || Boolean(msg.audioUrl)) && (
                          <VoiceAudioPlayer
                            audioUrl={msg.audioUrl || ''}
                            durationMs={msg.durationMs}
                            isMine={isMine}
                          />
                        )}

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

      {/* 1. KiwiShare Safe Pay Checkout Modal */}
      {showCheckoutModal && activeConversation?.item && (() => {
        const priceNum = parseFloat(currentOrder?.itemAmountNzd || activeConversation.item.priceNzd || '0') || 0;
        const feeNum = Math.max(1, Math.round(priceNum * 0.05 * 100) / 100);
        const gstNum = feeNum * (3 / 23); // 15% NZ GST included in platform fee
        const totalNum = priceNum + feeNum;

        return (
          <div
            style={{
              position: 'fixed',
              inset: 0,
              backgroundColor: 'rgba(0, 0, 0, 0.65)',
              zIndex: 1000,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '16px',
              backdropFilter: 'blur(3px)',
            }}
          >
            <div
              className="glass-card"
              style={{
                backgroundColor: '#ffffff',
                borderRadius: 'var(--radius-lg)',
                padding: '24px',
                maxWidth: '480px',
                width: '100%',
                boxShadow: 'var(--shadow-xl)',
                position: 'relative',
              }}
            >
              <button
                onClick={() => setShowCheckoutModal(false)}
                disabled={isProcessingPayment}
                style={{
                  position: 'absolute',
                  top: '16px',
                  right: '16px',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: 'var(--text-muted)',
                }}
              >
                <X size={20} />
              </button>

              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
                <div
                  style={{
                    width: '40px',
                    height: '40px',
                    borderRadius: '10px',
                    backgroundColor: '#ecfdf5',
                    color: '#059669',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <ShieldCheck size={24} />
                </div>
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.2rem', fontWeight: 800 }}>KiwiShare Safe Pay</h3>
                  <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                    Campus Escrow Protection • 100% In-Person Guarantee
                  </p>
                </div>
              </div>

              {/* Item Snapshot */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  padding: '12px',
                  backgroundColor: '#f8fafc',
                  borderRadius: '10px',
                  marginBottom: '16px',
                  border: '1px solid var(--border-subtle)',
                }}
              >
                {activeConversation.item.imageUrl ? (
                  <img
                    src={activeConversation.item.imageUrl}
                    alt=""
                    style={{ width: '48px', height: '48px', borderRadius: '8px', objectFit: 'cover' }}
                  />
                ) : (
                  <div
                    style={{
                      width: '48px',
                      height: '48px',
                      borderRadius: '8px',
                      backgroundColor: '#e2e8f0',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    <ShoppingBag size={20} color="var(--primary-600)" />
                  </div>
                )}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: '0.92rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {activeConversation.item.title}
                  </div>
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-muted)' }}>
                    Seller: {activeConversation.participant.displayName}
                  </div>
                </div>
                <div style={{ fontWeight: 800, fontSize: '1.05rem', color: 'var(--text-main)' }}>
                  ${priceNum.toFixed(2)}
                </div>
              </div>

              {/* Price Breakdown with NZ 15% GST */}
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '8px',
                  fontSize: '0.86rem',
                  padding: '12px 14px',
                  backgroundColor: '#f8fafc',
                  borderRadius: '10px',
                  marginBottom: '16px',
                  border: '1px solid var(--border-subtle)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-muted)' }}>Item Price (Private C2C Sale)</span>
                  <span style={{ fontWeight: 600 }}>${priceNum.toFixed(2)} NZD</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-muted)' }}>KiwiShare Escrow Protection</span>
                  <span style={{ fontWeight: 600 }}>${feeNum.toFixed(2)} NZD</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', paddingLeft: '12px', color: '#64748b', fontSize: '0.78rem' }}>
                  <span>  └ Includes 15% NZ GST on platform fee</span>
                  <span>${gstNum.toFixed(2)} NZD</span>
                </div>
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    borderTop: '1px dashed var(--border-subtle)',
                    paddingTop: '8px',
                    marginTop: '4px',
                    fontSize: '1rem',
                    fontWeight: 800,
                  }}
                >
                  <span>Total Amount</span>
                  <span style={{ color: '#059669', fontSize: '1.2rem' }}>${totalNum.toFixed(2)} NZD</span>
                </div>
              </div>

              {totalNum > 0 && (
                <div style={{ marginBottom: '16px' }}>
                  <label style={{ display: 'block', fontSize: '0.82rem', fontWeight: 700, marginBottom: '6px' }}>
                    Payment card
                  </label>
                  <input
                    className="form-input"
                    inputMode="numeric"
                    autoComplete="cc-number"
                    placeholder="Card number"
                    value={cardNumber}
                    onChange={(e) => setCardNumber(e.target.value.replace(/[^\d ]/g, ''))}
                    disabled={isProcessingPayment}
                    style={{ width: '100%', marginBottom: '8px' }}
                  />
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px' }}>
                    <input
                      className="form-input"
                      inputMode="numeric"
                      autoComplete="cc-exp"
                      placeholder="MM/YY"
                      value={cardExpiry}
                      onChange={(e) => setCardExpiry(e.target.value.replace(/[^\d/ ]/g, ''))}
                      disabled={isProcessingPayment}
                    />
                    <input
                      className="form-input"
                      inputMode="numeric"
                      autoComplete="cc-csc"
                      placeholder="CVC"
                      value={cardCvc}
                      onChange={(e) => setCardCvc(e.target.value.replace(/\D/g, '').slice(0, 4))}
                      disabled={isProcessingPayment}
                    />
                  </div>
                  <div style={{ marginTop: '6px', fontSize: '0.72rem', color: 'var(--text-muted)' }}>
                    Payment must be accepted by Stripe before KiwiShare marks this order as paid.
                  </div>
                </div>
              )}

              {/* NZ Tax and Escrow Note */}
              <div
                style={{
                  display: 'flex',
                  gap: '8px',
                  padding: '10px 12px',
                  backgroundColor: '#f0fdf4',
                  border: '1px solid #bbf7d0',
                  borderRadius: '8px',
                  color: '#166534',
                  fontSize: '0.78rem',
                  lineHeight: 1.45,
                  marginBottom: '18px',
                }}
              >
                <ShieldCheck size={16} color="#16a34a" style={{ flexShrink: 0, marginTop: '2px' }} />
                <span>
                  <strong>NZ Tax & Protection Note:</strong> Peer-to-peer individual sales are not subject to GST under NZ IRD rules. Platform escrow fee includes 15% NZ GST. Funds are held in KiwiShare Escrow and will only be released when you inspect the item and confirm handover.
                </span>
              </div>

              <div style={{ display: 'flex', gap: '10px' }}>
                <button
                  type="button"
                  onClick={() => setShowCheckoutModal(false)}
                  disabled={isProcessingPayment}
                  className="btn btn-secondary"
                  style={{ flex: 1, padding: '10px' }}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={handleSafePayCheckout}
                  disabled={isProcessingPayment}
                  className="btn btn-primary"
                  style={{
                    flex: 2,
                    padding: '10px',
                    backgroundColor: '#059669',
                    borderColor: '#059669',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                  }}
                >
                  {isProcessingPayment ? (
                    <>
                      <Loader2 size={16} className="animate-spin" />
                      <span>Authorizing…</span>
                    </>
                  ) : (
                    <>
                      <CreditCard size={16} />
                      <span>Authorize & Pay ${totalNum.toFixed(2)} NZD</span>
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        );
      })()}

      {/* 2. Schedule Meetup Modal */}
      {showScheduleModal && currentOrder && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.65)',
            zIndex: 1000,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '16px',
            backdropFilter: 'blur(3px)',
          }}
        >
          <div
            className="glass-card"
            style={{
              backgroundColor: '#ffffff',
              borderRadius: 'var(--radius-lg)',
              padding: '24px',
              maxWidth: '480px',
              width: '100%',
              boxShadow: 'var(--shadow-xl)',
              position: 'relative',
            }}
          >
            <button
              onClick={() => setShowScheduleModal(false)}
              disabled={isSubmittingMeetup}
              style={{
                position: 'absolute',
                top: '16px',
                right: '16px',
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                color: 'var(--text-muted)',
              }}
            >
              <X size={20} />
            </button>

            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '16px' }}>
              <div
                style={{
                  width: '40px',
                  height: '40px',
                  borderRadius: '10px',
                  backgroundColor: '#eff6ff',
                  color: '#2563eb',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                <Calendar size={22} />
              </div>
              <div>
                <h3 style={{ margin: 0, fontSize: '1.2rem', fontWeight: 800 }}>Schedule Campus Meetup</h3>
                <p style={{ margin: 0, fontSize: '0.8rem', color: 'var(--text-muted)' }}>
                  Coordinate in-person item inspection and handover
                </p>
              </div>
            </div>

            <form onSubmit={handleProposeMeetup} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>
                  Meetup Date & Time
                </label>
                <input
                  type="datetime-local"
                  required
                  value={meetupDate}
                  onChange={(e) => setMeetupDate(e.target.value)}
                  className="form-input"
                  style={{ width: '100%', padding: '9px 12px', fontSize: '0.9rem', borderRadius: '8px' }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>
                  Campus / Suburb Location
                </label>
                <input
                  type="text"
                  required
                  list="chat-campus-datalist"
                  value={meetupLocation}
                  onChange={(e) => setMeetupLocation(e.target.value)}
                  placeholder="Type or select a campus or suburb..."
                  className="form-input"
                  style={{ width: '100%', padding: '9px 12px', fontSize: '0.9rem', borderRadius: '8px' }}
                />
                <datalist id="chat-campus-datalist">
                  {CAMPUS_LOCATIONS.map((loc) => (
                    <option key={loc.name} value={loc.name}>
                      {loc.city} • {loc.category}
                    </option>
                  ))}
                </datalist>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: '6px' }}>
                  Meeting Notes (Optional)
                </label>
                <input
                  type="text"
                  value={meetupNote}
                  onChange={(e) => setMeetupNote(e.target.value)}
                  placeholder="e.g. Near the library entrance, wearing a blue jacket"
                  className="form-input"
                  style={{ width: '100%', padding: '9px 12px', fontSize: '0.9rem', borderRadius: '8px' }}
                />
              </div>

              <div style={{ display: 'flex', gap: '10px', marginTop: '8px' }}>
                <button
                  type="button"
                  onClick={() => setShowScheduleModal(false)}
                  disabled={isSubmittingMeetup}
                  className="btn btn-secondary"
                  style={{ flex: 1, padding: '10px' }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingMeetup}
                  className="btn btn-primary"
                  style={{
                    flex: 2,
                    padding: '10px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '8px',
                  }}
                >
                  {isSubmittingMeetup ? <Loader2 size={16} className="animate-spin" /> : <Calendar size={16} />}
                  <span>Send Proposal</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* 3. Meetup Handover QR & Confirmation Modal */}
      {showQrModal && currentOrder && (() => {
        const isPaid = currentOrder.status === 'paid' || currentOrder.status === 'meeting_scheduled' || currentOrder.status === 'completed';
        const isMeetupConfirmed = currentOrder.meeting?.proposalStatus === 'accepted' || meetupDetails?.proposalStatus === 'accepted';
        const role = activeConversation?.direction === 'buying' ? 'buyer' : 'seller';

        return (
          <div
            style={{
              position: 'fixed',
              inset: 0,
              backgroundColor: 'rgba(0, 0, 0, 0.65)',
              zIndex: 1000,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '16px',
              backdropFilter: 'blur(3px)',
            }}
          >
            <div
              className="glass-card"
              style={{
                backgroundColor: '#ffffff',
                borderRadius: 'var(--radius-lg)',
                padding: '24px',
                maxWidth: '440px',
                width: '100%',
                boxShadow: 'var(--shadow-xl)',
                position: 'relative',
                textAlign: 'center',
              }}
            >
              <button
                onClick={() => setShowQrModal(false)}
                disabled={isConfirmingHandover}
                style={{
                  position: 'absolute',
                  top: '16px',
                  right: '16px',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: 'var(--text-muted)',
                }}
              >
                <X size={20} />
              </button>

              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: '#e0e7ff', color: '#4338ca', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 12px' }}>
                <QrCode size={26} />
              </div>

              <h3 style={{ margin: '0 0 4px', fontSize: '1.25rem', fontWeight: 800 }}>Campus Handover QR</h3>
              <p style={{ margin: '0 0 16px', fontSize: '0.82rem', color: 'var(--text-muted)' }}>
                Order #{currentOrder.orderNumber || currentOrder.id.slice(0, 8)}
              </p>

              {!isPaid ? (
                <div style={{ padding: '16px', backgroundColor: '#fffbeb', borderRadius: '10px', border: '1px solid #fde68a', color: '#92400e', fontSize: '0.88rem', marginBottom: '16px' }}>
                  <AlertCircle size={20} style={{ margin: '0 auto 6px', color: '#d97706' }} />
                  <div style={{ fontWeight: 700 }}>Payment Required First</div>
                  <div>Buyer must complete Safe Pay checkout before the handover QR code can be released.</div>
                  {activeConversation?.direction === 'buying' && (
                    <button
                      onClick={() => {
                        setShowQrModal(false);
                        setShowCheckoutModal(true);
                      }}
                      className="btn btn-primary"
                      style={{
                        marginTop: '12px',
                        padding: '8px 16px',
                        fontSize: '0.85rem',
                        backgroundColor: '#059669',
                        borderColor: '#059669',
                        display: 'inline-flex',
                        alignItems: 'center',
                        gap: '6px',
                      }}
                    >
                      <CreditCard size={15} />
                      <span>Pay Now (${activeConversation?.item?.priceNzd || '0'} NZD)</span>
                    </button>
                  )}
                </div>
              ) : !isMeetupConfirmed ? (
                <div style={{ padding: '16px', backgroundColor: '#eff6ff', borderRadius: '10px', border: '1px solid #bfdbfe', color: '#1e40af', fontSize: '0.88rem', marginBottom: '16px' }}>
                  <Calendar size={20} style={{ margin: '0 auto 6px', color: '#2563eb' }} />
                  <div style={{ fontWeight: 700 }}>Meetup Agreement Required</div>
                  <div>Both parties must agree on the meetup time and campus location before item handover.</div>
                  <button
                    onClick={() => {
                      setShowQrModal(false);
                      setShowScheduleModal(true);
                    }}
                    className="btn btn-primary"
                    style={{ marginTop: '12px', padding: '6px 14px', fontSize: '0.82rem' }}
                  >
                    Schedule Meetup
                  </button>
                </div>
              ) : (
                <>
                  {/* Visual QR Code Card */}
                  <div
                    style={{
                      padding: '20px',
                      backgroundColor: '#f8fafc',
                      border: '2px dashed var(--primary-300)',
                      borderRadius: '16px',
                      display: 'inline-flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      gap: '10px',
                      marginBottom: '16px',
                    }}
                  >
                    <div
                      style={{
                        width: '160px',
                        height: '160px',
                        backgroundColor: '#ffffff',
                        padding: '10px',
                        borderRadius: '12px',
                        boxShadow: 'var(--shadow-sm)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <svg viewBox="0 0 100 100" width="140" height="140">
                        {/* Styled QR pattern placeholder */}
                        <rect width="100" height="100" fill="white" />
                        <rect x="10" y="10" width="25" height="25" fill="#0f172a" />
                        <rect x="15" y="15" width="15" height="15" fill="white" />
                        <rect x="18" y="18" width="9" height="9" fill="#0f172a" />

                        <rect x="65" y="10" width="25" height="25" fill="#0f172a" />
                        <rect x="70" y="15" width="15" height="15" fill="white" />
                        <rect x="73" y="18" width="9" height="9" fill="#0f172a" />

                        <rect x="10" y="65" width="25" height="25" fill="#0f172a" />
                        <rect x="15" y="70" width="15" height="15" fill="white" />
                        <rect x="18" y="73" width="9" height="9" fill="#0f172a" />

                        <rect x="42" y="10" width="8" height="8" fill="#059669" />
                        <rect x="42" y="24" width="8" height="8" fill="#059669" />
                        <rect x="10" y="42" width="8" height="8" fill="#059669" />
                        <rect x="24" y="42" width="8" height="8" fill="#059669" />
                        <rect x="42" y="42" width="16" height="16" fill="#0f172a" rx="4" />
                        <rect x="46" y="46" width="8" height="8" fill="#10b981" />
                        <rect x="65" y="42" width="10" height="8" fill="#0f172a" />
                        <rect x="80" y="42" width="10" height="8" fill="#0f172a" />
                        <rect x="42" y="65" width="10" height="10" fill="#0f172a" />
                        <rect x="58" y="65" width="15" height="10" fill="#0f172a" />
                        <rect x="78" y="65" width="12" height="10" fill="#0f172a" />
                        <rect x="42" y="80" width="20" height="10" fill="#0f172a" />
                        <rect x="68" y="80" width="22" height="10" fill="#059669" />
                      </svg>
                    </div>
                    <span style={{ fontSize: '0.78rem', color: 'var(--text-muted)', fontFamily: 'monospace' }}>
                      Token: {currentOrder.id.slice(0, 16).toUpperCase()}
                    </span>
                  </div>

                  {/* Scheduled location and time */}
                  {currentOrder.meeting && (
                    <div style={{ backgroundColor: '#f0fdf4', border: '1px solid #bbf7d0', borderRadius: '8px', padding: '10px 14px', textAlign: 'left', fontSize: '0.82rem', marginBottom: '16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 600, color: '#166534', marginBottom: '4px' }}>
                        <MapPin size={14} />
                        <span>{currentOrder.meeting.locationName}</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#166534' }}>
                        <Calendar size={14} />
                        <span>{new Date(currentOrder.meeting.scheduledAt).toLocaleString('en-NZ', { dateStyle: 'medium', timeStyle: 'short' })}</span>
                      </div>
                    </div>
                  )}

                  {/* Role Confirmation Button */}
                  <button
                    onClick={() => handleConfirmHandover(role)}
                    disabled={isConfirmingHandover}
                    className="btn btn-primary"
                    style={{
                      width: '100%',
                      padding: '11px',
                      backgroundColor: role === 'buyer' ? '#059669' : 'var(--primary-600)',
                      borderColor: role === 'buyer' ? '#059669' : 'var(--primary-600)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '8px',
                      fontSize: '0.92rem',
                    }}
                  >
                    {isConfirmingHandover ? (
                      <>
                        <Loader2 size={16} className="animate-spin" />
                        <span>Confirming Handover…</span>
                      </>
                    ) : role === 'buyer' ? (
                      <>
                        <CheckCircle2 size={18} />
                        <span>Confirm Receipt & Release Escrow</span>
                      </>
                    ) : (
                      <>
                        <CheckCircle2 size={18} />
                        <span>Confirm Handover to Buyer</span>
                      </>
                    )}
                  </button>
                </>
              )}
            </div>
          </div>
        );
      })()}

      {/* 4. Tax Invoice Modal with NZ 15% GST */}
      {showInvoiceModal && currentOrder && (() => {
        const priceNum = parseFloat(currentOrder.item?.priceNzd || '0') || 0;
        const feeNum = currentOrder.buyerFeeAmountNzd ? parseFloat(currentOrder.buyerFeeAmountNzd) : Math.max(1, Math.round(priceNum * 0.05 * 100) / 100);
        const gstNum = feeNum * (3 / 23); // 15% NZ GST included in fee
        const totalNum = currentOrder.buyerTotalAmountNzd ? parseFloat(currentOrder.buyerTotalAmountNzd) : priceNum + feeNum;

        return (
          <div
            style={{
              position: 'fixed',
              inset: 0,
              backgroundColor: 'rgba(0, 0, 0, 0.65)',
              zIndex: 1000,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '16px',
              backdropFilter: 'blur(3px)',
            }}
          >
            <div
              className="glass-card"
              style={{
                backgroundColor: '#ffffff',
                borderRadius: 'var(--radius-lg)',
                padding: '24px',
                maxWidth: '480px',
                width: '100%',
                boxShadow: 'var(--shadow-xl)',
                position: 'relative',
              }}
            >
              <button
                onClick={() => setShowInvoiceModal(false)}
                style={{
                  position: 'absolute',
                  top: '16px',
                  right: '16px',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: 'var(--text-muted)',
                }}
              >
                <X size={20} />
              </button>

              {/* Header */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '20px', paddingBottom: '16px', borderBottom: '1px solid var(--border-subtle)' }}>
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <Receipt size={22} color="#059669" />
                    <h3 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800 }}>Payment Invoice</h3>
                  </div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '4px' }}>
                    KiwiShare NZ C2C Marketplace
                  </div>
                </div>
                <span
                  style={{
                    padding: '4px 10px',
                    borderRadius: '6px',
                    fontSize: '0.75rem',
                    fontWeight: 800,
                    letterSpacing: '0.5px',
                    backgroundColor: currentOrder.isRefunded || currentOrder.status === 'refunded' ? '#fee2e2' : '#d1fae5',
                    color: currentOrder.isRefunded || currentOrder.status === 'refunded' ? '#991b1b' : '#065f46',
                    border: `1.2px solid ${currentOrder.isRefunded || currentOrder.status === 'refunded' ? '#ef4444' : '#10b981'}`,
                  }}
                >
                  {currentOrder.isRefunded || currentOrder.status === 'refunded' ? 'REFUNDED' : 'PAID'}
                </span>
              </div>

              {/* Metadata Rows */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '0.85rem', marginBottom: '16px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-muted)' }}>Invoice Number</span>
                  <span style={{ fontWeight: 600, fontFamily: 'monospace' }}>INV-ORD-{currentOrder.orderNumber || currentOrder.id.slice(0, 8)}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-muted)' }}>Order ID</span>
                  <span style={{ fontWeight: 600, fontFamily: 'monospace' }}>{currentOrder.id}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-muted)' }}>Date</span>
                  <span style={{ fontWeight: 600 }}>{new Date(currentOrder.createdAt).toLocaleDateString('en-NZ', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</span>
                </div>
              </div>

              {/* Item Snapshot */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px', backgroundColor: '#f8fafc', borderRadius: '8px', marginBottom: '18px' }}>
                {currentOrder.item?.imageUrl ? (
                  <img src={currentOrder.item.imageUrl} alt="" style={{ width: '48px', height: '48px', borderRadius: '6px', objectFit: 'cover' }} />
                ) : (
                  <div style={{ width: '48px', height: '48px', borderRadius: '6px', backgroundColor: '#e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <ShoppingBag size={20} color="var(--primary-600)" />
                  </div>
                )}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 700, fontSize: '0.9rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {currentOrder.item?.title}
                  </div>
                  <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginTop: '2px' }}>
                    Counterparty: {currentOrder.counterparty?.displayName || activeConversation?.participant?.displayName}
                  </div>
                </div>
                <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>
                  ${priceNum.toFixed(2)} NZD
                </div>
              </div>

              {/* Financial Breakdown with 15% NZ GST */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '0.85rem', borderTop: '1px solid var(--border-subtle)', paddingTop: '12px', marginBottom: '16px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-muted)' }}>Item Subtotal (Private Sale)</span>
                  <span style={{ fontWeight: 600 }}>${priceNum.toFixed(2)} NZD</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ color: 'var(--text-muted)' }}>Buyer Escrow & Protection</span>
                  <span style={{ fontWeight: 600 }}>${feeNum.toFixed(2)} NZD</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', paddingLeft: '12px', color: '#64748b', fontSize: '0.78rem' }}>
                  <span>  └ Includes 15% NZ GST on platform fee</span>
                  <span>${gstNum.toFixed(2)} NZD</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '1rem', fontWeight: 800, marginTop: '6px', paddingTop: '8px', borderTop: '1px dashed var(--border-subtle)' }}>
                  <span>Total Paid</span>
                  <span style={{ color: '#059669', fontSize: '1.15rem' }}>
                    ${totalNum.toFixed(2)} NZD
                  </span>
                </div>
              </div>

              {/* Guarantee Note */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 12px', backgroundColor: '#f0fdf4', borderRadius: '8px', border: '1px solid #bbf7d0', color: '#166534', fontSize: '0.78rem', marginBottom: '20px' }}>
                <ShieldCheck size={16} color="#16a34a" style={{ flexShrink: 0 }} />
                <span>KiwiShare Campus Escrow Protection Guarantee: Funds held securely until handover.</span>
              </div>

              <button
                onClick={() => setShowInvoiceModal(false)}
                className="btn btn-primary"
                style={{ width: '100%', padding: '10px' }}
              >
                Close Invoice
              </button>
            </div>
          </div>
        );
      })()}

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
