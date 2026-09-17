import 'package:flutter/material.dart';

class StepLine extends StatelessWidget {
  final bool completed;

  const StepLine({super.key, required this.completed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: 18.0,
        ), // Align with circle center
        child: Container(
          height: 2.5,
          color: completed
              ? colors.primary
              : colors.primary.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}
