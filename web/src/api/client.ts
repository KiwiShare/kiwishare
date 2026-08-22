export interface UserProfile {
  id: string;
  _id?: string;
  email: string;
  displayName: string;
  avatarUrl?: string | null;
  role?: 'admin' | 'user';
  trustScore: number;
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
  viewCount?: number;
  createdAt?: string;
}

export interface AuthResponse {
  status: string;
  token: string;
  user: UserProfile;
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
}

const API_BASE = '/api';

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

  const url = endpoint.startsWith('http') ? endpoint : `${API_BASE}${endpoint.startsWith('/') ? '' : '/'}${endpoint}`;

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

  getMe: () =>
    apiRequest<{ status: string; user: UserProfile }>('/users/me'),
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

  updateUserTrustScore: (id: string, body: { trustScore?: number; isStudentVerified?: boolean; studentInstitution?: string }) =>
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
};

// Watchlist APIs
export const watchlistApi = {
  getWatchlist: () =>
    apiRequest<{ status: string; count: number; items: UsedItem[] }>('/watchlist'),

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

