import 'package:flutter/material.dart';

class StepLine extends StatelessWidget {
  final bool completed;

  const StepLine({super.key, required this.completed});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: 18.0,
        ), // Align with circle center
        child: Container(
          height: 2.5,
          color: completed
              ? const Color(0xFF2E5E4E)
              : const Color(0xFF2E5E4E).withOpacity(0.2),
        ),
      ),
    );
  }
}
