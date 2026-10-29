import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../models/activity_post.dart';

/// Community recap card: author, text, photos. Non-transactional — no
/// price, no CTA, just social proof that real activities happen.
class MomentCard extends StatelessWidget {
  const MomentCard({super.key, required this.post, this.onAuthorTap});

  final ActivityPost post;
  final VoidCallback? onAuthorTap;

  String get _timeAgo {
    final Duration d = DateTime.now().difference(post.createdAt);
    if (d.inMinutes < 60) {
      return '${d.inMinutes.clamp(1, 59)}m';
    }
    if (d.inHours < 24) {
      return '${d.inHours}h';
    }
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final List<String> photos =
        post.images.where((String url) => url.isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: onAuthorTap,
                child: AppAvatar(size: 38, imageUrl: post.author.avatarUrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            post.author.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (post.author.isVerified) ...<Widget>[
                          const SizedBox(width: 4),
                          const Icon(
                            Iconsax.verify5,
                            size: 13,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '$_timeAgo \u00b7 ${AppStrings.momentBadge}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
          ),
          if (photos.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            _PhotoRow(photos: photos),
          ],
        ],
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final List<String> shown = photos.take(3).toList(growable: false);
    return SizedBox(
      height: shown.length == 1 ? 180 : 110,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < shown.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  shown[i],
                  fit: BoxFit.cover,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.background,
                    alignment: Alignment.center,
                    child: const Icon(
                      Iconsax.gallery_slash,
                      size: 20,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
