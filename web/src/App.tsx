import React from 'react';
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { WatchlistProvider } from './context/WatchlistContext';
import { ChatProvider } from './context/ChatContext';
import { Navbar } from './components/Navbar';
import { Footer } from './components/Footer';
import { HomePage } from './pages/HomePage';
import { ProductDetailPage } from './pages/ProductDetailPage';
import { WatchlistPage } from './pages/WatchlistPage';
import { LoginPage } from './pages/LoginPage';
import { RegisterPage } from './pages/RegisterPage';
import { ProfilePage } from './pages/ProfilePage';
import { AdminDashboardPage } from './pages/AdminDashboardPage';
import { ChatPage } from './pages/ChatPage';
import { ShareLinkLandingPage } from './pages/ShareLinkLandingPage';
import './styles/index.css';

const AppContent: React.FC = () => {
  const location = useLocation();
  const isChatRoute = location.pathname.startsWith('/chat');
  const isShareLanding = location.pathname.startsWith('/s/');

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      {!isShareLanding && <Navbar />}
      <main style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/products/:id" element={<ProductDetailPage />} />
          <Route path="/s/:id" element={<ShareLinkLandingPage />} />
          <Route path="/watchlist" element={<WatchlistPage />} />
          <Route path="/chat" element={<ChatPage />} />
          <Route path="/chat/:conversationId" element={<ChatPage />} />
          <Route path="/chats" element={<ChatPage />} />
          <Route path="/chats/:conversationId" element={<ChatPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/profile" element={<ProfilePage />} />
          <Route path="/admin" element={<AdminDashboardPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </main>
      {!isChatRoute && !isShareLanding && <Footer />}
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <BrowserRouter>
      <AuthProvider>
        <WatchlistProvider>
          <ChatProvider>
            <AppContent />
          </ChatProvider>
        </WatchlistProvider>
      </AuthProvider>
    </BrowserRouter>
  );
};

export default App;
