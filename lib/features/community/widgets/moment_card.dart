import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../models/activity_post.dart';

/// Community recap in a WeChat-Moments-style layout: squircle avatar on the
/// left; name, text, photo grid, venue and timestamp stacked on the right.
/// Non-transactional — no price, no CTA, just social proof plus the venue
/// recommendation other members can reuse.
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: onAuthorTap,
          child: AppAvatar(size: 44, imageUrl: post.author.avatarUrl),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: GestureDetector(
                      onTap: onAuthorTap,
                      child: Text(
                        post.author.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                  if (post.author.isVerified) ...<Widget>[
                    const SizedBox(width: 4),
                    const Icon(
                      Iconsax.verify5,
                      size: 14,
                      color: AppColors.accent,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                post.description,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
              if (photos.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _PhotoGrid(photos: photos),
              ],
              if (post.venue.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Iconsax.location5,
                        size: 13,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.venue,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '$_timeAgo \u00b7 ${AppStrings.momentBadge}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// WeChat-style photo grid: a single photo renders large; two or more
/// render as equal square cells on one row.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos});

  final List<String> photos;

  @override
  Widget build(BuildContext context) {
    final List<String> shown = photos.take(3).toList(growable: false);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (shown.length == 1) {
          final double side = constraints.maxWidth * 0.62;
          return _photo(shown.first, width: side, height: side);
        }
        const double gap = 5;
        final double cell =
            (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final String url in shown)
              _photo(url, width: cell, height: cell),
          ],
        );
      },
    );
  }

  Widget _photo(String url, {required double width, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: width,
          height: height,
          color: AppColors.surface,
          alignment: Alignment.center,
          child: const Icon(
            Iconsax.gallery_slash,
            size: 20,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}
