import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_network_image.dart';

/// Circular avatar backed by [AppNetworkImage]; falls back to a letter
/// avatar when [imageUrl] is null or empty (official account, users who
/// have not uploaded a photo yet).
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.fallbackLetter,
  });

  final double size;
  final String? imageUrl;
  final String? fallbackLetter;

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.darkCard,
          shape: BoxShape.circle,
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
    return ClipOval(
      child: AppNetworkImage(url: url, width: size, height: size),
    );
  }
}
