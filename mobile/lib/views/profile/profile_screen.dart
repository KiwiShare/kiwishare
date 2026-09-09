import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/providers.dart';
import '../auth/login_view.dart';
import 'report_screen.dart';
import 'notification_settings_screen.dart';
import 'user_listings_screen.dart';
import 'user_meetups_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

  Future<void> _editName(BuildContext context, UserModel user) async {
    final controller = TextEditingController(text: user.displayName);
    final formKey = GlobalKey<FormState>();
    final auth = context.read<AuthProvider>();
    String? failure;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit display name'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Display name',
                errorText: failure,
              ),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                return length < 2 ? 'Enter at least 2 characters.' : null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await auth.updateDisplayName(controller.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (_) {
                  setDialogState(
                    () => failure = 'Could not save your name. Try again.',
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final signedIn = auth.isLoggedIn && user != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          signedIn
              ? _ProfileHeader(
                  user: user,
                  onEdit: () => _editName(context, user),
                )
              : _GuestHeader(
                  onLogin: () => _showLogin(context),
                  onSignUp: () => _showSignUp(context),
                ),
          const SizedBox(height: 24),
          if (signedIn) ...[
            const _SectionTitle('My marketplace'),
            _MenuCard(
              children: [
                _MenuTile(
                  icon: Icons.sell_outlined,
                  title: 'Selling',
                  subtitle: 'Active and reserved listings',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const UserListingsScreen(
                        mode: UserListingsMode.selling,
                      ),
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Sold',
                  subtitle: 'Items you have already sold',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const UserListingsScreen(mode: UserListingsMode.sold),
                    ),
                  ),
                ),
                _MenuTile(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Meetups & QR Codes',
                  subtitle: 'Confirmed schedule and transaction QR codes',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const UserMeetupsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
          const _SectionTitle('Preferences'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.brightness_6_outlined,
                title: 'Appearance',
                subtitle: _themeLabel(context.watch<ThemeProvider>().themeMode),
                onTap: () => _showAppearance(context),
              ),
              if (signedIn)
                _MenuTile(
                  icon: Icons.notifications_outlined,
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
          const SizedBox(height: 24),
          const _SectionTitle('Safety & support'),
          _MenuCard(
            children: [
              _MenuTile(
                icon: Icons.shield_outlined,
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
            OutlinedButton.icon(
              onPressed: auth.logout,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final initial = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim()[0].toUpperCase();
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: scheme.primaryContainer,
                  foregroundImage: user.avatarUrl == null
                      ? null
                      : NetworkImage(user.avatarUrl!),
                  child: Text(
                    initial,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (user.isVerified)
                  Icon(Icons.verified, color: scheme.primary, size: 24),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kia ora, ${user.displayName}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: 'Trust score ${user.trustScore} out of 100',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Trust score ${user.trustScore}/100',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
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
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kia ora', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Log in to manage your listings, trust and account.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Log in'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onSignUp,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Create account'),
          ),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 64,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
