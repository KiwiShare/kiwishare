import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';
import '../../repositories/user_repository.dart';

enum AuthMode { password, otp }

class LoginView extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final bool isSignUp;

  const LoginView({super.key, this.onLoginSuccess, this.isSignUp = false});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _codeSent = false;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_validateEmail()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().requestPasswordReset(
        _emailController.text.trim(),
      );
      if (mounted) {
        setState(() => _codeSent = true);
      }
    } on OtpCooldownException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (mounted) {
        setState(() => _saving = false);
      }
      if (mounted) {
        await _showResultDialog(
          title: 'Password reset successful',
          message: 'Your password has been updated. You can log in now.',
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceFirst('Exception: ', '');
        setState(() {
          _saving = false;
          _error = message;
        });
        await _showResultDialog(
          title: 'Password reset failed',
          message: message,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return false;
    }
    return true;
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Reset password'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                enabled: !_codeSent && !_saving,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty ||
                      !email.contains('@') ||
                      !email.contains('.')) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              if (_codeSent) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    counterText: '',
                  ),
                  validator: (value) =>
                      value == null || value.trim().length != 6
                      ? 'Enter the 6-digit code.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    helperText:
                        'Use 8-128 characters. Choose something different from your current password.',
                    helperMaxLines: 3,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show new password'
                          : 'Hide new password',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                    ),
                  ),
                  validator: (value) => value == null || value.length < 8
                      ? 'Use at least 8 characters.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirm
                          ? 'Show password confirmation'
                          : 'Hide password confirmation',
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: _saving
                          ? null
                          : () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                    ),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? 'Passwords do not match.'
                      : null,
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : (_codeSent ? _resetPassword : _requestCode),
          child: Text(
            _saving
                ? 'Saving...'
                : (_codeSent ? 'Reset password' : 'Send code'),
          ),
        ),
      ],
    );
  }
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isSignUp = false;
  AuthMode _authMode = AuthMode.password;
  bool _codeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.isSignUp;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownSeconds = seconds;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() {
          _cooldownSeconds = 0;
        });
      } else {
        setState(() {
          _cooldownSeconds--;
        });
      }
    });
  }

  void _submitPasswordAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final displayName = _displayNameController.text.trim();

    try {
      if (_isSignUp) {
        await authProvider.register(email, password, displayName);
      } else {
        await authProvider.login(email, password);
      }

      final loggedInName =
          authProvider.currentUser?.displayName ??
          (displayName.isNotEmpty ? displayName : 'User');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kia ora, $loggedInName! Welcome to KiwiShare.'),
            backgroundColor: const Color(0xFF2E5E4E),
          ),
        );

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFC96B4A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sendOtp() async {
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address first.'),
          backgroundColor: Color(0xFFC96B4A),
        ),
      );
      return;
    }

    if (_cooldownSeconds > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please wait for the countdown timer to finish before requesting a new code.',
          ),
          backgroundColor: Color(0xFFC96B4A),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();

    try {
      await authProvider.sendOtp(email);
      _startCooldown(60);
      setState(() {
        _codeSent = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent! Please check your email.'),
            backgroundColor: Color(0xFF2E5E4E),
          ),
        );
      }
    } on OtpCooldownException catch (e) {
      _startCooldown(e.cooldownSeconds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please wait for the countdown timer to finish before requesting a new code.',
            ),
            backgroundColor: Color(0xFFC96B4A),
          ),
        );
      }
    } catch (e) {
      var errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('Please wait') || errorMsg.contains('cooldown')) {
        _startCooldown(60);
        errorMsg =
            'Please wait for the countdown timer to finish before requesting a new code.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFC96B4A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _verifyOtp() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit verification code.'),
          backgroundColor: Color(0xFFC96B4A),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailController.text.trim();
    final displayName = _displayNameController.text.trim();

    try {
      await authProvider.verifyOtp(
        email,
        code,
        displayName: (_isSignUp && displayName.isNotEmpty) ? displayName : null,
      );

      final loggedInName =
          authProvider.currentUser?.displayName ??
          (displayName.isNotEmpty ? displayName : 'User');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kia ora, $loggedInName! Welcome to KiwiShare.'),
            backgroundColor: const Color(0xFF2E5E4E),
          ),
        );

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMsg.contains('verification code')
                  ? 'Verification code is incorrect or expired.'
                  : errorMsg,
            ),
            backgroundColor: const Color(0xFFC96B4A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.loginWithGoogle();
      if (authProvider.isLoggedIn && mounted) {
        final user = authProvider.currentUser;
        if (user?.username == null || user!.username!.trim().isEmpty) {
          final usernameSaved = await _promptForGoogleUsername(
            authProvider,
            user?.email,
          );
          if (!usernameSaved || !mounted) {
            await authProvider.logout();
            return;
          }
        }

        if (!mounted) return;
        final name = authProvider.currentUser?.displayName ?? 'User';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kia ora, $name! Welcome to KiwiShare.'),
            backgroundColor: const Color(0xFF2E5E4E),
          ),
        );

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google Sign-in failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: const Color(0xFFC96B4A),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _promptForGoogleUsername(
    AuthProvider authProvider,
    String? email,
  ) async {
    final controller = TextEditingController();
    String? errorText;
    var isSubmitting = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose your username'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (email != null && email.isNotEmpty) ...[
                Text('Signed in as $email'),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                enabled: !isSubmitting,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. kiwi_trader',
                  errorText: errorText,
                  helperText: '3-24 letters, numbers, or underscores',
                ),
                onSubmitted: isSubmitting
                    ? null
                    : (_) => _submitGoogleUsername(
                        dialogContext,
                        setDialogState,
                        authProvider,
                        controller,
                        onSubmittingChanged: (value) => isSubmitting = value,
                        onErrorChanged: (value) => errorText = value,
                      ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () => _submitGoogleUsername(
                      dialogContext,
                      setDialogState,
                      authProvider,
                      controller,
                      onSubmittingChanged: (value) => isSubmitting = value,
                      onErrorChanged: (value) => errorText = value,
                    ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result == true;
  }

  Future<void> _submitGoogleUsername(
    BuildContext dialogContext,
    StateSetter setDialogState,
    AuthProvider authProvider,
    TextEditingController controller, {
    required ValueChanged<bool> onSubmittingChanged,
    required ValueChanged<String?> onErrorChanged,
  }) async {
    final value = controller.text.trim();
    if (!RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(value)) {
      setDialogState(() {
        onErrorChanged('Use 3-24 letters, numbers, or underscores.');
      });
      return;
    }

    setDialogState(() {
      onErrorChanged(null);
      onSubmittingChanged(true);
    });

    try {
      await authProvider.updateUsername(value);
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop(true);
      }
    } catch (error) {
      if (!dialogContext.mounted) return;
      final message = error
          .toString()
          .replaceFirst('UserRepositoryException: ', '')
          .replaceFirst('Exception: ', '')
          .trim();
      setDialogState(() {
        onSubmittingChanged(false);
        onErrorChanged(
          message.isEmpty
              ? 'Could not save that username. Try another.'
              : message,
        );
      });
    }
  }

  Future<void> _showPasswordReset() async {
    final email = _emailController.text.trim();
    await showDialog<bool>(
      context: context,
      builder: (_) => _PasswordResetDialog(initialEmail: email),
    );
  }

  InputDecoration _authInputDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? counterText,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      counterText: counterText,
      labelStyle: GoogleFonts.inter(
        color: colors.onSurfaceVariant,
        letterSpacing: 0,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: colors.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(
        alpha: isDark ? 0.42 : 0.55,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surface : const Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Text
              Text(
                _authMode == AuthMode.otp && _codeSent
                    ? 'Enter Verification Code'
                    : (_isSignUp
                          ? 'Create your Account'
                          : 'Log in to KiwiShare'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _authMode == AuthMode.otp && _codeSent
                    ? 'We sent a 6-digit code to ${_emailController.text}'
                    : (_isSignUp
                          ? 'Fill in your details to create a new KiwiShare account.'
                          : 'Sign in with your email and password.'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Auth Method Segmented Tabs (Password vs OTP)
              if (!_codeSent) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: isDark ? 0.48 : 0.62,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _authMode = AuthMode.password;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _authMode == AuthMode.password
                                  ? colors.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _authMode == AuthMode.password
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.18 : 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Password',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _authMode == AuthMode.password
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _authMode == AuthMode.password
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _authMode = AuthMode.otp;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _authMode == AuthMode.otp
                                  ? colors.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _authMode == AuthMode.otp
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: isDark ? 0.18 : 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Email Code (OTP)',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _authMode == AuthMode.otp
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _authMode == AuthMode.otp
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 1. Password Mode or Pre-OTP fields
              if (_authMode == AuthMode.password || !_codeSent) ...[
                // Username / Display Name Input Field (Only in Sign Up mode)
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _displayNameController,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.inter(color: colors.onSurface),
                    decoration: _authInputDecoration(
                      context,
                      labelText: 'Username',
                      hintText: 'e.g. Sam Yao',
                      prefixIcon: Icons.person_outline,
                    ),
                    validator: (value) {
                      if (!_isSignUp) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your username';
                      }
                      if (value.trim().length < 2) {
                        return 'Username must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Email Input
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(color: colors.onSurface),
                  decoration: _authInputDecoration(
                    context,
                    labelText: 'Email Address',
                    hintText: 'yourname@example.com',
                    prefixIcon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Password Input Field (Only in Password mode)
                if (_authMode == AuthMode.password) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: GoogleFonts.inter(color: colors.onSurface),
                    decoration: _authInputDecoration(
                      context,
                      labelText: 'Password',
                      hintText: '••••••••',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: colors.primary.withValues(alpha: 0.78),
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (_authMode != AuthMode.password) return null;
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (_isSignUp && value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  if (!_isSignUp) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _showPasswordReset,
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 20),

                  // Password Auth Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitPasswordAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC96B4A), // Terracotta
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(
                        0xFFC96B4A,
                      ).withOpacity(0.5),
                      disabledForegroundColor: Colors.white.withOpacity(0.8),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create Account' : 'Log In',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],

                // Send OTP Button (When in OTP mode and code not sent yet)
                if (_authMode == AuthMode.otp) ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: (_isLoading || _cooldownSeconds > 0)
                        ? null
                        : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC96B4A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(
                        0xFFC96B4A,
                      ).withOpacity(0.5),
                      disabledForegroundColor: Colors.white.withOpacity(0.8),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _cooldownSeconds > 0
                                ? 'Resend in ${_cooldownSeconds}s'
                                : 'Send Verification Code',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  if (_cooldownSeconds > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC96B4A).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFC96B4A).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Color(0xFFC96B4A),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Cooldown active: ${_cooldownSeconds}s remaining',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFC96B4A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ] else ...[
                // OTP Code Input State
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.inter(
                    color: colors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: _authInputDecoration(
                    context,
                    counterText: '',
                    labelText: '6-Digit Code',
                    hintText: '• • • • • •',
                    prefixIcon: Icons.lock_clock_outlined,
                  ),
                ),
                const SizedBox(height: 12),

                // Resend Code Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive code? ",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: (_isLoading || _cooldownSeconds > 0)
                          ? null
                          : _sendOtp,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        _cooldownSeconds > 0
                            ? 'Resend (${_cooldownSeconds}s)'
                            : 'Resend Code',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _cooldownSeconds > 0
                              ? colors.onSurfaceVariant.withValues(alpha: 0.55)
                              : const Color(0xFFC96B4A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Verify and Login / Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5E4E), // Sage Green
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isSignUp
                              ? 'Verify & Create Account'
                              : 'Verify & Log In',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 12),

                // Back Button to change email or username
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _codeSent = false;
                            _codeController.clear();
                          });
                        },
                  child: Text(
                    _isSignUp
                        ? 'Change Email or Username'
                        : 'Change Email Address',
                    style: GoogleFonts.inter(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              // Switch Mode Link (when not codeSent)
              if (!_codeSent) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _formKey.currentState?.reset();
                        });
                      },
                      child: Text(
                        _isSignUp ? 'Log in' : 'Create account',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFC96B4A),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: colors.outline.withValues(alpha: 0.22),
                      thickness: 1.5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: colors.outline.withValues(alpha: 0.22),
                      thickness: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Google Sign-In Button
              OutlinedButton(
                key: const Key('google_sign_in_button'),
                onPressed: _isLoading ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.onSurface,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: colors.outline.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(18, 18),
                      painter: GoogleLogoPainter(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isSignUp ? 'Sign up with Google' : 'Sign in with Google',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double r = w / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22;

    // Red Arc (Top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r - paint.strokeWidth / 2),
      -3.14159 * 0.75,
      3.14159 * 0.5,
      false,
      paint,
    );

    // Yellow Arc (Left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r - paint.strokeWidth / 2),
      3.14159 * 0.75,
      3.14159 * 0.5,
      false,
      paint,
    );

    // Green Arc (Bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r - paint.strokeWidth / 2),
      3.14159 * 0.25,
      3.14159 * 0.5,
      false,
      paint,
    );

    // Blue Arc & horizontal bar (Right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r, r), radius: r - paint.strokeWidth / 2),
      -3.14159 * 0.25,
      3.14159 * 0.5,
      false,
      paint,
    );

    // Horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(r, r - paint.strokeWidth / 2, r * 0.9, paint.strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
