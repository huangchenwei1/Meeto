import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../features/community/pages/community_guidelines_page.dart';

/// Community guidelines banner shared by the hosts and community tabs:
/// the same safety promise greets members on both entry surfaces. Taps
/// open the full guidelines page.
class GuidelinesBanner extends StatelessWidget {
  const GuidelinesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: const <Widget>[
                    Icon(Iconsax.star1, size: 13, color: AppColors.accent),
                    SizedBox(width: 5),
                    Text(
                      AppStrings.bannerEyebrow,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  AppStrings.bannerTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onDarkPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  AppStrings.bannerSub,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.onDarkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CommunityGuidelinesPage(),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.textPrimary,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text(AppStrings.bannerCta),
          ),
        ],
      ),
    );
  }
}
