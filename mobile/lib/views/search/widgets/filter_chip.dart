import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class SearchFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final bool showDropdown;

  const SearchFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    this.showDropdown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? AppColors.brandPrimaryContainer : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? AppColors.brandPrimary : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: AppColors.brandPrimary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  if (showDropdown) ...[
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
