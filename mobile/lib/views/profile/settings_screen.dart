import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/watchlist_provider.dart';
import '../../services/notification_permission_coordinator.dart';
import '../../services/r2_upload_service.dart';
import 'help_center_screen.dart';
import 'notification_settings_screen.dart';
import 'student_verification_sheet.dart';
import 'student_verification_benefits_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _chatPushEnabled = true;
  bool _soundEnabled = true;
  bool _isLoadingPrefs = true;
  bool _avatarBusy = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<WatchlistProvider?>()?.loadNotificationPreference();
        } catch (_) {}
      }
    });
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _chatPushEnabled =
              prefs.getBool('chat_push_notifications_enabled') ?? true;
          _soundEnabled = prefs.getBool('chat_sound_enabled') ?? true;
          _isLoadingPrefs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPrefs = false);
      }
    }
  }

  Future<void> _setChatPushEnabled(bool value) async {
    setState(() => _chatPushEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat_push_notifications_enabled', value);
      if (value && mounted) {
        // Offer system permissions if turning on
        await offerContextualNotificationPermission(context);
      }
    } catch (_) {}
  }

  Future<void> _setSoundEnabled(bool value) async {
    setState(() => _soundEnabled = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat_sound_enabled', value);
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will clear locally cached images and temporary data. Your account information and messages will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Temporary cache cleared successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showThemeSelector() {
    final themeProvider = context.read<ThemeProvider>();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Choose Theme',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.brightness_auto_outlined),
                  title: const Text('System Default'),
                  trailing: themeProvider.themeMode == ThemeMode.system
                      ? const Icon(Icons.check, color: Color(0xFF059669))
                      : null,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.system);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.light_mode_outlined),
                  title: const Text('Light'),
                  trailing: themeProvider.themeMode == ThemeMode.light
                      ? const Icon(Icons.check, color: Color(0xFF059669))
                      : null,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.light);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Dark'),
                  trailing: themeProvider.themeMode == ThemeMode.dark
                      ? const Icon(Icons.check, color: Color(0xFF059669))
                      : null,
                  onTap: () {
                    themeProvider.setThemeMode(ThemeMode.dark);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of KiwiShare?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have been signed out.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final signedIn = auth.isLoggedIn && user != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentThemeMode = context.watch<ThemeProvider>().themeMode;

    final themeLabel = switch (currentThemeMode) {
      ThemeMode.system => 'System Default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (signedIn) ...[
            _buildSectionHeader('Account & Security'),
            _buildCard(
              isDark: isDark,
              children: [
                _buildListTile(
                  icon: Icons.portrait_rounded,
                  title: _avatarBusy ? 'Saving photo...' : 'Profile Photo',
                  subtitle: 'Photo and avatar',
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _avatarBusy ? null : _editAvatar,
                ),
                _buildDivider(),
                _buildListTile(
                  icon: Icons.badge_outlined,
                  title: 'Username',
                  subtitle: user.username?.trim().isNotEmpty == true
                      ? user.username!.trim()
                      : user.displayName,
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _editUsername(context, user),
                ),
                _buildDivider(),
                _buildListTile(
                  icon: Icons.school_outlined,
                  title: 'Student Verification',
                  subtitle: user.isStudentVerified
                      ? 'Verified · View benefits'
                      : 'Unverified · Verify to get 100 KiwiGold',
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => user.isStudentVerified
                      ? showStudentVerificationBenefitsSheet(context, user)
                      : showStudentVerificationSheet(context),
                ),
                if (user.authProvider == null ||
                    user.authProvider == 'email_password') ...[
                  _buildDivider(),
                  _buildListTile(
                    icon: Icons.lock_outline,
                    title: 'Change Password',
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _changePasswordDialog(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
          ],

          _buildSectionHeader('Notifications'),
          _buildCard(
            isDark: isDark,
            children: [
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.chat_bubble_outline),
                title: const Text(
                  'Message Push Notifications',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Receive instant alerts when buyers or sellers message you',
                  style: TextStyle(fontSize: 12),
                ),
                value: _chatPushEnabled,
                activeColor: const Color(0xFF059669),
                onChanged: _isLoadingPrefs ? null : _setChatPushEnabled,
              ),
              _buildDivider(),
              SwitchListTile.adaptive(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text(
                  'In-App Sound & Vibration',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: const Text(
                  'Play alert sounds when receiving messages',
                  style: TextStyle(fontSize: 12),
                ),
                value: _soundEnabled,
                activeColor: const Color(0xFF059669),
                onChanged: _isLoadingPrefs ? null : _setSoundEnabled,
              ),
              Builder(
                builder: (context) {
                  WatchlistProvider? watchlist;
                  try {
                    watchlist = Provider.of<WatchlistProvider>(context);
                  } catch (_) {
                    watchlist = null;
                  }
                  final priceDropsEnabled =
                      watchlist?.watchlistPriceDropEnabled ?? true;
                  final priceIncreasesEnabled =
                      watchlist?.watchlistPriceIncreaseEnabled ?? false;
                  final isUpdating = watchlist?.isUpdatingPreference ?? false;

                  Future<void> updatePriceAlert({
                    required bool enabled,
                    required bool increase,
                  }) async {
                    if (watchlist == null) return;
                    final success = increase
                        ? await watchlist.updatePriceIncreasePreference(enabled)
                        : await watchlist.updatePriceDropPreference(enabled);
                    if (!context.mounted || success) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          increase
                              ? 'Could not update price increase alerts. Please try again.'
                              : 'Could not update price drop alerts. Please try again.',
                        ),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDivider(),
                      SwitchListTile.adaptive(
                        key: const Key(
                          'settings-watchlist-price-drop-alerts-switch',
                        ),
                        secondary: const Icon(Icons.trending_down_rounded),
                        title: const Text(
                          'Price Drop Alerts',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Notify me when a saved item gets cheaper',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: priceDropsEnabled,
                        activeColor: const Color(0xFF059669),
                        onChanged: isUpdating || watchlist == null
                            ? null
                            : (val) => updatePriceAlert(
                                enabled: val,
                                increase: false,
                              ),
                      ),
                      _buildDivider(),
                      SwitchListTile.adaptive(
                        key: const Key(
                          'settings-watchlist-price-increase-alerts-switch',
                        ),
                        secondary: const Icon(Icons.trending_up_rounded),
                        title: const Text(
                          'Price Increase Alerts',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: const Text(
                          'Notify me when a saved item becomes more expensive',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: priceIncreasesEnabled,
                        activeColor: const Color(0xFF059669),
                        onChanged: isUpdating || watchlist == null
                            ? null
                            : (val) => updatePriceAlert(
                                enabled: val,
                                increase: true,
                              ),
                      ),
                    ],
                  );
                },
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.phonelink_setup_outlined,
                title: 'System Notification Permissions',
                subtitle: 'Manage iOS / Android app permission settings',
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildSectionHeader('Preferences & Storage'),
          _buildCard(
            isDark: isDark,
            children: [
              _buildListTile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: themeLabel,
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _showThemeSelector,
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear Image Cache',
                subtitle: 'Free up local device space',
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: _clearCache,
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildSectionHeader('About & Support'),
          _buildCard(
            isDark: isDark,
            children: [
              _buildListTile(
                icon: Icons.help_outline,
                title: 'Help center',
                subtitle: 'Safety tips, guidelines & FAQ',
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const HelpCenterScreen(),
                  ),
                ),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.info_outline,
                title: 'About KiwiShare',
                subtitle: 'Version 1.0.0 (New Zealand)',
                trailing: const Text(
                  'v1.0.0',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showStaticContent(
                  context,
                  'Privacy Policy',
                  'KiwiShare respects your privacy and complies with the New Zealand Privacy Act 2020. Your information is securely encrypted and never sold to third parties.',
                ),
              ),
              _buildDivider(),
              _buildListTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _showStaticContent(
                  context,
                  'Terms of Service',
                  'By using KiwiShare, you agree to trade respectfully within the New Zealand community. Prohibited items, fraud, and harassment are strictly disallowed.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (signedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleSignOut,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: isDark ? const Color(0xFF1E2621) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16);
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

  Future<void> _editUsername(BuildContext context, UserModel user) async {
    final controller = TextEditingController(
      text: user.username?.trim().isNotEmpty == true
          ? user.username!.trim()
          : user.displayName.trim(),
    );
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Username'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'samyao',
            ),
            validator: (value) {
              final username = value?.trim() ?? '';
              if (!RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(username)) {
                return 'Use 3-24 letters, numbers, or underscores.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true && mounted) {
      try {
        await context.read<AuthProvider>().updateUsername(
          controller.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username updated successfully.')),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update username: $err')),
          );
        }
      }
    }
    controller.dispose();
  }

  Future<void> _changePasswordDialog(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New Password'),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                  validator: (v) {
                    if (v != newController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (updated == true && mounted) {
      try {
        await context.read<AuthProvider>().changePassword(
          currentPassword: currentController.text,
          newPassword: newController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed successfully.')),
          );
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to change password: $err')),
          );
        }
      }
    }
  }

  void _showStaticContent(BuildContext context, String title, String content) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
