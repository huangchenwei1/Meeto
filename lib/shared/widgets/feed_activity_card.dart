import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/time_ago.dart';
import 'app_avatar.dart';
import 'app_network_image.dart';

/// The one feed-post card used on both sides of the board — host activity
/// pitches on the user home and user activity requests in the gig hall —
/// so the marketplace reads as a single language. The author header rides
/// on top (avatar, name, verified mark, meta, time) and the activity
/// itself sits in an inset box: cover photo left, scene chip + title +
/// description right, with a footer line and the action pill at the
/// bottom. No money and no schedule on the card by design: fees live in
/// the invite sheet / detail page, and the concrete plan comes later
/// through the order plan flow.
class FeedActivityCard extends StatelessWidget {
  const FeedActivityCard({
    super.key,
    required this.onTap,
    required this.avatarUrl,
    required this.authorName,
    required this.authorVerified,
    required this.metaLine,
    required this.createdAt,
    required this.imageUrl,
    required this.sceneLabel,
    required this.title,
    required this.description,
    this.infoIcon,
    this.infoText = '',
    this.footerIcon,
    this.footerText = '',
    required this.action,
  });

  final VoidCallback onTap;
  final String avatarUrl;
  final String authorName;
  final bool authorVerified;
  final String metaLine;
  final DateTime createdAt;
  final String imageUrl;

  /// Already-localized scene display label.
  final String sceneLabel;

  final String title;
  final String description;

  /// Optional info line between the description and the footer, e.g.
  /// "今天下午 · Makati · 2 人已报名" on demand posts.
  final IconData? infoIcon;
  final String infoText;

  /// Bottom-left of the activity box, e.g. rough location or the budget.
  final IconData? footerIcon;
  final String footerText;

  /// Bottom-right of the activity box, e.g. an invite or pitch pill.
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(size: 42, imageUrl: avatarUrl, squircle: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            authorName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (authorVerified) ...<Widget>[
                          const SizedBox(width: 5),
                          const Icon(
                            Iconsax.verify5,
                            size: 14,
                            color: AppColors.accent,
                          ),
                        ],
                      ],
                    ),
                    if (metaLine.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        metaLine,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatTimeAgo(createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // The activity box: what you are actually buying.
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: AppColors.surface,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (imageUrl.isNotEmpty)
                      SizedBox(
                        width: 112,
                        child: AppNetworkImage(url: imageUrl),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                sceneLabel,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (description.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (infoText.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  if (infoIcon != null) ...<Widget>[
                                    Icon(
                                      infoIcon,
                                      size: 13,
                                      color: AppColors.textHint,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      infoText,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                if (footerText.isNotEmpty) ...<Widget>[
                                  if (footerIcon != null) ...<Widget>[
                                    Icon(
                                      footerIcon,
                                      size: 13,
                                      color: AppColors.textHint,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      footerText,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                action,
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card's action pill (invite / pitch), dark to carry the card's one
/// call to action.
class FeedActionPill extends StatelessWidget {
  const FeedActionPill({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.onDarkPrimary,
          ),
        ),
      ),
    );
  }
}
