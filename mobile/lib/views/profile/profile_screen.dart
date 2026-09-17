import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/r2_upload_service.dart';

import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../../repositories/user_repository.dart';
import '../auth/login_view.dart';
import 'my_reports_screen.dart';
import 'report_screen.dart';
import 'notification_settings_screen.dart';
import 'user_listings_screen.dart';
import 'user_meetups_screen.dart';
import '../scanner/qr_scanner_screen.dart';

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
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose profile photo'),
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
      if (choice == 'photo') {
        final photo = await ImagePicker().pickImage(
          source: ImageSource.gallery,
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
      backgroundColor: isDark
          ? const Color(0xFF0C1310)
          : const Color(0xFFF7F8F6),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceContainerHighest.withValues(alpha: 0.3)
                  : colors.surface,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: IconButton(
              key: const Key('profile-scan-qr-button'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Scan QR Code',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const QrScannerScreen(),
                ),
              ),
            ),
          ),
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
                  )
                : _GuestHeader(
                    onLogin: () => _showLogin(context),
                    onSignUp: () => _showSignUp(context),
                  ),
            const SizedBox(height: 16),
            if (signedIn) ...[
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
              ),
              const SizedBox(height: 16),
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
                    icon: Icons.add_a_photo_outlined,
                    iconColor: colors.primary,
                    title: _avatarBusy ? 'Saving photo...' : 'Profile photo',
                    subtitle: 'Photo and avatar',
                    onTap: _editAvatar,
                  ),
                  _ModernMenuTile(
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF14B8A6),
                    title: 'Nickname',
                    subtitle: user.displayName,
                    onTap: () => _editName(context, user),
                  ),
                  _ModernMenuTile(
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF0EA5E9),
                    title: 'Change password',
                    subtitle: canChangePassword
                        ? 'Update your password'
                        : 'Managed by your sign-in provider',
                    onTap: canChangePassword
                        ? () => _showChangePassword(context)
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password changes are unavailable for this account. Use your sign-in provider instead.',
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            const _SectionHeader(title: 'Safety & support'),
            _SoftMenuContainer(
              children: [
                _ModernMenuTile(
                  icon: Icons.history_rounded,
                  iconColor: colors.primary,
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
  const _ProfileHeader({required this.user, required this.onEdit});
  final UserModel user;
  final VoidCallback onEdit;

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
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.15),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 34,
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
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      label: 'Trust score ${user.trustScore} out of 100',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
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
                              size: 13,
                              color: isDark
                                  ? const Color(0xFF92D4B3)
                                  : const Color(0xFF064B3A),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Trust score ${user.trustScore}/100',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFD6F6E3)
                                    : const Color(0xFF064B3A),
                                fontWeight: FontWeight.w700,
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
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
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

class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.onWatchlistTap,
    required this.onSellingTap,
    required this.onSoldTap,
    required this.onMeetupsTap,
  });

  final VoidCallback onWatchlistTap;
  final VoidCallback onSellingTap;
  final VoidCallback onSoldTap;
  final VoidCallback onMeetupsTap;

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
                  icon: Icons.favorite_border,
                  iconBg: const Color(0xFFFDF2F8),
                  iconColor: const Color(0xFFDB2777),
                  label: 'Watchlist',
                  sublabel: 'Saved items',
                  onTap: onWatchlistTap,
                ),
              ),
              Expanded(
                child: _MarketplaceGridAction(
                  icon: Icons.sell_rounded,
                  iconBg: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF059669),
                  label: 'Selling',
                  sublabel: 'Active listings',
                  onTap: onSellingTap,
                ),
              ),
              Expanded(
                child: _MarketplaceGridAction(
                  icon: Icons.inventory_2_rounded,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF2563EB),
                  label: 'Sold',
                  sublabel: 'Sold history',
                  onTap: onSoldTap,
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
      title: const Text('Edit nickname'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nickname',
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
