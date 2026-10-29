import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';

/// Network image with a consistent loading/error placeholder.
///
/// Single entry point for remote images so that swapping in a caching
/// library (e.g. `cached_network_image`) later is a one-file change.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) {
          return child;
        }
        return _Placeholder(width: width, height: height);
      },
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return _Placeholder(width: width, height: height);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Iconsax.gallery,
        size: 26,
        color: AppColors.textHint,
      ),
    );
  }
}
