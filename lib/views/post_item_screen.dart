import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PostItemScreen extends StatelessWidget {
  final VoidCallback onViewListing;

  const PostItemScreen({
    super.key,
    required this.onViewListing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9E6F8), // Sky Blue background
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2D5B), size: 28),
                    onPressed: () {},
                    tooltip: 'Back',
                  ),
                  Text(
                    'Post an item',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2D5B),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF3F6FD9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Step Progress Indicator (Details -> Photos -> Price -> Confirm)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  _buildStepCircle('Details', completed: true),
                  _buildStepLine(completed: true),
                  _buildStepCircle('Photos', completed: true),
                  _buildStepLine(completed: true),
                  _buildStepCircle('Price', completed: true),
                  _buildStepLine(completed: true),
                  _buildStepCircle('Confirm', completed: true, active: true),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Main Success Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFBFF), // Cream
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1F2D5B).withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Confetti / Celebration checkmark icon
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rays/Dots surrounding check
                          ...List.generate(8, (index) {
                            final double angle = (index * 45) * math.pi / 180;
                            return Transform.translate(
                              offset: Offset(math.sin(angle) * 40, math.cos(angle) * 40),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: index % 2 == 0
                                      ? const Color(0xFFB4A7E5) // Lavender
                                      : const Color(0xFF3F6FD9), // Cobalt
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }),
                          // Large Blue Checkmark Circle
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3F6FD9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),

                      Text(
                        'Your item is live!',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2D5B),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        "Nice one! You're helping keep good things\nin use and out of landfill.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: const Color(0xFF6E7FBF),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Button 1: View my listing
                      ElevatedButton(
                        onPressed: onViewListing,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F2D5B), // Deep Navy
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'View my listing',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Button 2: Share listing
                      OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1F2D5B),
                          side: const BorderSide(color: Color(0xFF1F2D5B), width: 1.5),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.share_outlined, size: 20),
                        label: Text(
                          'Share listing',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tip Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Color(0xFF3F6FD9), size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Tip: Respond to messages quickly to sell faster.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2D5B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(String label, {required bool completed, bool active = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF3F6FD9)
                : (completed ? const Color(0xFF3F6FD9).withOpacity(0.2) : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF3F6FD9),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.check,
            size: 14,
            color: active ? Colors.white : const Color(0xFF3F6FD9),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? const Color(0xFF3F6FD9) : const Color(0xFF6E7FBF),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool completed}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18.0), // Align with circle center
        child: Container(
          height: 2.5,
          color: completed ? const Color(0xFF3F6FD9) : const Color(0xFF6E7FBF).withOpacity(0.3),
        ),
      ),
    );
  }
}
