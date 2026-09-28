import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/r2_upload_service.dart';

import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/kiwigold_coin_icon.dart';
import '../../widgets/vip_crown_icon.dart';
import '../auth/login_view.dart';
import 'help_center_screen.dart';
import 'kiwigold_topup_sheet.dart';
import 'my_reports_screen.dart';
import 'payment_methods_screen.dart';
import 'report_screen.dart';
import 'notification_settings_screen.dart';
import 'user_listings_screen.dart';
import 'user_meetups_screen.dart';
import 'user_orders_screen.dart';
import 'settings_screen.dart';
import 'public_profile_screen.dart';
import '../support/support_chat_screen.dart';
import '../scanner/qr_scanner_screen.dart';
import '../../utils/trust_score.dart';
import 'student_verification_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _loadedToken;
  String? _refreshError;
  bool _avatarBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final token = context.watch<AuthProvider>().jwtToken;
    if (token != _loadedToken) {
      _loadedToken = token;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null) return;
    try {
      await auth.refreshProfile();
      if (mounted && auth.jwtToken == token) {
        setState(() => _refreshError = null);
      }
    } on UserAuthenticationException catch (error) {
      if (mounted && auth.jwtToken == token) {
        await auth.clearSession();
        if (mounted) {
          setState(() => _refreshError = error.message);
        }
      }
    } on UserNetworkException catch (error) {
      if (mounted && auth.jwtToken == token) {
        setState(() => _refreshError = error.message);
      }
    } on UserRepositoryException catch (error) {
      if (mounted && auth.jwtToken == token) {
        setState(() => _refreshError = error.message);
      }
    } catch (_) {
      if (mounted && auth.jwtToken == token) {
        setState(
          () =>
              _refreshError = 'Could not refresh profile. Showing saved data.',
        );
      }
    }
  }

  Future<void> _editAvatar() async {
    final auth = context.read<AuthProvider>();
    final token = auth.jwtToken;
    if (token == null || _avatarBusy) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photo library'),
              onTap: () => Navigator.pop(sheet, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Use default avatar'),
              onTap: () => Navigator.pop(sheet, 'default'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted || auth.jwtToken != token) return;
    setState(() => _avatarBusy = true);
    try {
      var url = '';
      if (choice == 'photo' || choice == 'camera') {
        final photo = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1024,
          imageQuality: 85,
        );
        if (photo == null) return;
        final bytes = await photo.readAsBytes();
        if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
          throw StateError('Choose a photo smaller than 5 MB.');
        }
        if (auth.jwtToken != token) return;
        url = await R2UploadService().uploadImage(
          bytes: bytes,
          fileName: photo.name,
          contentType:
              photo.mimeType ??
              (photo.name.toLowerCase().endsWith('.png')
                  ? 'image/png'
                  : 'image/jpeg'),
          authToken: token,
        );
      }
      if (auth.jwtToken != token) return;
      await auth.updateAvatar(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save photo. Choose an image under 5 MB and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _showLogin(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(16),
      child: LoginView(
        isSignUp: false,
        onLoginSuccess: () {
          if (sheetContext.mounted) {
            Navigator.pop(sheetContext);
          }
        },
      ),
    ),
  );

  Future<void> _showSignUp(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(16),
      child: LoginView(
        isSignUp: true,
        onLoginSuccess: () {
          if (sheetContext.mounted) {
            Navigator.pop(sheetContext);
          }
        },
      ),
    ),
  );

  Future<void> _showChangePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(
        onSave: ({required currentPassword, required newPassword}) =>
            context.read<AuthProvider>().changePassword(
              currentPassword: currentPassword,
              newPassword: newPassword,
            ),
      ),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
    }
  }

  Future<void> _showOtpSetPassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _OtpSetPasswordDialog(),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password set. You can now sign in with your email and password.',
          ),
        ),
      );
    }
  }

  Future<void> _editName(BuildContext context, UserModel user) async {
    final auth = context.read<AuthProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => _EditDisplayNameDialog(
        initialName: user.displayName,
        onSave: auth.updateDisplayName,
      ),
    );
  }

  Future<void> _showStudentVerification(BuildContext context) async {
    await showStudentVerificationSheet(context);
  }

  Future<void> _showVipManagementSheet(
    BuildContext context,
    UserModel user,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final expiresAt = user.vipExpiresAt;
    final dateStr = expiresAt != null
        ? _formatVipDate(expiresAt)
        : 'Next billing cycle';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          final currentUser = auth.currentUser ?? user;
          final isAutoRenew = currentUser.vipAutoRenew;
          final currentExpiresAt = currentUser.vipExpiresAt ?? expiresAt;
          final currentDateStr = currentExpiresAt != null
              ? _formatVipDate(currentExpiresAt)
              : dateStr;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181715) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFDF73), Color(0xFFC89328)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFC89328,
                            ).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const VipCrownIcon(
                        color: Color(0xFF382305),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KiwiGold VIP Membership',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isAutoRenew
                                  ? const Color(
                                      0xFF059669,
                                    ).withValues(alpha: 0.15)
                                  : const Color(
                                      0xFFD97706,
                                    ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAutoRenew
                                  ? 'ACTIVE · AUTO-RENEWS'
                                  : 'VIP ACTIVE · AUTO-RENEW OFF',
                              style: TextStyle(
                                color: isAutoRenew
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFD97706),
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF24221E)
                        : const Color(0xFFFBF8F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      _VipInfoRow(
                        label: 'Current Plan',
                        value: 'VIP Monthly (\$9.00 NZD/mo)',
                      ),
                      const SizedBox(height: 10),
                      _VipInfoRow(
                        label: 'Membership Access',
                        value: 'Valid until $currentDateStr',
                        valueColor: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 10),
                      _VipInfoRow(
                        label: 'Monthly Subscription',
                        value: isAutoRenew
                            ? 'Active (Auto-renews $currentDateStr)'
                            : 'Paused (No future charges)',
                        valueColor: isAutoRenew
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Included Perks',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const _VipPerkItem(
                  icon: Icons.rocket_launch_rounded,
                  title: 'Unlimited Listing Boosts',
                  desc:
                      'Boost any listing to top of feeds without spending coins',
                ),
                const SizedBox(height: 8),
                const _VipPerkItem(
                  customIcon: VipCrownIcon(size: 18),
                  title: 'KiwiGold VIP Badge',
                  desc: 'KiwiGold badge displayed on your profile and listings',
                ),
                const SizedBox(height: 8),
                const _VipPerkItem(
                  icon: Icons.trending_up_rounded,
                  title: 'Top Search Exposure',
                  desc: 'Higher ranking and visibility in marketplace searches',
                ),
                const SizedBox(height: 24),
                if (isAutoRenew)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            title: const Text('Cancel VIP Auto-Renewal?'),
                            content: Text(
                              'Your KiwiGold VIP benefits (unlimited boosts & golden badge) will remain fully active until $currentDateStr.\n\nYou will not be charged for next month.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogCtx, false),
                                child: const Text('Keep VIP'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                ),
                                onPressed: () => Navigator.pop(dialogCtx, true),
                                child: const Text('Confirm Cancellation'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          try {
                            await context
                                .read<AuthProvider>()
                                .cancelVipRenewal();
                            if (sheetCtx.mounted) {
                              Navigator.pop(sheetCtx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'VIP auto-renewal cancelled. You will continue to enjoy VIP perks until $currentDateStr.',
                                  ),
                                  backgroundColor: const Color(0xFF059669),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to cancel renewal: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text(
                        'Cancel Next Month\'s Renewal',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        try {
                          await context.read<AuthProvider>().resumeVipRenewal();
                          if (sheetCtx.mounted) {
                            Navigator.pop(sheetCtx);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'VIP auto-renewal resumed successfully! Your subscription will renew on $currentDateStr.',
                                ),
                                backgroundColor: const Color(0xFF059669),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to resume renewal: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Resume VIP Auto-Renewal',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final signedIn = auth.isLoggedIn && user != null;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final canChangePassword =
        user?.authProvider == null || user?.authProvider == 'email_password';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('profile-scan-qr-button'),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
            tooltip: 'Scan QR Code',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const QrScannerScreen()),
            ),
          ),
          IconButton(
            key: const Key('profile-support-button'),
            icon: const Icon(Icons.support_agent_rounded, size: 24),
            tooltip: 'Customer Support',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SupportChatScreen(),
              ),
            ),
          ),
          IconButton(
            key: const Key('profile-settings-button'),
            icon: const Icon(Icons.settings_outlined, size: 24),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            if (_refreshError != null)
              ListTile(
                title: Text(_refreshError!),
                trailing: IconButton(
                  tooltip: 'Retry',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            signedIn
                ? _ProfileHeader(
                    user: user,
                    onEdit: () => _editName(context, user),
                    onStudentTap: () => _showStudentVerification(context),
                  )
                : _GuestHeader(
                    onLogin: () => _showLogin(context),
                    onSignUp: () => _showSignUp(context),
                  ),
            const SizedBox(height: 14),
            if (!signedIn) ...[
              _KiwigoldVipBannerCard(
                user: null,
                onTap: () => _showLogin(context),
              ),
              const SizedBox(height: 14),
            ],
            if (signedIn) ...[
              _KiwigoldVipBannerCard(
                user: user,
                onTap: () {
                  if (user.isVip) {
                    _showVipManagementSheet(context, user);
                  } else {
                    KiwiGoldTopUpSheet.show(
                      context,
                      initialPlan: TopUpPlanType.vipMonthly,
                    );
                  }
                },
              ),
              const SizedBox(height: 14),
              _MarketplaceCard(
                onWatchlistTap: () => context.go('/watchlist'),
                onSellingTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const UserListingsScreen(
                      mode: UserListingsMode.selling,
                    ),
                  ),
                ),
                onOrdersTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const UserOrdersScreen(),
                  ),
                ),
                onSoldTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const UserListingsScreen(mode: UserListingsMode.sold),
                  ),
                ),
                onMeetupsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const UserMeetupsScreen(),
                  ),
                ),
                onPaymentTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PaymentMethodsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const _SectionHeader(title: 'Preferences'),
            _SoftMenuContainer(
              children: [
                _ModernMenuTile(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Appearance',
                  subtitle: _themeLabel(
                    context.watch<ThemeProvider>().themeMode,
                  ),
                  onTap: () => _showAppearance(context),
                ),
                if (signedIn)
                  _ModernMenuTile(
                    icon: Icons.notifications_active_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Notifications',
                    subtitle: 'System permission and notification access',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (signedIn) ...[
              const _SectionHeader(title: 'Account & security'),
              _SoftMenuContainer(
                children: [
                  _ModernMenuTile(
                    icon: Icons.portrait_rounded,
                    iconColor: const Color(0xFFF43F5E),
                    title: _avatarBusy ? 'Saving photo...' : 'Profile photo',
                    subtitle: 'Photo and avatar',
                    onTap: _editAvatar,
                  ),
                  _ModernMenuTile(
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF14B8A6),
                    title: 'Username',
                    subtitle: user.displayName,
                    onTap: () => _editName(context, user),
                  ),
                  _ModernMenuTile(
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF0EA5E9),
                    title: 'Change password',
                    subtitle: canChangePassword
                        ? 'Update your password'
                        : 'Set a password using an email code',
                    onTap: canChangePassword
                        ? () => _showChangePassword(context)
                        : () => _showOtpSetPassword(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const _SectionHeader(title: 'Safety & support'),
            _SoftMenuContainer(
              children: [
                _ModernMenuTile(
                  icon: Icons.explore_outlined,
                  iconColor: const Color(0xFF059669),
                  title: 'How KiwiShare works',
                  subtitle:
                      '5-step guide to trading & supporting circular economy',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const HelpCenterScreen(initialTabIndex: 0),
                    ),
                  ),
                ),
                _ModernMenuTile(
                  icon: Icons.quiz_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Help center & FAQs',
                  subtitle:
                      'Answers to meetups, QR, KiwiGold, and safety questions',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const HelpCenterScreen(initialTabIndex: 1),
                    ),
                  ),
                ),
                _ModernMenuTile(
                  icon: Icons.shield_outlined,
                  iconColor: const Color(0xFF6366F1),
                  title: 'My reports',
                  subtitle: 'View your report history and review status',
                  onTap: signedIn
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const MyReportsScreen(),
                          ),
                        )
                      : () => _showLogin(context),
                ),
                _ModernMenuTile(
                  icon: Icons.verified_user_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Report a safety issue',
                  subtitle: 'Tell us about unsafe or suspicious behaviour',
                  onTap: signedIn
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const ReportScreen(),
                          ),
                        )
                      : () => _showLogin(context),
                ),
              ],
            ),
            if (signedIn) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: auth.logout,
                icon: Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: colors.error.withValues(alpha: 0.85),
                ),
                label: Text(
                  'Log out',
                  style: TextStyle(
                    color: colors.error.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: isDark
                      ? colors.error.withValues(alpha: 0.08)
                      : colors.error.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Use device setting',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  Future<void> _showAppearance(BuildContext context) async {
    final provider = context.read<ThemeProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values
                .map(
                  (mode) => RadioListTile<ThemeMode>(
                    value: mode,
                    groupValue: provider.themeMode,
                    title: Text(_themeLabel(mode)),
                    onChanged: (value) async {
                      if (value == null) return;
                      await provider.setThemeMode(value);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onEdit,
    this.onStudentTap,
  });
  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback? onStudentTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final initial = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim()[0].toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top User Info Row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                key: const Key('profile_header_avatar_button'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PublicProfileScreen(userId: user.id),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: user.isVip
                              ? const Color(0xFFFFD700)
                              : scheme.primary.withValues(alpha: 0.15),
                          width: user.isVip ? 3 : 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: scheme.primaryContainer,
                        foregroundImage:
                            user.avatarUrl == null || user.avatarUrl!.isEmpty
                            ? null
                            : NetworkImage(user.avatarUrl!),
                        onForegroundImageError:
                            user.avatarUrl == null || user.avatarUrl!.isEmpty
                            ? null
                            : (_, _) {},
                        child: Text(
                          initial,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (user.isVerified)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF101B17)
                                : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.displayName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isVip) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                VipCrownIcon(size: 12),
                                SizedBox(width: 3),
                                Text(
                                  'VIP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              showKiwiTrustScoreSheet(context, user.trustScore),
                          child: Semantics(
                            label:
                                'Trust score ${formatPublicTrustScore(user.trustScore)}',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [
                                          const Color(0xFF0F3D31),
                                          const Color(0xFF0A5941),
                                        ]
                                      : [
                                          const Color(0xFFE8F5EE),
                                          const Color(0xFFD3EEDF),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user_rounded,
                                    size: 12,
                                    color: isDark
                                        ? const Color(0xFF92D4B3)
                                        : const Color(0xFF064B3A),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Trust score ${formatPublicTrustScore(user.trustScore)}',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFFD6F6E3)
                                          : const Color(0xFF064B3A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              showKiwiTrustScoreSheet(context, user.trustScore),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? getTrustScoreInfo(user.trustScore).darkBg
                                  : getTrustScoreInfo(user.trustScore).lightBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color:
                                    (isDark
                                            ? getTrustScoreInfo(
                                                user.trustScore,
                                              ).darkColor
                                            : getTrustScoreInfo(
                                                user.trustScore,
                                              ).lightColor)
                                        .withOpacity(0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              getTrustScoreInfo(user.trustScore).label,
                              style: TextStyle(
                                color: isDark
                                    ? getTrustScoreInfo(
                                        user.trustScore,
                                      ).darkColor
                                    : getTrustScoreInfo(
                                        user.trustScore,
                                      ).lightColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        if (user.isStudentVerified)
                          GestureDetector(
                            onTap: onStudentTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(
                                        0xFF1E3A8A,
                                      ).withValues(alpha: 0.5)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFBFDBFE),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.school_rounded,
                                    size: 12,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Student',
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF93C5FD)
                                          : const Color(0xFF1E40AF),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      key: const Key('profile_view_public_page_chip'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PublicProfileScreen(userId: user.id),
                          ),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'My Public Profile',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 9,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: isDark
                    ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
                    : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Bottom Wallet & Balance Shelf ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF221F1B) : const Color(0xFFFBF8F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFFB45309).withValues(alpha: 0.25)
                    : const Color(0xFFFDE68A),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const KiwiGoldCoinIcon(size: 18),
                const SizedBox(width: 8),
                Text(
                  '${user.kiwiGold} KiwiGold',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFF92400E),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => KiwiGoldTopUpSheet.show(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_circle,
                          size: 14,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Top Up',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFB45309),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.onOrdersTap,
    required this.onWatchlistTap,
    required this.onSellingTap,
    required this.onSoldTap,
    required this.onMeetupsTap,
    required this.onPaymentTap,
  });

  final VoidCallback onOrdersTap;
  final VoidCallback onWatchlistTap;
  final VoidCallback onSellingTap;
  final VoidCallback onSoldTap;
  final VoidCallback onMeetupsTap;
  final VoidCallback onPaymentTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 14),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 15,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'My marketplace',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _MarketplaceGridAction(
                  icon: Icons.receipt_long_rounded,
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  label: 'Orders',
                  sublabel: 'Buying & Selling',
                  onTap: onOrdersTap,
                ),
              ),
              Expanded(
                child: _MarketplaceGridAction(
                  icon: Icons.qr_code_2_rounded,
                  iconBg: const Color(0xFFFDF2F8),
                  iconColor: const Color(0xFFDB2777),
                  label: 'Meetups',
                  sublabel: 'QR & Schedules',
                  onTap: onMeetupsTap,
                ),
              ),
              Expanded(
                child: _MarketplaceGridAction(
                  icon: Icons.favorite_border,
                  iconBg: const Color(0xFFFEE2E2),
                  iconColor: const Color(0xFFDC2626),
                  label: 'Watchlist',
                  sublabel: 'Saved items',
                  onTap: onWatchlistTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MarketplaceGridAction(
                  icon: Icons.sell_rounded,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF059669),
                  label: 'Listings',
                  sublabel: 'Active listings',
                  onTap: onSellingTap,
                ),
              ),
              Expanded(
                child: _MarketplaceGridAction(
                  icon: Icons.inventory_2_rounded,
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF9333EA),
                  label: 'Sold',
                  sublabel: 'Sold history',
                  onTap: onSoldTap,
                ),
              ),
              Expanded(
                child: _MarketplaceGridAction(
                  icon: Icons.account_balance_wallet_rounded,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  label: 'Wallet',
                  sublabel: 'Cards & Payout',
                  onTap: onPaymentTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarketplaceGridAction extends StatelessWidget {
  const _MarketplaceGridAction({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isDark ? iconColor.withValues(alpha: 0.9) : iconColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestHeader extends StatelessWidget {
  const _GuestHeader({required this.onLogin, required this.onSignUp});
  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 28,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kia ora!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Log in to explore and manage trades',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onLogin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Log in',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSignUp,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Create account',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 15,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftMenuContainer extends StatelessWidget {
  const _SoftMenuContainer({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceContainerLow : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 56, right: 16),
                child: Divider(
                  height: 1,
                  thickness: 0.6,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ModernMenuTile extends StatelessWidget {
  const _ModernMenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? iconColor.withValues(alpha: 0.15)
                      : iconColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDark ? iconColor.withValues(alpha: 0.95) : iconColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditDisplayNameDialog extends StatefulWidget {
  const _EditDisplayNameDialog({
    required this.initialName,
    required this.onSave,
  });

  final String initialName;
  final Future<void> Function(String name) onSave;

  @override
  State<_EditDisplayNameDialog> createState() => _EditDisplayNameDialogState();
}

class _EditDisplayNameDialogState extends State<_EditDisplayNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  String? _failure;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = 'Could not save your name. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit username'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Username',
            errorText: _failure,
          ),
          validator: (value) {
            final length = value?.trim().length ?? 0;
            return length < 2 ? 'Enter at least 2 characters.' : null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.onSave});
  final Future<void> Function({
    required String currentPassword,
    required String newPassword,
  })
  onSave;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  String? _failure;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change password'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _current,
            obscureText: !_showCurrent,
            decoration: InputDecoration(
              labelText: 'Current password',
              suffixIcon: IconButton(
                tooltip: _showCurrent
                    ? 'Hide current password'
                    : 'Show current password',
                icon: Icon(
                  _showCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: _saving
                    ? null
                    : () => setState(() => _showCurrent = !_showCurrent),
              ),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter your current password.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _next,
            obscureText: !_showNext,
            decoration: InputDecoration(
              labelText: 'New password',
              suffixIcon: IconButton(
                tooltip: _showNext ? 'Hide new password' : 'Show new password',
                icon: Icon(
                  _showNext
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: _saving
                    ? null
                    : () => setState(() => _showNext = !_showNext),
              ),
            ),
            validator: (v) =>
                v == null || v.length < 8 ? 'Use at least 8 characters.' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirm,
            obscureText: !_showConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              suffixIcon: IconButton(
                tooltip: _showConfirm
                    ? 'Hide password confirmation'
                    : 'Show password confirmation',
                icon: Icon(
                  _showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: _saving
                    ? null
                    : () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
            validator: (v) =>
                v != _next.text ? 'Passwords do not match.' : null,
          ),
          if (_failure != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: _saving ? const Text('Saving...') : const Text('Save'),
      ),
    ],
  );
}

class _KiwigoldVipBannerCard extends StatelessWidget {
  const _KiwigoldVipBannerCard({this.user, required this.onTap});

  final UserModel? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVip = user?.isVip ?? false;
    final isAutoRenew = user?.vipAutoRenew ?? true;
    final expiresAt = user?.vipExpiresAt;
    final dateStr = expiresAt != null ? _formatVipDate(expiresAt) : null;

    final String badgeText;
    final now = DateTime.now();
    final daysRemaining = expiresAt != null
        ? expiresAt.difference(now).inDays
        : 999;
    if (!isVip) {
      badgeText = 'MEMBER';
    } else if (isAutoRenew) {
      badgeText = 'ACTIVE';
    } else if (daysRemaining <= 3 && daysRemaining >= 0) {
      badgeText = 'EXPIRING';
    } else {
      badgeText = 'ACTIVE';
    }

    final String subtitleText;
    if (!isVip) {
      subtitleText = 'Unlimited boosts · Top exposure · \$9/mo';
    } else if (isAutoRenew) {
      subtitleText = dateStr != null
          ? 'Unlimited boosts active · Renews $dateStr'
          : 'Unlimited boosts active';
    } else {
      subtitleText = dateStr != null
          ? 'Perks active until $dateStr · Auto-renew off'
          : 'Perks active · Auto-renew off';
    }

    final String actionText = isVip ? 'Manage' : 'Get VIP';

    return Container(
      decoration: BoxDecoration(
        // Xianyu VIP luxury aesthetic: deep charcoal & dark gold gradient
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1D1A), Color(0xFF2B2319), Color(0xFF382C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC89328).withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFDF73), Color(0xFFC89328)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC89328).withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: VipCrownIcon(color: Color(0xFF382305), size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'KiwiGold VIP',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFDE68A),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: (!isVip || isAutoRenew)
                                    ? const [
                                        Color(0xFFF59E0B),
                                        Color(0xFFD97706),
                                      ]
                                    : const [
                                        Color(0xFFDC2626),
                                        Color(0xFFB91C1C),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: const Color(
                            0xFFF5E6C8,
                          ).withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: isVip
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFFFE082), Color(0xFFE5A93C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: isVip
                        ? const Color(0xFF42341F).withValues(alpha: 0.9)
                        : null,
                    borderRadius: BorderRadius.circular(18),
                    border: isVip
                        ? Border.all(
                            color: const Color(
                              0xFFE5A93C,
                            ).withValues(alpha: 0.6),
                            width: 1,
                          )
                        : null,
                    boxShadow: isVip
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(
                                0xFFE5A93C,
                              ).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isVip
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF382305),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 15,
                        color: isVip
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF382305),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatVipDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

class _VipInfoRow extends StatelessWidget {
  const _VipInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _VipPerkItem extends StatelessWidget {
  const _VipPerkItem({
    this.icon,
    this.customIcon,
    required this.title,
    required this.desc,
  }) : assert(icon != null || customIcon != null);

  final IconData? icon;
  final Widget? customIcon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(
              0xFFD4AF37,
            ).withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              customIcon ??
              Icon(icon!, size: 18, color: const Color(0xFFD4AF37)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OtpSetPasswordDialog extends StatefulWidget {
  const _OtpSetPasswordDialog();

  @override
  State<_OtpSetPasswordDialog> createState() => _OtpSetPasswordDialogState();
}

class _OtpSetPasswordDialogState extends State<_OtpSetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _sending = false;
  bool _saving = false;
  bool _showPassword = false;
  String? _failure;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _failure = null;
    });
    try {
      final email = _email.text.trim();
      if (!email.contains('@')) {
        setState(() => _failure = 'Enter a valid email address.');
        return;
      }
      await context.read<AuthProvider>().requestPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reset code sent. If email delivery is not configured, read the code from the server log.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await context.read<AuthProvider>().resetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _next.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Set a password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We will send a verification code to the email below.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Account email',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || !v.contains('@')
                  ? 'Enter a valid email address.'
                  : null,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter the code.'
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton(
                    onPressed: _sending ? null : _sendCode,
                    child: Text(_sending ? 'Sending…' : 'Send code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _next,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'New password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              validator: (v) => v == null || v.length < 8
                  ? 'Use at least 8 characters.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: !_showPassword,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v != _next.text ? 'Passwords do not match.' : null,
            ),
            if (_failure != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_failure!, style: TextStyle(color: colors.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
