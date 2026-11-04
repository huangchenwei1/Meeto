import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../data/profile_repository.dart';
import '../models/profile_parts.dart';
import '../models/user_detail.dart';

/// Public profile of another user, Bumble-style blocks under a regular
/// identity header: content cards (about, basics, interests) alternate
/// with full-width photo cards. Photos set the pace; whatever is left
/// when one side runs out just stacks below. Activity stats and reviews —
/// the trust assets a hosting marketplace has that a dating app does
/// not — close the page.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    required this.userId,
    required this.profileRepository,
  });

  final String userId;
  final ProfileRepository profileRepository;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserDetail? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final UserDetail? user =
        await widget.profileRepository.fetchUserDetail(widget.userId);
    if (!mounted) {
      return;
    }
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  /// Weaves the page: a regular identity header first, then content
  /// blocks alternating with the photos, then stats and reviews.
  List<Widget> _blocks(UserDetail user) {
    final List<String> photos =
        user.photos.where((String p) => p != user.avatarUrl).toList();

    final List<Widget> content = <Widget>[
      if (user.bio.isNotEmpty) _AboutCard(user: user),
      if (user.info.isNotEmpty) _BasicsCard(info: user.info),
      if (user.tags.isNotEmpty) _InterestsCard(tags: user.tags),
    ];

    final List<Widget> blocks = <Widget>[_Header(user: user)];
    int photoIndex = 0;
    for (final Widget card in content) {
      blocks.add(card);
      if (photoIndex < photos.length) {
        blocks.add(_PhotoCard(imageUrl: photos[photoIndex]));
        photoIndex++;
      }
    }
    // Leftover photos keep stacking once the content runs out.
    for (; photoIndex < photos.length; photoIndex++) {
      blocks.add(_PhotoCard(imageUrl: photos[photoIndex]));
    }

    blocks.add(_StatsCard(stats: user.stats));
    if (user.reviews.isNotEmpty) {
      blocks.add(const _SectionTitle(AppStrings.profileReviews));
      blocks.addAll(user.reviews.map((UserReview r) => _ReviewTile(review: r)));
    }
    return blocks;
  }

  @override
  Widget build(BuildContext context) {
    final UserDetail? user = _user;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(AppStrings.profileTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
                  children: _blocks(user),
                ),
    );
  }
}

/// The regular identity header: avatar, name, badge and the meta line.
class _Header extends StatelessWidget {
  const _Header({required this.user});

  final UserDetail user;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      child: Column(
        children: <Widget>[
          AppAvatar(size: 76, imageUrl: user.avatarUrl),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 7),
              if (user.isVerified) const VerifiedBadge(),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            <String>[user.meta, user.city, user.joinedText]
                .where((String part) => part.isNotEmpty)
                .join(' \u00b7 '),
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

/// Shared shell: white rounded block on the gray canvas.
class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: AppNetworkImage(url: imageUrl),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.user});

  final UserDetail user;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      title: AppStrings.profileAboutTitle,
      child: Text(
        user.bio,
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.7,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// The basics as icon chips (job, education, height, weight, city) —
/// Bumble's badge row instead of a label/value table.
class _BasicsCard extends StatelessWidget {
  const _BasicsCard({required this.info});

  final List<ProfileInfoItem> info;

  IconData _iconFor(String label) {
    if (label == AppStrings.profileJobLabel) {
      return Iconsax.briefcase;
    }
    if (label == AppStrings.profileEducationLabel) {
      return Iconsax.teacher;
    }
    if (label == AppStrings.profileHeightLabel) {
      return Iconsax.ruler;
    }
    if (label == AppStrings.profileWeightLabel) {
      return Iconsax.weight;
    }
    if (label == AppStrings.profileLivesInLabel) {
      return Iconsax.location;
    }
    return Iconsax.info_circle;
  }

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      title: AppStrings.profileBasicsTitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: info
            .map(
              (ProfileInfoItem item) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _iconFor(item.label),
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _InterestsCard extends StatelessWidget {
  const _InterestsCard({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      title: AppStrings.profileInterestsTitle,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags
            .map(
              (String tag) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return _ContentCard(
      child: Row(
        children: stats
            .map(
              (ProfileStat s) => Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      s.value,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final UserReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(size: 24, imageUrl: review.avatarUrl),
              const SizedBox(width: 8),
              Text(
                review.fromName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              const Icon(Iconsax.star1, size: 14, color: AppColors.accent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
