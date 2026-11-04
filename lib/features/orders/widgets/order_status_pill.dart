import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';

/// The order status as a small capsule, shared by the Messages rows and
/// the My Orders history rows.
class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color fg, Color bg) = switch (status) {
      'AWAITING_PAYMENT' => (
          AppStrings.statusAwaitingPayment,
          const Color(0xFF92400E),
          const Color(0xFFFEF3C7),
        ),
      'ACTIVE' => (
          AppStrings.statusActive,
          AppColors.accent,
          AppColors.accentSoft,
        ),
      'COMPLETED' => (
          AppStrings.statusCompleted,
          AppColors.textSecondary,
          AppColors.surface,
        ),
      'FORFEITED' => (
          AppStrings.statusForfeited,
          AppColors.textSecondary,
          AppColors.surface,
        ),
      _ => (
          AppStrings.statusCancelled,
          AppColors.textSecondary,
          AppColors.surface,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
