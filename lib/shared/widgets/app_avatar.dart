import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_network_image.dart';

/// Avatar backed by [AppNetworkImage]; falls back to a letter avatar when
/// [imageUrl] is null or empty (official account, users who have not
/// uploaded a photo yet). Circular by default; pass [squircle] for the
/// rounded-square look used on host cards.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.fallbackLetter,
    this.squircle = false,
  });

  final double size;
  final String? imageUrl;
  final String? fallbackLetter;
  final bool squircle;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(squircle ? size * 0.28 : size / 2);
    final String? url = imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Text(
          fallbackLetter ?? '?',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            color: AppColors.onDarkPrimary,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: radius,
      child: AppNetworkImage(url: url, width: size, height: size),
    );
  }
}
