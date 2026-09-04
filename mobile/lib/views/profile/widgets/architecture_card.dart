import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArchitectureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Color borderColor;
  final List<Widget> items;

  const ArchitectureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.borderColor,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF1F1F1F).withOpacity(0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(height: 20, color: Color(0xFF1F1F1F)),
          ...items,
        ],
      ),
    );
  }
}
