import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';

class LoginView extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  final bool isSignUp;

  const LoginView({super.key, this.onLoginSuccess, this.isSignUp = false});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isSignUp = false;
  bool _codeSent = false;
  bool _isLoading = false;

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

  void _sendOtp() async {
    if (_formKey.currentState!.validate()) {
      if (_cooldownSeconds > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please wait $_cooldownSeconds seconds before requesting a new code.',
            ),
            backgroundColor: const Color(0xFFC96B4A),
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
              backgroundColor: Color(0xFF2E5E4E), // Sage Green
            ),
          );
        }
      } catch (e) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: const Color(0xFFC96B4A), // Terracotta
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2), // Off-White
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
                _codeSent
                    ? 'Enter Verification Code'
                    : (_isSignUp
                          ? 'Create your Account'
                          : 'Log in to KiwiShare'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E5E4E), // Sage Green
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _codeSent
                    ? 'We sent a 6-digit code to ${_emailController.text}'
                    : (_isSignUp
                          ? 'Enter your username and email to register.'
                          : 'Enter your email to receive a login verification code.'),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF1F1F1F).withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              if (!_codeSent) ...[
                // Username / Display Name Input Field (Only in Sign Up mode)
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _displayNameController,
                    textCapitalization: TextCapitalization.words,
                    style: GoogleFonts.inter(color: const Color(0xFF1F1F1F)),
                    decoration: InputDecoration(
                      labelText: 'User Name',
                      hintText: 'e.g. Sam',
                      labelStyle: GoogleFonts.inter(
                        color: const Color(0xFF1F1F1F).withOpacity(0.6),
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF2E5E4E),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF2E8DB).withOpacity(0.3),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: const Color(0xFF2E5E4E).withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2E5E4E),
                          width: 1.5,
                        ),
                      ),
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
                  const SizedBox(height: 16),
                ],

                // Email Input State
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(color: const Color(0xFF1F1F1F)),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'yourname@example.com',
                    labelStyle: GoogleFonts.inter(
                      color: const Color(0xFF1F1F1F).withOpacity(0.6),
                    ),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Color(0xFF2E5E4E),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF2E8DB).withOpacity(0.3),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF2E5E4E).withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E5E4E),
                        width: 1.5,
                      ),
                    ),
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
                const SizedBox(height: 20),

                // Send OTP Button
                ElevatedButton(
                  onPressed: (_isLoading || _cooldownSeconds > 0)
                      ? null
                      : _sendOtp,
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
                          _cooldownSeconds > 0
                              ? 'Resend in ${_cooldownSeconds}s'
                              : 'Send Verification Code',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ] else ...[
                // OTP Code Input State
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1F1F1F),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: '6-Digit Code',
                    hintText: '• • • • • •',
                    labelStyle: GoogleFonts.inter(
                      color: const Color(0xFF1F1F1F).withOpacity(0.6),
                      fontSize: 14,
                      letterSpacing: 0,
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_clock_outlined,
                      color: Color(0xFF2E5E4E),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF2E8DB).withOpacity(0.3),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF2E5E4E).withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF2E5E4E),
                        width: 1.5,
                      ),
                    ),
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
                        color: const Color(0xFF1F1F1F).withOpacity(0.6),
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
                              ? const Color(0xFF1F1F1F).withOpacity(0.4)
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
                        ? 'Change Email or User Name'
                        : 'Change Email Address',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF2E5E4E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              // Switch Mode Link (when not codeSent)
              if (!_codeSent) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF1F1F1F).withOpacity(0.7),
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

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: const Color(0xFF1F1F1F).withOpacity(0.1),
                      thickness: 1.5,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or continue with',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF1F1F1F).withOpacity(0.4),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: const Color(0xFF1F1F1F).withOpacity(0.1),
                      thickness: 1.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Google Sign-In Button
              OutlinedButton(
                onPressed: _isLoading ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F1F1F),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: const Color(0xFF1F1F1F).withOpacity(0.15),
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
                      'Sign in with Google',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F1F1F),
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
