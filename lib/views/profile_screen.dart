import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_state.dart';
import 'login_view.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLoginBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFF), // Cream
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LoginView(
                  onLoginSuccess: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final isLoggedIn = appState.isLoggedIn;

    return Scaffold(
      backgroundColor: const Color(0xFFD9E6F8), // Sky Blue background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Title
              Text(
                'Profile',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2D5B),
                ),
              ),
              const SizedBox(height: 24),

              // Header Area - Mobile App Style
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFF), // Cream
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1F2D5B).withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: isLoggedIn && user != null
                    ? Row(
                        children: [
                          // Authenticated User Avatar
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundColor: const Color(0xFF3F6FD9), // Cobalt Blue
                                child: Text(
                                  user.displayName.substring(0, 1),
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (user.isVerified)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3E8E41), // Verified Green
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // User Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1F2D5B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2F0D9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Trust Score: ${user.trustScore}/100',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF3E8E41),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Logout button
                          IconButton(
                            icon: const Icon(Icons.logout, color: Color(0xFF6E7FBF)),
                            onPressed: () {
                              appState.logout();
                            },
                            tooltip: 'Log Out',
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Guest Avatar
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFF6E7FBF).withOpacity(0.15),
                            child: const Icon(
                              Icons.person_outline,
                              size: 40,
                              color: Color(0xFF6E7FBF),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Guest Welcome and Login Button
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kia ora, Guest!',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1F2D5B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton(
                                  onPressed: () => _showLoginBottomSheet(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3F6FD9), // Cobalt
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(120, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Log In / Register',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 32),

              // Settings Header
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(Icons.developer_board, color: Color(0xFF1F2D5B), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Core System Architecture',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2D5B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Client Side Direct Links Card
              _buildArchitectureCard(
                title: 'Client-Direct Operations (Flutter Direct)',
                subtitle: 'Optimized for high concurrency and low latency',
                color: const Color(0xFFE2F0D9), // Light Green
                borderColor: const Color(0xFFA2D091),
                items: [
                  _buildArchDetailItem(
                    icon: Icons.sync,
                    label: 'Firestore Streams',
                    description: 'Real-time syncing for product grids, user metadata, and chat lists directly to clients.',
                  ),
                  _buildArchDetailItem(
                    icon: Icons.cloud_upload_outlined,
                    label: 'Storage Uploads',
                    description: 'Direct multi-part uploads to Firebase Storage bypassing intermediate gateway servers.',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cloud Functions Card
              _buildArchitectureCard(
                title: 'Secure Serverless Node.js Backend',
                subtitle: 'Running on protected privileged Admin SDK envs',
                color: const Color(0xFFFBE4D8), // Light Orange
                borderColor: const Color(0xFFF2A385),
                items: [
                  _buildArchDetailItem(
                    icon: Icons.g_translate_outlined,
                    label: 'AI Moderation & Risk Control',
                    description: 'Evaluates listings for prohibited items using Google Cloud Functions without exposing secrets.',
                  ),
                  _buildArchDetailItem(
                    icon: Icons.qr_code_scanner,
                    label: 'QR Code Atomic Validation',
                    description: 'Atomic Firestore transaction routines validating handovers to prevent double-redeems.',
                  ),
                  _buildArchDetailItem(
                    icon: Icons.calculate_outlined,
                    label: 'Kiwi Trust Score Settlement',
                    description: 'Secured calculations utilizing Admin SDK triggers based on successful transactions.',
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchitectureCard({
    required String title,
    required String subtitle,
    required Color color,
    required Color borderColor,
    required List<Widget> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: const Color(0xFF1F2D5B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6E7FBF),
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(height: 20, color: Color(0xFF1F2D5B)),
          ...items,
        ],
      ),
    );
  }

  Widget _buildArchDetailItem({
    required IconData icon,
    required String label,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1F2D5B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: const Color(0xFF1F2D5B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF1F2D5B).withOpacity(0.85),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
