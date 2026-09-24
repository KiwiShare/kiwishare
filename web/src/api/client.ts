export interface UserProfile {
  id: string;
  _id?: string;
  email: string;
  username?: string | null;
  needsUsername?: boolean;
  displayName: string;
  avatarUrl?: string | null;
  role?: 'admin' | 'user';
  trustScore: number;
  kiwiGold?: number;
  isVerified: boolean;
  isStudentVerified?: boolean;
  studentInstitution?: string;
  studentIdNumber?: string;
  isBanned?: boolean;
  status?: string;
  itemsCount?: number;
  registrationPlatform?: string;
  lastUsedPlatform?: string;
  lastActiveAt?: string;
  createdAt?: string;
}

export interface CategoryItem {
  id: string;
  _id?: string;
  name: string;
  slug: string;
  icon: string;
  description?: string;
  sortOrder: number;
  isActive: boolean;
  itemCount?: number;
}

export interface UsedItem {
  id: string;
  _id?: string;
  title: string;
  description: string;
  category: string;
  condition: string;
  price: number;
  priceNzd?: string;
  currency?: string;
  images?: Array<{ url: string; sortOrder: number }>;
  imageUrl?: string;
  location?: {
    city?: string;
    suburb?: string;
    coordinates?: {
      coordinates: [number, number];
    };
  };
  sellerId?: string;
  ownerId?: string;
  seller?: {
    id: string;
    displayName: string;
    email?: string;
    avatarUrl?: string | null;
    trustScore?: number;
    isVerified?: boolean;
    isStudentVerified?: boolean;
    studentInstitution?: string;
    role?: string;
  };
  status: string;
  isSustainable?: boolean;
  isFree?: boolean;
  watchlistCount?: number;
  favouriteCount?: number;
  viewCount?: number;
  createdAt?: string;
}

export interface AuthResponse {
  status: string;
  token: string;
  user: UserProfile;
}

export interface AdminOrderStats {
  totalOrders: number;
  completedOrders: number;
  activeOrders: number;
  cancelledOrders: number;
  totalGmvNzd: string;
  totalPlatformFeesNzd: string;
  totalSellerPayoutsNzd: string;
  statusBreakdown: Record<string, number>;
  recentOrders: Array<{
    id: string;
    orderNumber: string;
    status: string;
    itemTitle: string;
    itemImageUrl: string;
    buyerName: string;
    buyerEmail?: string;
    sellerName: string;
    sellerEmail?: string;
    itemAmountNzd: string;
    buyerFeeNzd: string;
    sellerFeeNzd: string;
    platformFeeNzd: string;
    buyerTotalNzd: string;
    sellerReceiveNzd: string;
    createdAt: string;
  }>;
}

export interface AdminStats {
  totalUsers: number;
  totalItems: number;
  activeItems: number;
  revokedItems: number;
  soldItems: number;
  totalWatchlistEntries: number;
  platformStats: Record<string, number>;
  categoryDistribution: Array<{ category: string; count: number }>;
  recentUsers: Array<{ displayName: string; email: string; role: string; registrationPlatform: string; createdAt: string }>;
  recentItems: UsedItem[];
  orderStats?: AdminOrderStats;
}

export interface ConversationParticipant {
  id: string;
  displayName: string;
  avatarUrl: string | null;
}

export interface ConversationItemSummary {
  id: string;
  title: string;
  imageUrl: string;
  status?: string;
  priceNzd?: string;
}

export interface ConversationItem {
  id: string;
  status: string;
  direction: 'buying' | 'selling';
  unreadCount: number;
  lastMessageText: string;
  lastMessageAt: string | null;
  item: ConversationItemSummary;
  participant: ConversationParticipant;
  createdAt: string;
  updatedAt: string;
}

export interface ChatMessage {
  id: string;
  conversationId: string;
  senderId: string;
  receiverId: string;
  type: 'text' | 'image' | 'voice' | 'location';
  text: string;
  imageUrl: string | null;
  audioUrl: string | null;
  durationMs: number | null;
  location?: {
    name: string;
    latitude: number;
    longitude: number;
  } | null;
  status: string;
  isMine: boolean;
  readAt: string | null;
  createdAt: string;
  updatedAt: string;
}


/**
 * Resolves the backend API base URL.
 * Supports environment variables VITE_API_URL / VITE_API_BASE_URL
 * (e.g. https://kiwishare.onrender.com or https://kiwishare.onrender.com/api).
 * Falls back to relative '/api' for Vite dev proxy.
 */
export function getApiBaseUrl(): string {
  const envUrl = (import.meta.env?.VITE_API_URL || import.meta.env?.VITE_API_BASE_URL || '') as string;
  if (envUrl && envUrl.trim() !== '') {
    const clean = envUrl.trim().replace(/\/+$/, '');
    return clean.endsWith('/api') ? clean : `${clean}/api`;
  }
  return '/api';
}

function getAuthToken(): string | null {
  return localStorage.getItem('kiwishare_token');
}

export async function apiRequest<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const token = getAuthToken();
  const headers = new Headers(options.headers || {});

  // Platform and content headers
  headers.set('x-client-platform', 'web');
  if (!headers.has('Content-Type') && !(options.body instanceof FormData)) {
    headers.set('Content-Type', 'application/json');
  }

  if (token) {
    headers.set('Authorization', `Bearer ${token}`);
  }

  const apiBase = getApiBaseUrl();
  const cleanEndpoint = endpoint.startsWith('/') ? endpoint.slice(1) : endpoint;
  const url = endpoint.startsWith('http') ? endpoint : `${apiBase}/${cleanEndpoint}`;

  const res = await fetch(url, {
    ...options,
    headers,
  });

  const data = await res.json().catch(() => ({}));

  if (!res.ok) {
    throw new Error(data.message || `API Error: ${res.statusText}`);
  }

  return data as T;
}

// Authentication APIs
export const authApi = {
  register: (body: { email: string; password?: string; displayName: string; platform?: string }) =>
    apiRequest<AuthResponse>('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ ...body, platform: 'web' }),
    }),

  login: (body: { email: string; password?: string; platform?: string }) =>
    apiRequest<AuthResponse>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ ...body, platform: 'web' }),
    }),

  sendOtp: (email: string) =>
    apiRequest<{ status: string; message: string; devCode?: string }>('/auth/send-otp', {
      method: 'POST',
      body: JSON.stringify({ email }),
    }),

  verifyOtp: (body: { email: string; code: string; displayName?: string }) =>
    apiRequest<AuthResponse>('/auth/verify-otp', {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  loginWithGoogle: (idToken: string) =>
    apiRequest<AuthResponse>('/auth/google', {
      method: 'POST',
      body: JSON.stringify({ idToken }),
    }),

  getMe: () =>
    apiRequest<{ status: string; user: UserProfile }>('/users/me'),

  updateMe: (body: { username?: string }) =>
    apiRequest<{ status: string; user: UserProfile }>('/users/me', {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),
};

// Category APIs
export const categoriesApi = {
  getCategories: (includeInactive = false) =>
    apiRequest<{ status: string; count: number; categories: CategoryItem[] }>(`/categories?includeInactive=${includeInactive}`),

  createCategory: (body: { name: string; slug?: string; icon?: string; description?: string; sortOrder?: number }) =>
    apiRequest<{ status: string; category: CategoryItem }>('/categories', {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  updateCategory: (id: string, body: Partial<CategoryItem>) =>
    apiRequest<{ status: string; category: CategoryItem }>(`/categories/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),

  deleteCategory: (id: string) =>
    apiRequest<{ status: string; message: string }>(`/categories/${id}`, {
      method: 'DELETE',
    }),
};

// Items & Discovery APIs
export const itemsApi = {
  getItems: async (params?: Record<string, any>) => {
    const query = new URLSearchParams();
    if (params) {
      Object.entries(params).forEach(([key, val]) => {
        if (val !== undefined && val !== null && val !== '') {
          query.set(key, String(val));
        }
      });
    }
    const qStr = query.toString();
    const data = await apiRequest<any>(`/usedItems${qStr ? `?${qStr}` : ''}`);
    if (Array.isArray(data)) {
      return { status: 'success', count: data.length, items: data as UsedItem[] };
    }
    return { status: 'success', count: data.items?.length || 0, items: data.items || [] };
  },

  getRecommended: async (limit = 10) => {
    const data = await apiRequest<any>(`/usedItems/recommended?limit=${limit}`);
    if (Array.isArray(data)) {
      return { status: 'success', count: data.length, items: data as UsedItem[] };
    }
    return { status: 'success', count: data.items?.length || 0, items: data.items || [] };
  },

  getItemById: async (id: string) => {
    const data = await apiRequest<any>(`/usedItems/${id}`);
    const item = data.item || data;
    return { status: 'success', item: item as UsedItem };
  },

  getDiscoveryOptions: () =>
    apiRequest<{ status: string; categories: Array<{ value: string; count: number }>; locations: any[]; priceRange: any }>('/usedItems/discovery-options'),

  createItem: (body: {
    title: string;
    description: string;
    category: string;
    priceNzd: string;
    condition: string;
    city: string;
    suburb?: string;
    imageUrl?: string;
    images?: Array<{ url: string; sortOrder?: number }>;
    imageUrls?: string[];
    isSustainable?: boolean;
    targetUserEmail?: string;
    targetUserId?: string;
    sellerId?: string;
  }) => {
    let imagesPayload: Array<{ url: string; sortOrder: number }> = [];
    if (Array.isArray(body.images) && body.images.length > 0) {
      imagesPayload = body.images.map((im, idx) => ({ url: im.url, sortOrder: im.sortOrder ?? idx }));
    } else if (Array.isArray(body.imageUrls) && body.imageUrls.length > 0) {
      imagesPayload = body.imageUrls.map((url, idx) => ({ url, sortOrder: idx }));
    } else if (body.imageUrl) {
      imagesPayload = [{ url: body.imageUrl, sortOrder: 0 }];
    }

    return apiRequest<{ status: string; item: UsedItem }>('/usedItems', {
      method: 'POST',
      body: JSON.stringify({
        ...body,
        location: {
          city: body.city || 'Auckland',
          suburb: body.suburb || '',
        },
        price: Math.round(parseFloat(body.priceNzd || '0') * 100),
        priceNzd: body.priceNzd,
        currency: 'NZD',
        status: 'active',
        imageUrl: imagesPayload[0]?.url || body.imageUrl || '',
        images: imagesPayload,
      }),
    });
  },

  updateItem: (id: string, body: {
    title?: string;
    description?: string;
    category?: string;
    priceNzd?: string | number;
    condition?: string;
    status?: string;
    city?: string;
    suburb?: string;
    imageUrl?: string;
    images?: Array<{ url: string; sortOrder?: number }>;
    isSustainable?: boolean;
  }) => {
    const payload: any = { ...body };
    if (body.city || body.suburb) {
      payload.location = {
        city: body.city || 'Auckland',
        suburb: body.suburb || '',
      };
    }
    if (body.priceNzd !== undefined) {
      payload.priceNzd = body.priceNzd;
    }
    return apiRequest<{ status: string; item: UsedItem }>(`/usedItems/${id}`, {
      method: 'PATCH',
      body: JSON.stringify(payload),
    });
  },

  deleteItem: (id: string) =>
    apiRequest<{ status: string; message: string }>(`/usedItems/${id}`, {
      method: 'DELETE',
    }),
};

// Admin Moderation & Stats APIs
export const adminApi = {
  getStats: () =>
    apiRequest<{ status: string; stats: AdminStats }>('/admin/stats'),

  getUsers: (params?: { search?: string; role?: string; status?: string }) => {
    const query = new URLSearchParams();
    if (params?.search) query.set('search', params.search);
    if (params?.role) query.set('role', params.role);
    if (params?.status) query.set('status', params.status);
    const qStr = query.toString();
    return apiRequest<{ status: string; count: number; users: UserProfile[] }>(`/admin/users${qStr ? `?${qStr}` : ''}`);
  },

  updateUserTrustScore: (
    id: string,
    body: {
      trustScore?: number;
      kiwiGold?: number;
      role?: 'user' | 'admin';
      isVerified?: boolean;
      displayName?: string;
      isStudentVerified?: boolean;
      studentInstitution?: string;
    }
  ) =>
    apiRequest<{ status: string; message: string; user: any }>(`/admin/users/${id}/trust-score`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),

  updateUserStatus: (id: string, body: { isBanned?: boolean; status?: string }) =>
    apiRequest<{ status: string; message: string; user: any }>(`/admin/users/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),

  getItems: (params?: { status?: string; search?: string }) => {
    const query = new URLSearchParams();
    if (params?.status) query.set('status', params.status);
    if (params?.search) query.set('search', params.search);
    const qStr = query.toString();
    return apiRequest<{ status: string; count: number; items: UsedItem[] }>(`/admin/items${qStr ? `?${qStr}` : ''}`);
  },

  updateItemStatus: (id: string, status: 'active' | 'revoked' | 'sold' | 'deleted') =>
    apiRequest<{ status: string; message: string; item: UsedItem }>(`/admin/items/${id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status }),
    }),

  reassignItem: (id: string, body: { targetUserEmail?: string; targetUserId?: string }) =>
    apiRequest<{ status: string; message: string; item: UsedItem }>(`/admin/items/${id}/assign`, {
      method: 'PATCH',
      body: JSON.stringify(body),
    }),
};

// Watchlist APIs
export const watchlistApi = {
  getWatchlist: (cursor?: string) => {
    const params = new URLSearchParams({ limit: '50' });
    if (cursor) params.set('cursor', cursor);
    return apiRequest<{
      status: string;
      count: number;
      items?: UsedItem[];
      data?: UsedItem[];
      pagination?: { hasMore: boolean; nextCursor: string | null };
    }>(`/watchlist?${params.toString()}`);
  },

  getWatchlistIds: () =>
    apiRequest<{ status: string; itemIds: string[] }>('/watchlist/ids'),

  checkWatch: (itemId: string) =>
    apiRequest<{ status: string; isWatched: boolean }>(`/watchlist/check/${itemId}`),

  addToWatchlist: (itemId: string) =>
    apiRequest<{ status: string; message: string }>(`/watchlist/${itemId}`, {
      method: 'POST',
    }),

  removeFromWatchlist: (itemId: string) =>
    apiRequest<{ status: string; message: string }>(`/watchlist/${itemId}`, {
      method: 'DELETE',
    }),

  getWatchlistCount: (itemId: string) =>
    apiRequest<{ status: string; itemId: string; count: number }>(`/watchlist/count/${itemId}`),
};

// Cloudflare R2 Image Upload APIs
export const uploadApi = {
  uploadImage: async (file: File) => {
    const base64 = await new Promise<string>((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
      reader.readAsDataURL(file);
    });

    return apiRequest<{
      status: string;
      message: string;
      url: string;
      key: string;
      bucket: string;
      storageEndpoint: string;
    }>('/upload', {
      method: 'POST',
      body: JSON.stringify({
        imageBase64: base64,
        fileName: file.name,
        contentType: file.type,
      }),
    });
  },

  getPresignedUrl: (fileName: string, contentType: string) =>
    apiRequest<{
      status: string;
      uploadUrl: string;
      publicUrl: string;
      key: string;
      bucket: string;
      endpoint: string;
    }>('/upload/presign', {
      method: 'POST',
      body: JSON.stringify({ fileName, contentType }),
    }),
};

// Chat & Conversation APIs
export const chatApi = {
  getConversations: () =>
    apiRequest<{ status: string; conversations: ConversationItem[] }>('/conversations'),

  startConversation: (itemId: string) =>
    apiRequest<{ status: string; conversation: ConversationItem }>('/conversations', {
      method: 'POST',
      body: JSON.stringify({ itemId }),
    }),

  getMessages: (conversationId: string, limit = 50, before?: string) => {
    const query = new URLSearchParams();
    if (limit) query.set('limit', String(limit));
    if (before) query.set('before', before);
    const qs = query.toString();
    return apiRequest<{
      status: string;
      messages: ChatMessage[];
      pagination: { hasMore: boolean; nextBefore: string | null };
    }>(`/conversations/${conversationId}/messages${qs ? `?${qs}` : ''}`);
  },

  sendMessage: (conversationId: string, body: { type?: 'text' | 'image'; text?: string; imageUrl?: string }) =>
    apiRequest<{ status: string; message: ChatMessage }>(`/conversations/${conversationId}/messages`, {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  markAsRead: (conversationId: string, throughMessageId?: string) =>
    apiRequest<{ status: string; readCount?: number }>(`/conversations/${conversationId}/read`, {
      method: 'PATCH',
      body: JSON.stringify(throughMessageId ? { throughMessageId } : {}),
    }),
};

// Orders APIs
export interface OrderItem {
  id: string;
  orderNumber: string;
  status: string;
  role: 'buying' | 'selling';
  itemId: string;
  isPaid?: boolean;
  buyerFeeAmountNzd?: string;
  buyerTotalAmountNzd?: string;
  refundedAt?: string | null;
  isRefunded?: boolean;
  item: {
    id: string;
    title: string;
    priceNzd: string;
    imageUrl: string;
    condition?: string;
    category?: string;
    status?: string;
  };
  counterparty: {
    id: string;
    displayName: string;
    avatarUrl: string | null;
    role: 'buyer' | 'seller';
  };
  meeting?: {
    scheduledAt: string;
    locationName: string;
    latitude: number | null;
    longitude: number | null;
    proposalStatus: string;
    note?: string;
  } | null;
  createdAt: string;
  updatedAt: string;
  completedAt?: string | null;
}

export const ordersApi = {
  getMyOrders: (params?: { type?: 'buying' | 'selling' | 'all'; status?: 'in_progress' | 'completed' | 'all' }) => {
    const query = new URLSearchParams();
    if (params?.type) query.set('type', params.type);
    if (params?.status) query.set('status', params.status);
    const qs = query.toString();
    return apiRequest<{ status: string; orders: OrderItem[] }>(`/orders/my${qs ? `?${qs}` : ''}`);
  },
  getOrderById: (orderId: string) =>
    apiRequest<{ status: string; order: OrderItem }>(`/orders/${orderId}`),
  getOrderByItemId: (itemId: string) =>
    apiRequest<{ status: string; order: OrderItem }>(`/orders/by-item/${itemId}`),
  createOrder: (itemId: string) =>
    apiRequest<{ status: string; order: OrderItem }>('/orders', {
      method: 'POST',
      body: JSON.stringify({ itemId }),
    }),
  refundOrder: (orderId: string, reason?: string) =>
    apiRequest<{ status: string; message: string; order: OrderItem }>(`/orders/${orderId}/refund`, {
      method: 'POST',
      body: JSON.stringify({ reason }),
    }),
};

export const paymentsApi = {
  createIntent: async (orderId: string) => {
    const response = await apiRequest<any>('/payments/create-intent', {
      method: 'POST',
      body: JSON.stringify({ orderId }),
    });

    if (response.isFree) {
      return {
        status: response.status as string,
        isFree: true,
        paymentIntentId: '',
        clientSecret: undefined,
        amountNzd: response.totalAmountNzd || '0.00',
        itemAmountNzd: '0.00',
        buyerFeeNzd: '0.00',
      };
    }

    const data = response.data || response;
    return {
      status: response.status as string,
      isFree: false,
      paymentIntentId: String(data.paymentIntentId || ''),
      clientSecret: data.clientSecret as string | undefined,
      amountNzd: (Number(data.amountCents || 0) / 100).toFixed(2),
      itemAmountNzd: (Number(data.itemAmountCents || 0) / 100).toFixed(2),
      buyerFeeNzd: (Number(data.buyerFeeCents || 0) / 100).toFixed(2),
    };
  },

  createPaymentMethod: (body: {
    cardNumber: string;
    expMonth: number;
    expYear: number;
    cvc: string;
  }) =>
    apiRequest<{ status: string; paymentMethodId: string }>('/payments/payment-methods', {
      method: 'POST',
      body: JSON.stringify(body),
    }),

  confirm: async (orderId: string, paymentIntentId: string, paymentMethodId?: string) => {
    const response = await apiRequest<any>('/payments/confirm', {
      method: 'POST',
      body: JSON.stringify({ orderId, paymentIntentId, paymentMethodId }),
    });
    return {
      status: response.status as string,
      data: response.data || response,
    };
  },
};

export const meetupsApi = {
  getMeetup: (orderId: string) =>
    apiRequest<{
      status: string;
      meetup: any;
      qrToken?: string | null;
      isUnlocked?: boolean;
    }>(`/meetups/${orderId}`),
  propose: (orderId: string, body: { scheduledAt: string; locationName: string; latitude?: number; longitude?: number; note?: string }) =>
    apiRequest<{ status: string; meetup: any }>(`/meetups/${orderId}/propose`, {
      method: 'POST',
      body: JSON.stringify(body),
    }),
  accept: (orderId: string) =>
    apiRequest<{ status: string; meetup: any }>(`/meetups/${orderId}/accept`, {
      method: 'POST',
      body: JSON.stringify({}),
    }),
  confirmHandover: (orderId: string, role: 'buyer' | 'seller') =>
    apiRequest<{ status: string; message: string; order: any }>(`/meetups/${orderId}/confirm-handover`, {
      method: 'POST',
      body: JSON.stringify({ role }),
    }),
};

export const aiApi = {
  getListingSuggestion: (input: {
    title?: string;
    description?: string;
    category?: string;
    condition?: string;
    location?: string;
  }) =>
    apiRequest<{
      status: string;
      suggestion: {
        title: string;
        description: string;
        category: string;
        condition: string;
        priceNzd?: string;
        tags?: string[];
      };
    }>('/listing-suggestions', {
      method: 'POST',
      body: JSON.stringify(input),
    }),
};


