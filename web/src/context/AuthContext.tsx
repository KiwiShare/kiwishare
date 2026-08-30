import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { UserProfile, authApi } from '../api/client';

interface AuthContextType {
  user: UserProfile | null;
  token: string | null;
  isLoggedIn: boolean;
  isLoading: boolean;
  login: (identifier: string, password?: string) => Promise<void>;
  loginWithOtp: (email: string, code: string, displayName?: string) => Promise<void>;
  loginWithPhone: (params: { idToken?: string; phone?: string; code?: string; displayName?: string }) => Promise<void>;
  register: (email: string, password: string, displayName: string) => Promise<void>;
  logout: () => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<UserProfile | null>(() => {
    const saved = localStorage.getItem('kiwishare_user');
    return saved ? JSON.parse(saved) : null;
  });
  const [token, setToken] = useState<string | null>(() => {
    return localStorage.getItem('kiwishare_token');
  });
  const [isLoading, setIsLoading] = useState<boolean>(true);

  const saveAuth = (newToken: string, newUser: UserProfile) => {
    setToken(newToken);
    setUser(newUser);
    localStorage.setItem('kiwishare_token', newToken);
    localStorage.setItem('kiwishare_user', JSON.stringify(newUser));
  };

  const clearAuth = React.useCallback(() => {
    setToken(null);
    setUser(null);
    localStorage.removeItem('kiwishare_token');
    localStorage.removeItem('kiwishare_user');
  }, []);

  const refreshUser = React.useCallback(async () => {
    if (!token) return;
    try {
      const res = await authApi.getMe();
      if (res.user) {
        setUser(res.user);
        localStorage.setItem('kiwishare_user', JSON.stringify(res.user));
      }
    } catch {
      // Token might be expired
      clearAuth();
    }
  }, [token, clearAuth]);

  useEffect(() => {
    if (token) {
      refreshUser().finally(() => setIsLoading(false));
    } else {
      setIsLoading(false);
    }
  }, [token, refreshUser]);

  const login = async (identifier: string, password?: string) => {
    const res = await authApi.login({ identifier, password, platform: 'web' });
    saveAuth(res.token, res.user);
  };

  const loginWithOtp = async (email: string, code: string, displayName?: string) => {
    const res = await authApi.verifyOtp({ email, code, displayName });
    saveAuth(res.token, res.user);
  };

  const loginWithPhone = async (params: { idToken?: string; phone?: string; code?: string; displayName?: string }) => {
    const res = await authApi.loginWithPhone(params);
    saveAuth(res.token, res.user);
  };

  const register = async (email: string, password: string, displayName: string) => {
    const res = await authApi.register({ email, password, displayName, platform: 'web' });
    saveAuth(res.token, res.user);
  };

  const logout = () => {
    clearAuth();
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isLoggedIn: !!token && !!user,
        isLoading,
        login,
        loginWithOtp,
        loginWithPhone,
        register,
        logout,
        refreshUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
