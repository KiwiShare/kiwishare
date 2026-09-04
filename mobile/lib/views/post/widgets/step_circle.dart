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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF2E5E4E)
                : (completed
                      ? const Color(0xFF2E5E4E).withOpacity(0.2)
                      : Colors.white),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2E5E4E), width: 2),
          ),
          child: Icon(
            Icons.check,
            size: 14,
            color: active ? Colors.white : const Color(0xFF2E5E4E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: active
                ? const Color(0xFF2E5E4E)
                : const Color(0xFF1F1F1F).withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
