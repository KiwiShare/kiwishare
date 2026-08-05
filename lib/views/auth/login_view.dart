import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_state.dart';

class LoginView extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginView({super.key, this.onLoginSuccess});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.login().then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSignUp
                  ? 'Account created! Welcome to KiwiShare.'
                  : 'Welcome back! Logged in as Sam.',
            ),
            backgroundColor: const Color(0xFF2E5E4E), // Sage Green
          ),
        );

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F2), // Off-White
        borderRadius: BorderRadius.circular(24),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Text
            Text(
              _isSignUp
                  ? 'Create a KiwiShare Account'
                  : 'Kia ora! Welcome to KiwiShare',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E5E4E), // Sage Green
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp
                  ? 'Join Aotearoa\'s trusted second-hand marketplace.'
                  : 'Log in to start sharing, buying, and selling sustainably.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(
                  0xFF1F1F1F,
                ).withOpacity(0.6), // Charcoal opacity
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Email Input
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(color: const Color(0xFF1F1F1F)),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: GoogleFonts.inter(
                  color: const Color(0xFF1F1F1F).withOpacity(0.6),
                ),
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF2E5E4E),
                ), // Sage Green
                filled: true,
                fillColor: const Color(
                  0xFFF2E8DB,
                ).withOpacity(0.3), // Warm Beige tint
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
                if (!value.contains('@')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Input
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              style: GoogleFonts.inter(color: const Color(0xFF1F1F1F)),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: GoogleFonts.inter(
                  color: const Color(0xFF1F1F1F).withOpacity(0.6),
                ),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF2E5E4E),
                ), // Sage Green
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: const Color(0xFF2E5E4E), // Sage Green
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                filled: true,
                fillColor: const Color(
                  0xFFF2E8DB,
                ).withOpacity(0.3), // Warm Beige tint
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
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Submit Button (Terracotta accent)
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC96B4A), // Terracotta
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                _isSignUp ? 'Create Account' : 'Log In',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Switch login mode button (Sage Green)
            TextButton(
              onPressed: () {
                setState(() {
                  _isSignUp = !_isSignUp;
                });
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Log In'
                    : 'New to KiwiShare? Register here',
                style: GoogleFonts.inter(
                  color: const Color(0xFF2E5E4E), // Sage Green
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
