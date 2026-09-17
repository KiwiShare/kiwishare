import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StepCircle extends StatelessWidget {
  final String label;
  final bool completed;
  final bool active;

  const StepCircle({
    super.key,
    required this.label,
    required this.completed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final inactiveFill = colors.surface;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? colors.primary
                : (completed
                      ? colors.primaryContainer.withValues(alpha: 0.6)
                      : inactiveFill),
            shape: BoxShape.circle,
            border: Border.all(color: colors.primary, width: 2),
          ),
          child: Icon(
            Icons.check,
            size: 14,
            color: active ? colors.onPrimary : colors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active ? colors.primary : colors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
