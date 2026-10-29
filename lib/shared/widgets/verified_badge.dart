import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';

/// Small "Verified" tag shown next to user names.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const <Widget>[
        Icon(Iconsax.verify5, size: 13, color: AppColors.accent),
        SizedBox(width: 3),
        Text(
          AppStrings.verifiedLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
