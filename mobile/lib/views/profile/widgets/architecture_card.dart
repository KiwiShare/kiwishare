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
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: colors.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Divider(height: 20, color: colors.outline.withValues(alpha: 0.35)),
          ...items,
        ],
      ),
    );
  }
}
