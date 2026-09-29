import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../auth/login_view.dart';

/// Shared signed-out experience for private KiwiShare areas such as
/// Watchlist and Chats. Keeping this as one widget prevents the two tabs
/// from drifting visually or behaviorally.
class GuestSignInState extends StatelessWidget {
  const GuestSignInState({super.key, this.onSignedIn});

  final VoidCallback? onSignedIn;

  static const imageAsset =
      'assets/icons/kiwishare-app-icon_V1.5/master/kiwishare-mark-green-4096.png';

  Future<void> _openLogin(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LoginView(
          isSignUp: false,
          onLoginSuccess: () {
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
            onSignedIn?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      key: const Key('guest_sign_in_state'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    key: const Key('guest_sign_in_kiwi_illustration'),
                    width: 132,
                    height: 132,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.42),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.10),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      imageAsset,
                      fit: BoxFit.contain,
                      semanticLabel: 'KiwiShare kiwi bird',
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: 8,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -10,
                    top: 10,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: colors.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Please sign in',
                key: const Key('guest_sign_in_title'),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sign in to view your chats and Watchlist, and keep your KiwiShare activity together.',
                key: const Key('guest_sign_in_message'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('guest_sign_in_button'),
                  onPressed: () => _openLogin(context),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
