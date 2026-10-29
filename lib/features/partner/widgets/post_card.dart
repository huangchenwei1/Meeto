import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../core/session/auth_session.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/relative_time.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../models/date_post.dart';

/// Community wall item: poster header + a status-led activity card.
/// The card tells how the activity is going (waiting / in progress and
/// which host took it), it is not an action button — details live behind
/// the tap.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onAuthorTap,
    this.viewerLat,
    this.viewerLng,
  });

  static const double _imageWidth = 112;

  final DatePost post;
  final VoidCallback onTap;
  final VoidCallback onAuthorTap;

  /// Viewer's location, when known; used to show the real distance to the
  /// post's venue on the card.
  final double? viewerLat;
  final double? viewerLng;

  /// Real distance from the viewer to the venue; null hides it.
  double? get _venueDistanceKm {
    if (viewerLat == null || viewerLng == null || !post.hasVenueLocation) {
      return null;
    }
    return distanceKmBetween(
      viewerLat!,
      viewerLng!,
      post.placeLat,
      post.placeLng,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _AuthorHeader(post: post, onAuthorTap: onAuthorTap),
        const SizedBox(height: 10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _CoverImage(post: post, width: _imageWidth),
                      Expanded(
                        child: _PostBody(
                          post: post,
                          isMine:
                              post.author.id == AuthSession.currentUserId,
                          venueDistanceKm: _venueDistanceKm,
                        ),
                      ),
                    ],
                  ),
                ),
                _ProgressFooter(post: post),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({required this.post, required this.onAuthorTap});

  final DatePost post;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        GestureDetector(
          onTap: onAuthorTap,
          child: AppAvatar(size: 36, imageUrl: post.author.avatarUrl),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: <Widget>[
              Text(
                post.author.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              if (post.author.isVerified) const VerifiedBadge(),
            ],
          ),
        ),
        Text(
          post.createdAt.toRelativeLabel(),
          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
        ),
      ],
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.post, required this.width});

  final DatePost post;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AppNetworkImage(url: post.imageUrl),
          // Applicant count badge, shown only while hosts can still pitch.
          if (post.signedCount > 0 && post.status == 'OPEN')
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Iconsax.profile_2user,
                      size: 11,
                      color: AppColors.onDarkPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.appliedCount(post.signedCount),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.onDarkPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({
    required this.post,
    required this.isMine,
    this.venueDistanceKm,
  });

  final DatePost post;
  final bool isMine;

  /// Viewer's real distance to the venue, appended to the place line.
  final double? venueDistanceKm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  post.sceneTag,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _StatusPill(post: post),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            post.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            post.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _MetaLine(icon: Iconsax.clock, text: post.timeText),
          const SizedBox(height: 4),
          _MetaLine(
            icon: Iconsax.location,
            text: venueDistanceKm == null
                ? post.place
                : '${post.place} \u00b7 '
                    '${venueDistanceKm!.toStringAsFixed(1)} km',
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: _BudgetLabel(post: post)),
              if (isMine) _ManageButton(post: post),
            ],
          ),
        ],
      ),
    );
  }
}

/// Status pill: how the activity is going. PENDING_PAYMENT already has a
/// chosen host, so anything past OPEN reads as in progress on the wall.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.post});

  final DatePost post;

  @override
  Widget build(BuildContext context) {
    final bool waiting = post.status == 'OPEN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: waiting ? AppColors.surface : AppColors.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        waiting
            ? AppStrings.wallStatusWaiting
            : AppStrings.wallStatusInProgress,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: waiting ? AppColors.textSecondary : AppColors.onDarkPrimary,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }
}

/// The poster's budget for the activity (the platform-set service fee).
/// One neutral amount for every viewer; role-specific amounts (net payout)
/// appear only inside the sign-up and order flows.
class _BudgetLabel extends StatelessWidget {
  const _BudgetLabel({required this.post});

  final DatePost post;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: <InlineSpan>[
          const TextSpan(
            text: '${AppStrings.budgetLabel} ',
            style: TextStyle(fontSize: 11, color: AppColors.textHint),
          ),
          TextSpan(
            text: MoneyFormat.format(post.tipAmount),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The author's entry to their own candidate pool / activity management.
class _ManageButton extends StatelessWidget {
  const _ManageButton({required this.post});

  final DatePost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        AppStrings.manageButton,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Attribution bar under the card: which host took the activity, or a
/// waiting line while the candidate pool is still open.
class _ProgressFooter extends StatelessWidget {
  const _ProgressFooter({required this.post});

  final DatePost post;

  @override
  Widget build(BuildContext context) {
    final bool hasHost = post.hasHost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: hasHost
          ? Row(
              children: <Widget>[
                AppAvatar(size: 22, imageUrl: post.selectedHost!.avatarUrl),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppStrings.wallHostAccepted(post.selectedHost!.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Iconsax.verify5,
                  size: 14,
                  color: AppColors.accent,
                ),
              ],
            )
          : Row(
              children: <Widget>[
                const Icon(
                  Iconsax.timer_1,
                  size: 14,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    AppStrings.wallWaitingLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
